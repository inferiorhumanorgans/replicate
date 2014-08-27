//
//  CCAppDelegate.h
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CCAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindowController *prefsController;
}

@property (assign) IBOutlet NSWindow       *prefsWindow;
@property (assign) IBOutlet NSWindow       *mainWindow;
@property (strong, nonatomic) NSMutableSet *windows;

- (IBAction) btnScanClicked:(id)sender;
- (IBAction)preferencesWasClicked:(id)sender;

@end
