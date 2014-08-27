//
//  CCFileTransferBase.h
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCFileTransferProtocol.h"
#import "CCInterrogationProtocol.h"

@class CCFileTransferWindowController;

// Defines the string used for our back-front end notification mechanism
extern NSString *const CCNotificationStatusChanged;

// UserInfo keys for the kCCStatIdle status
extern NSString *const CCStatIdle_CurrentDirectory;
extern NSString *const CCStatIdle_DirectoryContents;
extern NSString *const CCStatIdle_KeepAlive;

extern NSString *const CCStatDirent_Owner;
extern NSString *const CCStatDirent_Group;
extern NSString *const CCStatDirent_Size;
extern NSString *const CCStatDirent_Path;
extern NSString *const CCStatDirent_LastModified;

// UserInfo keys for the kCCStatTransferNew, kCCStatTransferUpdate, and kCCStatTransferDone statuses
extern NSString *const CCStatTransfer_Size;
extern NSString *const CCStatTransfer_Path;


// http://stackoverflow.com/questions/15373783/where-to-put-common-code-for-optional-protocol-method-implementation
@interface CCFileTransferBase : NSObject {
    CCFTPState currentState;
}

@property (copy) NSURL    *url;
@property unsigned short  port;
@property (retain) NSObject<CCInterrogationProtocol> *controller;

- (id)initWithController:(NSObject<CCInterrogationProtocol> *)aController;

- (void) postStatusChanged:(CCFTPState)aStatus;
- (void) postStatusChanged:(CCFTPState)aStatus withUserKey:(id)aKey andValue:(id)aValue;
- (void) postStatusChanged:(CCFTPState)aStatus withUserData:(NSDictionary *)someUserData;

- (void)closeSessionWithReason:(NSString *)aReason;
- (void)closeSession;

@end
