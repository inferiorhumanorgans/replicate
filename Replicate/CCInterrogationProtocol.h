//
//  CCInterrogation.h
//  Replicate
//
//  Created by Alex Zepeda on 8/4/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CCInterrogationProtocol <NSObject>

- (NSString *) getAnswerForQuestion:(NSString *)aQuestion;
- (NSString *) getPassword;
- (void) storePassword:(NSString *)aPassword;
- (void) commitPassword;

@end
