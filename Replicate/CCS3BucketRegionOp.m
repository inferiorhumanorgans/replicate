//
//  CCS3BucketRegionOp.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3BucketRegionOp.h"

@implementation CCS3BucketRegionOp

- (id)initWithOptions:(NSDictionary *)someOptions andController:(NSObject<CCInterrogationProtocol> *)aController {
    if ((self = [super initWithOptions:someOptions andController:aController])) {
        awsObject = nil;
        awsRegion = @"any";
        awsParameters = @"?location=";
    }
    
    return self;
}

- (id)executeWithXML:(NSXMLDocument *)someXML usingBlock:(void (^)(NSData *))aBlock {
    NSXMLNode *region;
    NSError *error;
    NSArray *elements;

    [super executeWithXML:someXML usingBlock:aBlock];

    for (NSString *xpathQuery in [NSArray arrayWithObjects:@"/LocationConstraint", @"/Error/Region", nil]) {
        elements = [xmlResponse nodesForXPath:xpathQuery error:&error];

        // Some sort of XML parsing error, bail out for good
        if (error != nil) {
            return nil;
        }

        // Found a region, let's go with that.
        if ([elements count] == 1) {
            break;
        }
    }

    if ([elements count] < 1) {
        return nil;
    }

    region = [elements objectAtIndex:0];
    return [region stringValue];
}

@end
