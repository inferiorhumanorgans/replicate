//
//  CCS3Semaphore.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3Semaphore.h"

@implementation CCS3Semaphore

- (id)init {
    if (self = [super init]) {
        consumerSemaphore = dispatch_semaphore_create(0);
        producerSemaphore = dispatch_semaphore_create(0);
        _finished = NO;
    }
    return self;
}

- (void) consume:(void(^)(id)) block {
    BOOL finished = NO;
    while (!finished) {
        dispatch_semaphore_wait(consumerSemaphore, DISPATCH_TIME_FOREVER);
        finished = _finished;
        if (!finished) {
            block(_object);
            dispatch_semaphore_signal(producerSemaphore);
        }
    }
}

- (void) produce:(id) object {
    _object = object;
    _finished = NO;
    dispatch_semaphore_signal(consumerSemaphore);
    dispatch_semaphore_wait(producerSemaphore, DISPATCH_TIME_FOREVER);
}

- (void) finish {
    _finished = YES;
    dispatch_semaphore_signal(consumerSemaphore);
}

@end
