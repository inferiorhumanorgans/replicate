//
//  CCS3ObjectFetchOp.m
//  Replicate
//
//  Created by Alex Zepeda on 8/8/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3ObjectFetchOp.h"

@implementation CCS3ObjectFetchOp

- (id)initWithOptions:(NSDictionary *)someOptions andController:(NSObject<CCInterrogationProtocol> *)aController {
    if ((self = [super initWithOptions:someOptions andController:aController])) {
        awsObject = [someOptions objectForKey:@"object"];
        awsParameters = nil;
    }
    
    return self;
}

@end
