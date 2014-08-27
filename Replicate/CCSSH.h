//
//  CCSSH.h
//  Replicate
//
//  Created by Alex Zepeda on 8/4/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCFileTransferBase.h"

@interface CCSSH : CCFileTransferBase<CCFileTransferProtocol> {
    struct CCSFTPPrivate *priv;

    dispatch_queue_t dqtControl, dqtTransfer;
    id lockToken;
    NSString *currentDirectory;
}

- (NSArray *)getSupportedAuthMethodsForUser:(NSString *)aUsername;

@end
