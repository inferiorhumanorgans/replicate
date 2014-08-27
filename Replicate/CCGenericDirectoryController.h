//
//  CCGenericDirectoryController.h
//  Replicate
//
//  Created by Alex Zepeda on 8/6/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CCFileTransferProtocol.h"

@class CCDirectoryEntry;

@interface CCGenericDirectoryController : NSArrayController <NSTableViewDataSource>

@property NSObject<CCFileTransferProtocol> *ssh;

- (void)downloadAnObject:(CCDirectoryEntry *)aDirent;

@end
