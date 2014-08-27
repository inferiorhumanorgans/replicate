//
//  CCSheetController.h
//  Replicate
//
//  Created by Alex Zepeda on 8/3/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CCSheetController : NSWindowController {
    IBOutlet id inputSheet;
    IBOutlet id mainWindow;
}

- (IBAction)startInput:(id)sender;
- (IBAction)finishedInput:(id)sender;
@end
