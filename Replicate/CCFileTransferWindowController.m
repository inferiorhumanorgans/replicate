//
//  CCFileTransferWindowController.m
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#include <netdb.h>

#import "CCFileTransferWindowController.h"
#import "CCGenericDirectoryController.h"
#import "CCDirectoryEntry.h"

#include <libssh2.h>
#include <libssh2_sftp.h>

static void logKeychainError(OSStatus status) {
    CFStringRef str = SecCopyErrorMessageString(status, NULL);
    NSLog(@"Error: %@", str);
    CFRelease(str);
}

@implementation CCFileTransferWindowController

@synthesize curDirent;

// From NSWindowController
- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Set up the remote protocol
        status = kCCStatDisconnected;

        // Directory entries
        self.aryCWD = [NSMutableArray arrayWithCapacity:0];

        // History tracking
        aryHistory = [NSMutableArray array];
        historyPosition = -1;
    }

    return self;
}

// From NSWindowController
- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.pathCWD setPathComponentCells:[NSArray array]];
    [self.tblCWD setDraggingSourceOperationMask:(NSDragOperationCopy|NSDragOperationGeneric) forLocal:NO];
    [self.tblCWD setDataSource:self.ctlCWD];
    
    NSSortDescriptor *defaultSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"path" ascending:YES];
    [self.ctlCWD setSortDescriptors:[NSArray arrayWithObject:defaultSortDescriptor]];
    [txtURL setDelegate:self];
}

- (void)progress:(BOOL)isBusy {
    if (isBusy) {
        [progress startAnimation:self];
        [progress setHidden:NO];
    } else {
        [progress setHidden:YES];
        [progress stopAnimation:self];
    }
}

// This is really goss but ensures that we access the UI components only from the main thread.
// Using performSelectorOnMainThread allows Cocoa to do its thing with the event loop instad
// of creating a deadlock with GCD.
- (void)getElements:(NSMutableDictionary *)objects {
    NSMutableDictionary *ourDict = objects;
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:[txtURL stringValue]];
    [ourDict setObject:urlComponents forKey:@"components"];
}

// This needs to run on the main thread because it gets the stringValue of a UI component, and
// it may be called from a background thread.
- (NSURL *)currentURL {
    NSMutableDictionary *myDict = [NSMutableDictionary dictionaryWithCapacity:1];
    NSURLComponents *myComponents;

    [self performSelectorOnMainThread:@selector(getElements:) withObject:myDict waitUntilDone:YES];
    myComponents = [myDict objectForKey:@"components"];
    if ((myComponents == nil) || ([myComponents host] == nil)) {
        return nil;
    }
    return [myComponents URL];
}

- (NSString *)currentURLForKeychain {
    NSURLComponents *components = [NSURLComponents componentsWithURL:[self currentURL] resolvingAgainstBaseURL:NO];
    [components setPath:@"/"];
    [components setScheme:[NSString stringWithFormat:@"replicate+%@", [components scheme]]];
    return [[components URL] absoluteString];
}

- (void)setTitleForStatus:(CCFTPState)aStatus {
    NSString *description = nil;
    switch(aStatus) {
        case kCCStatConnecting:
        case kCCStatAuthenticationSucceeded:
        case kCCStatHostVerificationSucceeded:
            description = @"Connecting";
            break;
        case kCCStatConnected:
        case kCCStatIdle:
        case kCCStatReady:
            description = @"Connected";
            break;
        case kCCStatAuthenticationFailed:
        case kCCStatHostVerificationFailed:
        case kCCStatDisconnected:
            description = @"Disconnected";
            break;
        default:
            return;
    }

    NSURL *theURL = [self currentURL];
    if (description != nil) {
        if ([theURL user] == nil) {
            [[self window] setTitle:[NSString stringWithFormat:@"%@ - %@", [theURL host], description]];
        } else {
            [[self window] setTitle:[NSString stringWithFormat:@"%@@%@ - %@", [theURL user], [theURL host], description]];
        }
    } else {
        [[self window] setTitle:[NSString stringWithFormat:@"%@@%@", [theURL user], [theURL host]]];
    }
}

