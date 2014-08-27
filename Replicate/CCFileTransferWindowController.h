//
//  CCFileTransferWindowController.h
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CCInterrogationProtocol.h"
#import "CCFileTransferBase.h"

struct CCSFTPPrivate;

@class CCSFTPDirectorySource;
@class CCGenericDirectoryController;
@class CCDirectoryEntry;

@interface CCFileTransferWindowController : NSWindowController {
    IBOutlet NSPanel             *sheetGetInfo;

    IBOutlet NSPanel             *sheetInterrogation;
    IBOutlet NSTextField         *txtAnswer;
    IBOutlet NSTextField         *txtQuestion;

    IBOutlet NSTextField         *txtURL;

    IBOutlet NSToolbar           *ourToolbar;

    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSProgressIndicator *progressBar;

    NSMutableArray               *aryHistory;
    int                          historyPosition;

    CCFileTransferBase<CCFileTransferProtocol> *ssh;
    CCFTPState status;

    NSString *tmpPassword;
}

@property IBOutlet NSPathControl                *pathCWD;
@property IBOutlet NSTableView                  *tblCWD;
@property NSMutableArray                        *aryCWD;
@property IBOutlet CCGenericDirectoryController *ctlCWD;
@property CCDirectoryEntry                      *curDirent;

// Toggles the progress spinner
- (void)progress:(BOOL)isBusy;

- (NSURL *)currentURL;
- (NSString *)currentURLForKeychain;
- (void)setTitleForStatus:(CCFTPState)aStatus;
- (void)statusDidChange:(NSNotification *)aNotification;
- (int)getPort;
- (id)getFileTransferInstanceForScheme:(NSString *)aScheme;

- (IBAction)connectWasClicked:(id)sender;
- (IBAction)bookmarksWereClicked:(id)sender;
- (IBAction)refreshWasClicked:(id)sender;
- (IBAction)pathBarWasClicked:(id)sender;
- (IBAction)backWasClicked:(id)sender;

// Spits out the window's history stack w/ NSLog
- (void)dumpHistory;

// Adds a history item to the stack
- (void)addHistory:(NSString *)aDirectory;

// Changes the current directory to the entry at position aPosition in the history stack
- (void)goToHistoryAt:(int)aPosition;

@end

@interface CCFileTransferWindowController (Interrogation) <CCInterrogationProtocol>
@end

@interface CCFileTransferWindowController (URLTextField)
- (void)controlTextDidEndEditing:(NSNotification *)aNotification;
@end

@interface CCFileTransferWindowController (ActionButton)
- (IBAction)getInfoWasClicked:(id)sender;
- (IBAction)downloadWasClicked:(id)sender;
@end
