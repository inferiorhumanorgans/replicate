//
//  CCAppDelegate.m
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCAppDelegate.h"
#import "CCFileTransferWindowController.h"

#include <libssh2.h>

@implementation CCAppDelegate

@synthesize mainWindow = _window;
@synthesize prefsWindow = _prefsWindow;

-(IBAction) btnScanClicked:(id)sender {
    CCFileTransferWindowController *controllerWindow = [[CCFileTransferWindowController alloc] initWithWindowNibName:@"CCFileTransferWindowController"];
    [controllerWindow showWindow:self];
    [self.windows addObject:controllerWindow];
}

- (IBAction)preferencesWasClicked:(id)sender {
    prefsController = [[NSWindowController alloc] initWithWindow:self.prefsWindow];
    [prefsController showWindow:nil];
}

- (void)windowWillCloseNotification:(NSNotification *)aNotification {
    if (aNotification.name != NSWindowWillCloseNotification) {
        NSLog(@"Spurious notification received at windowWillCloseNotification: %@", aNotification);
        return;
    }

    NSWindow *win = aNotification.object;
    if ([self.windows containsObject:win.windowController]) {
        [self.windows removeObject:win.windowController];
    } else {
        NSLog(@"Warned of impending window close on a window we known nothing about: %@", win);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.mainWindow setTitle:[[NSRunningApplication currentApplication] localizedName]];

    self.windows = [NSMutableSet set];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillCloseNotification:) name:NSWindowWillCloseNotification object:nil];

    int rc;
    if ((rc = libssh2_init(0))) {
        NSAlert *alert = [NSAlert
                          alertWithMessageText:[[NSRunningApplication currentApplication] localizedName]
                          defaultButton:@"OK"
                          alternateButton:nil
                          otherButton:nil
                          informativeTextWithFormat:@"libssh2 initialization failed (%d)\n", rc];
        [alert runModal];
        exit(-1);
    }
}

@end