- (void)statusDidChange:(NSNotification *)aNotification {
    @autoreleasepool {
        NSDictionary *info = [aNotification userInfo];

        CCFTPState connectionSatus;
        [[info objectForKey:@"Status"] getValue:&connectionSatus];

        [self setTitleForStatus:connectionSatus];

        switch(connectionSatus) {
            case kCCStatConnecting: {
                NSLog(@"kCCStatConnecting");
                for (NSToolbarItem *toolbarItem in [ourToolbar items]) {
                    if ([[toolbarItem itemIdentifier] compare:@"ConnectBtn"] == NSOrderedSame) {
                        [toolbarItem setLabel:@"Connecting"];
                    }
                }
                break;
            }
            case kCCStatConnected: {
                NSLog(@"kCCStatConnected");
                [ssh verifyHostKey];
                break;
            }
            case kCCStatHostVerificationSucceeded: {
                NSLog(@"kCCStatHostVerificationSucceeded");
                [ssh authenticateWithServer];
                break;
            }
            case kCCStatAuthenticationSucceeded: {
                NSLog(@"kCCStatAuthenticationSucceeded %@", info);
                [ssh initializeSFTP];
                break;
            }
            case kCCStatAuthenticationFailed: {
                NSLog(@"kCCStatAuthenticationFailed");
                [ssh closeSession];
                break;
            }
            case kCCStatReady: {
                NSLog(@"kCCStatReady");
                for (NSToolbarItem *toolbarItem in [ourToolbar items]) {
                    if ([[toolbarItem itemIdentifier] compare:@"SSHConnectBtn"] == NSOrderedSame) {
                        [toolbarItem setLabel:@"Disconnect"];
                    }
                }
                [self progress:NO];

                break;
            }
            case kCCStatBusy: {
                [self progress:YES];
                break;
            }
            case kCCStatIdle: {
                [self progress:NO];

                if ([info objectForKey:CCStatIdle_DirectoryContents]) {
                    NSLog(@"DirInfo");
                    NSMutableArray *pathComponents = [NSMutableArray array];
                    NSMutableString *urlString = [NSMutableString stringWithString:@"sftp://host/"];
                    NSString *newCWD = [info objectForKey:CCStatIdle_CurrentDirectory];

                    for (NSString *pathComponent in [newCWD componentsSeparatedByString:@"/"]) {
                        NSPathComponentCell *componentCell = [[NSPathComponentCell alloc] init];
                        NSImage *iconImage = NULL;

                        if (([pathComponent length] == 0) && ([pathComponents count] == 0)) {
                            [componentCell setTitle:[[self currentURL] host]];
                            iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericHardDiskIcon)];
                        } else if ([pathComponent length] > 0) {
                            [urlString appendFormat:@"%@/", pathComponent];
                            iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
                            [componentCell setTitle:pathComponent];
                        }

                        if (iconImage) {
                            [componentCell setImage:iconImage];
                            [componentCell setURL:[NSURL URLWithString:urlString]];

                            [pathComponents addObject:componentCell];
                        }
                    }

                    [self.pathCWD setPathComponentCells:pathComponents];

                    [self addHistory:newCWD];
                    [self dumpHistory];
                    [self.aryCWD removeAllObjects];
                    [self.aryCWD addObjectsFromArray:[info objectForKey:CCStatIdle_DirectoryContents]];
                    [self.ctlCWD rearrangeObjects];
                    [self progress:NO];
                }

                if ([info objectForKey:CCStatIdle_KeepAlive]) {
                    NSLog(@"Next Keepalive: %@", [info objectForKey:CCStatIdle_KeepAlive]);
                }
                break;
            }
            case kCCStatDisconnected: {
                NSLog(@"kCCSFTPDisconnected");

                // Only enable editing if we're really going from a connected state to disconnected
                if (status != kCCStatDisconnected) {
                    [txtURL setEditable:YES];
                }

                [self.pathCWD setURL:[NSURL URLWithString:@""]];
                [self.aryCWD removeAllObjects];
                [self.ctlCWD rearrangeObjects];

                for (NSToolbarItem *toolbarItem in [ourToolbar items]) {
                    if ([[toolbarItem itemIdentifier] compare:@"SSHConnectBtn"] == NSOrderedSame) {
                        [toolbarItem setLabel:@"Connect"];
                    }
                }

                [self progress:NO];
                break;
            }
            case kCCStatTransferNew: {
                [progressBar startAnimation:self];
                NSNumber *num = [info objectForKey:CCStatTransfer_Size];
                [progressBar setMaxValue:[progressBar maxValue] + [num unsignedLongValue]];
                [progressBar setDoubleValue:0.0];
                num = NULL;
                break;
            }
            case kCCStatTransferUpdate: {
                @autoreleasepool {
                    NSNumber *num = [info objectForKey:CCStatTransfer_Size];
                    [progressBar incrementBy:[num unsignedLongValue]];
                    if ([progressBar doubleValue] >= [progress maxValue]) {
                        [progressBar stopAnimation:self];
                    } else {
                        [progressBar startAnimation:self];
                    }
                    num = NULL;
                }
                break;
            }
            case kCCStatTransferDone: {
                NSNumber *num = [info objectForKey:CCStatTransfer_Size];
                [progressBar setMaxValue:[progressBar maxValue] - [num unsignedLongValue]];
                [progressBar setDoubleValue: [progressBar doubleValue] - [num unsignedLongValue]];
                if ([progressBar doubleValue] >= [progress maxValue]) {
                    [progressBar stopAnimation:self];
                } else {
                    [progressBar startAnimation:self];
                }
                num = NULL;
                break;
            }
            default: {
                NSLog(@"Connected: %@", aNotification);
                for (NSToolbarItem *toolbarItem in [ourToolbar items]) {
                    if ([[toolbarItem itemIdentifier] compare:@"SSHConnectBtn"] == NSOrderedSame) {
                        [toolbarItem setLabel:@"Connect"];
                    }
                }
                [self progress:NO];
                break;
            }
        }
        info = NULL;
        status = connectionSatus;
    }
}

