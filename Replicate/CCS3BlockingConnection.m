//
//  CCS3BlockingConnection.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3BlockingConnection.h"

@implementation CCS3BlockingConnection

@synthesize responseStatusCode;

- (id)initWithRequest:(NSURLRequest *)aRequest andCallback:(void(^)(NSData* data))aCallback {
    if (self = [super init]) {
        self.lock = [CCS3Semaphore new];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSURLConnection connectionWithRequest:aRequest delegate:self];
            while(!self.lock.finished) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
        });

        [self.lock consume:^(NSData* data) {
            if (aCallback != nil) {
                aCallback(data);
            }
            data = nil;
        }];
    }
    return self;
}

+ (NSInteger) connectionWithURL:(NSURL *)aUrl callback:(void(^)(NSData* data))aCallback {
    NSURLRequest *ourRequest = [NSURLRequest requestWithURL:aUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    return [CCS3BlockingConnection connectionWithRequest:ourRequest callback:aCallback];
}

+ (NSInteger) connectionWithRequest:(NSURLRequest *)aRequest callback:(void(^)(NSData* data))aCallback {
    CCS3BlockingConnection *connection = [[CCS3BlockingConnection alloc] initWithRequest:aRequest andCallback:aCallback];
    return connection.responseStatusCode;
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    if ([connection isKindOfClass:[NSHTTPURLResponse class]] == YES) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        self.responseStatusCode = [httpResponse statusCode];
    } else {
        self.responseStatusCode = -1;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.lock produce:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.lock produce:nil];
    [self.lock finish];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.lock finish];
}
@end
