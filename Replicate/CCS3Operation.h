//
//  CCS3Operation.h
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCInterrogationProtocol.h"

@class CCFileTransferWindowController;

@interface CCS3Operation : NSObject {
    dispatch_queue_t dqtTransfer;
    NSURL *theURL;

    NSDate *theDate;

    NSString *awsRegion;
    NSString *awsService;
    NSString *awsBucket;
    NSString *awsObject;
    NSString *awsParameters;
    BOOL isAnonymous;
    NSDictionary *theOptions;

    NSMutableDictionary *additionalHeaders;
    NSXMLDocument *xmlResponse;
    NSInteger httpStatusCode;
    NSObject<CCInterrogationProtocol> *controller;
}

// Default execute blobs.  Assumes no controller or block
- (id)execute;

// Execute the S3 operation with a block (nil is OK).  Queries the S3 endpoint and
// parses the results with executeWithXML:(NSXMLDocument *)someXML usingBlock:(void (^)(NSData *))aBlock
- (id)executeUsingBlock:(void(^)(NSData *))aBlock;

// Parses the XML results mostly split out this way for testing.
- (id)executeWithXML:(NSXMLDocument *)someXML usingBlock:(void (^)(NSData *))aBlock;

- (id)initWithOptions:(NSDictionary *)someOptions andController:(NSObject<CCInterrogationProtocol> *)aController;

+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController;
+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController andOptions:(NSDictionary *)someOptions;
+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController andOptions:(NSDictionary *)someOptions andBlock:(void(^)(NSData *))aBlock;

@end