- (int)getPort {
    NSURL *theURL = [self currentURL];
    int port = theURL.port.intValue;
    if (port == 0) {
        struct servent *service = NULL;
        if ([theURL.scheme compare:@"sftp"] == NSOrderedSame) {
            service = getservbyname("ssh", NULL);
        } else if ([theURL.scheme compare:@"s3"] == NSOrderedSame) {
            service = getservbyname("https", NULL);
        }

        if (service) {
            return ntohs(service->s_port);
        } else {
            NSLog(@"Warning, no port specified and we don't really know what to do with this protocol.");
        }
    }

    return port;
}

- (id)getFileTransferInstanceForScheme:(NSString *)aScheme {
    NSString *fileTransferScheme = nil;

    if ([aScheme compare:@"sftp"] == NSOrderedSame) {
        fileTransferScheme = @"CCSSH";
    } else if ([aScheme compare:@"s3"] == NSOrderedSame) {
        fileTransferScheme = @"CCS3";
    } else {
        // Unknown scheme...
        return nil;
    }

    Class fileTransferClass = NSClassFromString(fileTransferScheme);
    return [[fileTransferClass alloc] initWithController:self];
}

- (IBAction)connectWasClicked:(id)sender {
    switch (status) {
        case kCCStatDisconnected: {
            NSURL *theURL = [self currentURL];
            NSLog(@"Connect to '%@'", theURL);

            if (theURL == nil) {
                // Bogus URL, should probably throw up a dialog box
                return;
            }

            self.ctlCWD.ssh = ssh = [self getFileTransferInstanceForScheme:theURL.scheme];

            if (ssh == nil) {
                return;
            }

            [txtURL setEditable:NO];

            tmpPassword = NULL;

            if ([ssh setupSession]) {
                [ssh closeSessionWithReason:@"Failed to initialize session data"];
                return;
            };

            ssh.port = [self getPort];
            ssh.url = [self currentURL];
            
            [ssh connect];
            break;
        }
        case kCCStatBusy: {
            // Cancel operation
            [ssh closeSession];
            break;
        }
        default: {
            // Assume we're not doing anything important
            [ssh closeSession];
            break;
        }
    }
}
    
