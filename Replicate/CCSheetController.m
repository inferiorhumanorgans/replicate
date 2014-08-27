//
//  CCSheetController.m
//  Replicate
//
//  Created by Alex Zepeda on 8/3/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCSheetController.h"

@interface CCSheetController ()

@end

@implementation CCSheetController

- (IBAction)startInput:(id)sender
{
    [NSApp beginSheet:inputSheet modalForWindow:mainWindow
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (IBAction)finishedInput:(id)sender
{
    [inputSheet orderOut:nil];
    [NSApp endSheet:inputSheet];
}

@end
