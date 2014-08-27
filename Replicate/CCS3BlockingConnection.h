//
//  CCS3BlockingConnection.h
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCS3Semaphore.h"

@interface CCS3BlockingConnection : NSObject<NSURLConnectionDelegate>

@property CCS3Semaphore *lock;
@property NSInteger responseStatusCode;


- (id)initWithRequest:(NSURLRequest *)aUrl andCallback:(void(^)(NSData* data))aCallback;

+ (NSInteger) connectionWithURL:(NSURL*) url callback:(void(^)(NSData* data)) callback;
+ (NSInteger) connectionWithRequest:(NSURLRequest *)aRequest callback:(void(^)(NSData* data))aCallback;

@end