- (IBAction)bookmarksWereClicked:(id)sender
{
    
}

- (IBAction)refreshWasClicked:(id)sender
{
    [ssh changeDirectory:@"."];
}

- (IBAction)pathBarWasClicked:(id)sender {
    NSPathControl *localPath = sender;
    NSURL *localURL = [[localPath clickedPathComponentCell] URL];
    [ssh changeDirectory:[localURL path]];
}

- (IBAction)backWasClicked:(id)sender {
    NSSegmentedControl *theControl = sender;

    switch ([theControl selectedSegment]) {
        case 0: {
            // Check connection status
            if (historyPosition <= 0) {
                return;
            }
            [self goToHistoryAt:--historyPosition];
            break;
        }
        case 1: {
            // Check connection status
            if (historyPosition >= ([aryHistory count] - 1)) {
                return;
            }
            [self goToHistoryAt:++historyPosition];
            break;
        }
    }
}

- (void)dumpHistory {
    for (int i=0; i < [aryHistory count]; i++) {
        NSString *currentHistory = [aryHistory objectAtIndex:i];
        if (i == historyPosition) {
            fprintf(stderr, "%s <--- *\n", [currentHistory UTF8String]);
        } else {
            fprintf(stderr, "%s\n", [currentHistory UTF8String]);
        }
    }
}

- (void)addHistory:(NSString *)aDirectory {
    if ((historyPosition >= 0) && ([(NSString *)[aryHistory objectAtIndex:historyPosition] compare:aDirectory] == NSOrderedSame)) {
        // Ignore since we just reloaded
        return;
    }

    if (historyPosition != ([aryHistory count] - 1)) {
        // Truncate
        aryHistory = [NSMutableArray arrayWithArray:[aryHistory subarrayWithRange:NSMakeRange(0, historyPosition + 1)]];
    }

    // Add to top
    [aryHistory addObject:aDirectory];
    historyPosition = (int)[aryHistory count] - 1;
}

- (void)goToHistoryAt:(int)aPosition {
    [ssh changeDirectory:[aryHistory objectAtIndex:aPosition]];
}

@end

@implementation CCFileTransferWindowController(Interrogation)

- (NSString *) getAnswerForQuestion:(NSString *)aQuestion {
    NSMutableString *answerValue = [[NSMutableString alloc] init];
    
    NSTextField *localQuestion = txtQuestion;
    NSTextField *localAnswer = txtAnswer;
    NSPanel     *localSheet = sheetInterrogation;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [localQuestion setStringValue:aQuestion];
        [NSApp beginSheet:localSheet modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        switch ([NSApp runModalForWindow:localSheet]) {
            case NSOKButton: {
                [answerValue setString:[localAnswer stringValue]];
                break;
            }
            case NSCancelButton:
            default: {
                break;
            }
        }
        [localAnswer setStringValue:@""];
    });
    return answerValue;
}

- (IBAction)endTheSheet:(id)sender {
    
    [NSApp endSheet:sheetInterrogation];
    [sheetInterrogation orderOut:sender];
    NSString *title = [sender title];
    if ([title caseInsensitiveCompare:@"OK"]==NSOrderedSame) {
        [NSApp stopModalWithCode:NSOKButton];
    } else if ([title caseInsensitiveCompare:@"Cancel"]==NSOrderedSame) {
        [NSApp stopModalWithCode:NSCancelButton];
    }
}

