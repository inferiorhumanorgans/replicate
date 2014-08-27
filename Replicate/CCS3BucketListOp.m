//
//  CCS3BucketList.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3BucketListOp.h"

#import "CCFileTransferBase.h"

@implementation CCS3BucketListOp

- (id)initWithOptions:(NSDictionary *)someOptions andController:(NSObject<CCInterrogationProtocol> *)aController {
    if ((self = [super initWithOptions:someOptions andController:aController])) {
        awsObject = nil;

        NSString *params;

        NSString *theDir = [someOptions objectForKey:@"directory"];
        if (theDir == nil) {
            params = nil;
        } else if ([theDir compare:@"/"] == NSOrderedSame) {
            params = @"?delimiter=/&marker=%MARKER%";
        } else {
            NSString *prefix = theDir;
            if ([prefix hasPrefix:@"/"]) {
                prefix = [NSString stringWithFormat:@"%@/", [prefix substringFromIndex:1]];
            }
            
            params = [NSString stringWithFormat:@"?delimiter=/&marker=%%MARKER%%&prefix=%@", prefix];
        }
        baseParams = params;
    }

    return self;
}

- (id)executeWithXML:(NSXMLDocument *)someXML usingBlock:(void (^)(NSData *))aBlock {
    NSError *error;
    NSMutableArray *contents;
    NSMutableSet *directories;
    NSArray *results = nil;
    BOOL truncated = YES;
    NSString *prefix = nil;
    NSUInteger prefixLen;

    NSMutableArray *directoryEntries = [NSMutableArray arrayWithCapacity:1000];
    NSMutableArray *fileEntries = [NSMutableArray arrayWithCapacity:1000];

    while (truncated == YES) {
        if (([directoryEntries count] == 0) && ([fileEntries count] == 0)) {
            awsParameters = [baseParams stringByReplacingOccurrencesOfString:@"&marker=%MARKER%" withString:@""];
        } else {
            results = [[fileEntries lastObject] nodesForXPath:@"./Key" error:nil];
            awsParameters = [baseParams stringByReplacingOccurrencesOfString:@"%MARKER%" withString:[[results firstObject] stringValue]];
        }
        [super executeWithXML:someXML usingBlock:aBlock];

        results = [xmlResponse nodesForXPath:@"/ListBucketResult/Prefix" error:&error];
        if ([results count] == 0) {
            NSLog(@"XML: %@", xmlResponse);
            return nil;
        }

        prefix = [[results objectAtIndex:0] stringValue];
        prefixLen = [prefix length];

        results = [xmlResponse nodesForXPath:@"/ListBucketResult/IsTruncated" error:nil];
        if ([results count] != 1) {
            NSLog(@"Error trying to determine if we've been truncated");
            return nil;
        }

        if ([[[results objectAtIndex:0] stringValue] compare:@"true"] == NSOrderedSame) {
            truncated = YES;
        } else {
            truncated = NO;
        }

        [directoryEntries addObjectsFromArray:[xmlResponse nodesForXPath:@"/ListBucketResult/CommonPrefixes" error:&error]];
        [fileEntries addObjectsFromArray: [xmlResponse nodesForXPath:@"/ListBucketResult/Contents" error:&error]];

        NSLog(@"Truncated: %@, %d", truncated == YES ? @"YES" : @"NO", [[xmlResponse nodesForXPath:@"/ListBucketResult/CommonPrefixes" error:&error] count] + [[xmlResponse nodesForXPath:@"/ListBucketResult/Contents" error:&error] count]);

    }

    contents = [NSMutableArray arrayWithCapacity:[directoryEntries count] + [fileEntries count]];
    directories = [NSMutableSet setWithCapacity:[directoryEntries count] + [fileEntries count]];

    NSLog(@"Directory Entries: %d", [directoryEntries count]);
    for (NSXMLNode *contentsNode in directoryEntries) {
        NSString *pathNode = [[contentsNode childAtIndex:0] stringValue];
        NSString *path = [pathNode substringFromIndex:prefixLen];
        path = [path substringToIndex:path.length-(path.length>0)];

        NSDictionary *node = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"!!isdir", path, nil] forKeys:[NSArray arrayWithObjects:@"isdir", CCStatDirent_Path, nil]];
 
        [directories addObject:path];
        [contents addObject:node];
    }
    directoryEntries = nil;

    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'.'SSS'Z'"];

    NSLog(@"File Entries: %d", [fileEntries count]);
    for (NSXMLNode *contentsNode in fileEntries) {
        // Key - 0
        NSString *contentPath = [[contentsNode childAtIndex:0] stringValue];
        NSString *path = [contentPath substringFromIndex:prefixLen];

        if (([path length] == 0) || ([directories containsObject:path] == YES)) {
            continue;
        }

        if ([path hasSuffix:@"_$folder$"] == YES) {
            NSString *folderName = [path substringToIndex:[path length] - 9];
            if ([directories containsObject:folderName] == NO) {
                NSDictionary *node = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"!!isdir", folderName, nil] forKeys:[NSArray arrayWithObjects:@"isdir", CCStatDirent_Path, nil]];
                
                [directories addObject:folderName];
                [contents addObject:node];
            }
            continue;
        }

        // Size
        NSString *contentSize = (NSString *)[NSNull null];
        results = [contentsNode nodesForXPath:@"./Size" error:nil];
        if ([results count] == 1) {
            contentSize = [[results objectAtIndex:0] stringValue];
        }
        NSNumber *fileSize = [NSNumber numberWithUnsignedLongLong:strtoull([contentSize UTF8String], NULL, 0)];

        // LastModified
        NSString *strLastModified = nil;
        NSDate *lastModified = (NSDate *)[NSNull null];
        results = [contentsNode nodesForXPath:@"./LastModified" error:nil];
        if ([results count] == 1) {
            strLastModified = [[results objectAtIndex:0] stringValue];
            lastModified = [dateFormatter dateFromString:strLastModified];
        }

        // Ownership
        NSString *ownerInfo = (NSString *)[NSNull null];
        results = [contentsNode nodesForXPath:@"./Owner/DisplayName" error:nil];
        if ([results count] == 1) {
            ownerInfo = [[results objectAtIndex:0] stringValue];
        }

        NSDictionary *node = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"!!isfile", path, fileSize, lastModified, ownerInfo, [NSNull null], nil] forKeys:[NSArray arrayWithObjects:@"isfile", CCStatDirent_Path, CCStatDirent_Size, CCStatDirent_LastModified, CCStatDirent_Owner, CCStatDirent_Group, nil]];

        [contents addObject:node];
    }
    fileEntries = nil;

    return contents;
}

@end
