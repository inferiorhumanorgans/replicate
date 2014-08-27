//
//  CCS3.h
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCFileTransferBase.h"

@interface CCS3 : CCFileTransferBase<CCFileTransferProtocol> {
    dispatch_queue_t dqtControl, dqtTransfer;
    id lockToken;
    NSString *currentDirectory;
    NSMutableDictionary *currentDirectoryContents;
    NSString *awsAccessKey;
    NSString *awsSecretKey;
    NSString *awsRegion;
}

@end