- (NSString *) getPassword {
    NSLog(@"getPassword:%@", [self currentURLForKeychain]);
    NSString *ret = nil;
    const char *keychainItemName;
    char *passwordData = 0;
    UInt32 passwordLength;
    OSStatus keychainStatus;
    

    keychainItemName = [[self currentURLForKeychain] UTF8String];
    keychainStatus = SecKeychainFindGenericPassword(NULL, 0, NULL, (UInt32)strlen(keychainItemName), keychainItemName, &passwordLength, (void**)&passwordData, NULL);

    if (keychainStatus == errSecSuccess) {
        ret = [[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding];
    } else {
        logKeychainError(keychainStatus);
    }
    
    if (passwordData) {
        SecKeychainItemFreeContent(NULL, passwordData);
    }
    
    return ret;
}

- (void) storePassword:(NSString *)aPassword {
    tmpPassword = aPassword;
}

- (void) commitPassword {
    if (tmpPassword == NULL) {
        return;
    }
    
    const char *keychainItemName;
    const char *passwordData = [tmpPassword UTF8String];
    keychainItemName = [[self currentURLForKeychain] UTF8String];
    
    OSStatus keychainStatus = SecKeychainAddGenericPassword(NULL, 0, NULL, (UInt32)strlen(keychainItemName), keychainItemName, (UInt32)strlen(passwordData), passwordData, NULL);
    
    switch(keychainStatus) {
        case errSecSuccess:
            break;
        case errSecAuthFailed:
            // Acknowledge that the user didn't
            break;
        case errSecDuplicateItem: {
            // We need to update not add
            SecKeychainItemRef itemRef;
            keychainStatus = SecKeychainFindGenericPassword(NULL, 0, NULL, (UInt32)strlen(keychainItemName), keychainItemName, NULL, NULL, &itemRef);
            if (keychainStatus != errSecSuccess) {
                NSLog(@"Couldn't find the old password??");
                logKeychainError(keychainStatus);
                return;
            }
            
            // Check status
            keychainStatus = SecKeychainItemModifyAttributesAndData (itemRef, NULL, (UInt32)strlen(passwordData), passwordData);
            if (keychainStatus != errSecSuccess) {
                NSLog(@"Couldn't commit the new password.");
                logKeychainError(keychainStatus);
                return;
            }
            
            if (itemRef) {
                CFRelease(itemRef);
            }
            
            break;
        }
        default: {
            logKeychainError(keychainStatus);
            break;
        }
    }
    
    tmpPassword = NULL;
}
@end

@implementation CCFileTransferWindowController (URLTextField)

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
    NSDictionary *userInfo = [aNotification userInfo];
    NSNumber *reason = [userInfo objectForKey:@"NSTextMovement"];

    // http://stackoverflow.com/questions/9143353/nstextmovement-values
    switch ([reason intValue]) {
        case NSReturnTextMovement: {
            if ([txtURL isEditable] == YES) {
                [self connectWasClicked:nil];
            }
            return;
        }
        case NSIllegalTextMovement: // Also NSOtherTextMovement
        case NSTabTextMovement:
        case NSBacktabTextMovement:
        case NSLeftTextMovement:
        case NSRightTextMovement:
        case NSUpTextMovement:
        case NSDownTextMovement:
        case NSCancelTextMovement:
        default:
            return;
    }
    
}

@end

@implementation CCFileTransferWindowController (ActionButton)

- (IBAction)getInfoWasClicked:(id)sender {
    NSArray *ourObjects = [self.ctlCWD selectedObjects];

    // Right now we don't support selecting multiple objects
    if ([ourObjects count] != 1) {
        return;
    }

    [sheetGetInfo makeKeyAndOrderFront:nil]; // to show it
}

- (IBAction)downloadWasClicked:(id)sender {
    for (CCDirectoryEntry *dirent in [self.ctlCWD selectedObjects]) {
        [self.ctlCWD downloadAnObject:dirent];
    }
}

@end
