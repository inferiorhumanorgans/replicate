//
//  CCS3.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCS3.h"

#import "CCS3Operation.h"
#import "CCDirectoryEntry.h"

@implementation CCS3

- init {
    if ((self = [super init])) {
        lockToken = [NSDate date];
        dqtControl = dispatch_queue_create([[NSString stringWithFormat:@"s3-control-queue-%@", lockToken] UTF8String], DISPATCH_QUEUE_SERIAL);
        dqtTransfer = dispatch_queue_create([[NSString stringWithFormat:@"s3-transfer-queue-%@", lockToken] UTF8String], DISPATCH_QUEUE_CONCURRENT);

        awsAccessKey = nil;
        awsSecretKey = nil;
    }
    return self;
}

- (int)setupSession {
    return 0;
}

- (void)closeSessionWithReason:(NSString *)aReason {
    [self postStatusChanged:kCCStatDisconnected];
}

- (void)connect {
    [self postStatusChanged:kCCStatConnecting];
    NSObject<CCInterrogationProtocol> *ourController = self.controller;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        self->awsAccessKey = [defaults stringForKey:@"awsAccessKey"];
        [defaults synchronize];

        NSMutableDictionary *opts = [NSMutableDictionary dictionaryWithCapacity:1];
        [opts setObject:self.url forKey:@"URL"];

        id ret = [CCS3Operation excecuteNamedOperation:@"BucketRegion" withController:ourController andOptions:opts];
        if (ret == nil) {
            [self postStatusChanged:kCCStatDisconnected];
        } else {
            self->awsRegion = ret;
            [self postStatusChanged:kCCStatConnected];
        }

    });
}

- (void)verifyHostKey {
    [self postStatusChanged:kCCStatReady];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self changeDirectory:@"/"];
    });
}

- (void)authenticateWithServer {
    
}

- (void)initializeSFTP {
    
}

- (void)changeDirectory:(NSString *)aDirectory {
    [self postStatusChanged:kCCStatBusy];
    NSObject<CCInterrogationProtocol> *ourController = self.controller;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            if ([aDirectory hasPrefix:@"/"] == YES) {
                self->currentDirectory = aDirectory;
            } else {
                self->currentDirectory = [self->currentDirectory stringByAppendingPathComponent:aDirectory];
            }

            NSLog(@"CD: %@", self->currentDirectory);
            NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:3];
            [options setObject:self.url forKey:@"URL"];
            [options setObject:self->currentDirectory forKey:@"directory"];
            [options setObject:self->awsRegion forKey:@"aws-region"];
            
            NSArray *tree = [CCS3Operation excecuteNamedOperation:@"BucketList" withController:ourController andOptions:options];

            if (tree == nil) {
                [self postStatusChanged:kCCStatDisconnected];
                return;
            }

            NSMutableArray *directoryContents = [NSMutableArray arrayWithCapacity:500];
            self->currentDirectoryContents = [NSMutableDictionary dictionaryWithCapacity:500];

            for (NSDictionary *node in tree) {
                CCDirectoryEntry *dirent = nil;
                int permissions = 0;
                if ([node objectForKey:@"isfile"]) {
                    permissions = (0100000 | 000666);
                } else if ([node objectForKey:@"isdir"]) {
                    // Is directory
                    permissions = (0040000 | 000555);
                }

                dirent = [CCDirectoryEntry
                          direntFromAttributes:[self->currentDirectory stringByAppendingPathComponent:[node objectForKey:CCStatDirent_Path]]
                          size:[[node objectForKey:CCStatDirent_Size] unsignedLongLongValue]
                          mtime:[node objectForKey:CCStatDirent_LastModified]
                          permissions:permissions
                          owner:[node objectForKey:CCStatDirent_Owner]
                          group:[node objectForKey:CCStatDirent_Group]
                          ];
                [directoryContents addObject:dirent];
                [self->currentDirectoryContents setObject:dirent forKey:[node objectForKey:CCStatDirent_Path]];
            }

            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setObject:self->currentDirectory forKey:CCStatIdle_CurrentDirectory];
            
            [userInfo setObject:directoryContents forKey:CCStatIdle_DirectoryContents];

            [self postStatusChanged:kCCStatIdle withUserData:userInfo];
        }
    });
}

- (void)copyFileFrom:(NSString *)src to:(NSString *)dest {
    NSLog(@"Fetch %@ to %@", src, dest);

    // Stat
    CCDirectoryEntry *dirent = [self->currentDirectoryContents objectForKey:[src lastPathComponent]];

    NSObject<CCInterrogationProtocol> *ourController = self.controller;
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObject:self.url forKey:@"URL"];
    [options setObject:src forKey:@"object"];
    [options setObject:self->awsRegion forKey:@"aws-region"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{


        int fd = open(dest.UTF8String, (O_RDWR | O_CREAT | O_TRUNC), (S_IRUSR | S_IWUSR));
        lseek(fd, 0, SEEK_SET);

        [self postStatusChanged:kCCStatTransferNew withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLongLong:dirent.size]];

        [CCS3Operation excecuteNamedOperation:@"ObjectFetch" withController:ourController andOptions:options andBlock:^(NSData *localData) {
            @autoreleasepool {
                if (localData != nil) {
                    write(fd, [localData bytes], [localData length]);
                    [self postStatusChanged:kCCStatTransferUpdate withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLongLong:[localData length]]];
                } else {
                    //an error occurred
                    NSLog(@"Error?");
                }
            }
        }];

        close(fd);
        [self postStatusChanged:kCCStatTransferDone withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLongLong:dirent.size]];
    });
}

- (NSString *)getCurrentDirectory {
    return currentDirectory;
}


@end
