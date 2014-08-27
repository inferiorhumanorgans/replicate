//
//  CCFileTransferBase.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCFileTransferBase.h"
#import "CCFileTransferWindowController.h"

NSString *const CCNotificationStatusChanged  = @"CCNotificationStatusChanged";

NSString *const CCStatIdle_CurrentDirectory  = @"cwd";
NSString *const CCStatIdle_DirectoryContents = @"dirent";
NSString *const CCStatIdle_KeepAlive         = @"next-keep-alive";

NSString *const CCStatDirent_Owner           = @"owner";
NSString *const CCStatDirent_Group           = @"group";
NSString *const CCStatDirent_Size            = @"size";
NSString *const CCStatDirent_Path            = @"path";
NSString *const CCStatDirent_LastModified    = @"mtime";

NSString *const CCStatTransfer_Size          = @"transfer-size";

@implementation CCFileTransferBase

@synthesize port;
@synthesize controller;
@synthesize url;

- (id)initWithController:(id)aController {
    if ((self = [self init])) {
        self.controller = aController;
        [[NSNotificationCenter defaultCenter] addObserver:self.controller selector:@selector(statusDidChange:) name:CCNotificationStatusChanged object:self];
    }
    return self;
}

- (void) postStatusChanged:(CCFTPState)aStatus {
    [self postStatusChanged:aStatus withUserData:nil];
}

- (void) postStatusChanged:(CCFTPState)aStatus withUserKey:(id)aKey andValue:(id)aValue {
    @autoreleasepool {
        NSDictionary *dict = [NSDictionary dictionaryWithObject:aValue forKey:aKey];
        [self postStatusChanged:aStatus withUserData:dict];
        dict = NULL;
    }
}

- (void) postStatusChanged:(CCFTPState)aStatus withUserData:(NSDictionary *)someUserData {
    @autoreleasepool {
        currentState = aStatus;
        NSMutableDictionary *userData = [NSMutableDictionary dictionaryWithObject:[NSValue value: &aStatus withObjCType: @encode(CCFTPState)] forKey:@"Status"];
        if (someUserData) {
            [userData addEntriesFromDictionary:someUserData];
        }
        dispatch_async(dispatch_get_main_queue(), ^(void){
            NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
            [notify postNotification:[NSNotification notificationWithName:CCNotificationStatusChanged object:self userInfo:userData]];
        });
    }
}

- (void)closeSession {
    [self closeSessionWithReason:nil];
}

@end
