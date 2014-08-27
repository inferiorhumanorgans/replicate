//
//  CCSFTPDirectorySource.h
//  Replicate
//
//  Created by Alex Zepeda on 8/3/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kDirentSymlink,
    kDirentBlockDevice,
    kDirentCharDevice,
    kDirentDirectory,
    kDirentFile,
    kDirentPipe,
    kDirentSocket
} CCDirectoryEntryType;

@interface CCDirectoryEntry : NSObject<NSCopying>

/*
 Describes the type of file.  Ex: Block special file, character special file, directory, symbolic link, socket link, FIFO, regular file.
 */
@property CCDirectoryEntryType nodeType;

// Fully qualified path to the file (parent + filename)
@property (nonatomic, setter = setPath:)        NSString      *path;

// Size of the file in bytes
@property (nonatomic, setter = setSize:)        size_t        size;

// Last modification time
@property (nonatomic, setter = setMtime:)       NSDate        *mtime;

// File permissions
@property (nonatomic, setter = setPermissions:) NSUInteger    permissions;

// Owner
@property (nonatomic, setter = setOwner:)       NSString      *owner;

// Group
@property (nonatomic, setter = setGroup:)       NSString      *group;

// If file is a symlink, destination of symlink
@property (nonatomic, setter = setTargetPath:)  NSString      *targetPath;

// Permissions of symlink's destination
@property (nonatomic, setter = setTargetPerms:) NSUInteger    targetPermissions;

+ (CCDirectoryEntry *)direntFromAttributes:(NSString *)aPath size:(size_t)aSize mtime:(NSDate *)anMtime permissions:(NSUInteger)somePermissions owner:(NSString *)anOwner group:(NSString *)aGroup;

- (NSNumber *)sizeNumber;
- (NSString *)parentPath;
- (NSString *)permissionsString;

// Just the filename, no path
- (NSString *)filename;

// Text representation of the nodeType
- (NSString *)kind;

- (void) syncType;

- (BOOL) isSymlink;

- (NSImage *)imageValue;

@end
