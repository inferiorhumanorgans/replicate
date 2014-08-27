//
//  CCFileTransferProtocol.h
//  Replicate
//
//  Created by Alex Zepeda on 8/6/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCInterrogationProtocol.h"

typedef enum {
    kCCStatNULL,
    
    kCCStatDisconnected,
    kCCStatConnecting,
    kCCStatConnected,
    
    kCCStatHostVerificationFailed,
    kCCStatHostVerificationSucceeded,
    
    kCCStatAuthenticationSucceeded,
    kCCStatAuthenticationFailed,
    
    kCCStatTransferNew,
    kCCStatTransferUpdate,
    kCCStatTransferDone,
    
    kCCStatReady,
    
    kCCStatIdle,
    kCCStatBusy
} CCFTPState;

@protocol CCFileTransferProtocol <NSObject>

- (int)setupSession;

- (void)connect;
- (void)verifyHostKey;
- (void)authenticateWithServer;
- (void)initializeSFTP;
- (void)changeDirectory:(NSString *)aDirectory;
- (void)copyFileFrom:(NSString *)src to:(NSString *)dest;

- (NSString *)getCurrentDirectory;

@end
