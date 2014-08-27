//
//  CCS3Semaphore.h
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// http://stackoverflow.com/questions/13733124/nsurlconnection-blocking-wrapper-implemented-with-semaphores

@interface CCS3Semaphore : NSObject {
    dispatch_semaphore_t consumerSemaphore;
    dispatch_semaphore_t producerSemaphore;
    NSObject* _object;
}

@property (atomic, readonly) BOOL finished;

- (void) consume:(void(^)(id object)) block;
- (void) produce:(id) object;
- (void) finish;

@end
