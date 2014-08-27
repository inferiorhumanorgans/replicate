//
//  CCSFTPDirectorySource.m
//  Replicate
//
//  Created by Alex Zepeda on 8/3/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#include <libssh2_sftp.h>

#import "CCDirectoryEntry.h"
#import "CCSSH.h"

@implementation CCDirectoryEntry

@synthesize nodeType = _nodeType;
@synthesize path = _path;
@synthesize size = _size;
@synthesize mtime = _mtime;
@synthesize permissions = _permissions;

@synthesize targetPath = _targetPath;
@synthesize targetPermissions = _targetPermissions;

+ (CCDirectoryEntry *)direntFromAttributes:(NSString *)aPath size:(size_t)aSize mtime:(NSDate *)anMtime permissions:(NSUInteger)somePermissions owner:(NSString *)anOwner group:(NSString *)aGroup {
    CCDirectoryEntry *ret = [[CCDirectoryEntry alloc] initWithAttributes:aPath size:aSize mtime:anMtime permissions:somePermissions owner:anOwner group:aGroup];

    return ret;
}

- (id) initWithAttributes:(NSString *)aPath size:(size_t)aSize mtime:(NSDate *)anMtime permissions:(NSUInteger)somePermissions owner:(NSString *)anOwner group:(NSString *)aGroup {

    if ((self = [self init])) {
        _path = aPath;
        _size = aSize;
        _mtime = anMtime;
        _permissions = somePermissions;
        _owner = anOwner;
        _group = aGroup;
        [self syncType];
    }

    return self;
}

- (void)syncType {
    NSUInteger ourPermissions = LIBSSH2_SFTP_S_ISLNK(_permissions) ? _targetPermissions : _permissions;

    if (LIBSSH2_SFTP_S_ISDIR(ourPermissions)) {
        _nodeType = kDirentDirectory;
    } else if (LIBSSH2_SFTP_S_ISBLK(ourPermissions)) {
        _nodeType = kDirentBlockDevice;
    } else if (LIBSSH2_SFTP_S_ISCHR(ourPermissions)) {
        _nodeType = kDirentCharDevice;
    } else if (LIBSSH2_SFTP_S_ISSOCK(ourPermissions)) {
        _nodeType = kDirentSocket;
    } else if (LIBSSH2_SFTP_S_ISFIFO(ourPermissions)) {
        _nodeType = kDirentPipe;
    } else {
        _nodeType = kDirentFile;
    }
}

- (void) setPath:(NSString *)path {
    _path = path;
    [self syncType];
}

- (void) setSize:(size_t)size {
    _size = size;
    [self syncType];
}

- (void) setMtime:(NSDate *)mtime {
    _mtime = mtime;
    [self syncType];
}

- (void) setPermissions:(NSUInteger)permissions {
    _permissions = permissions;
    [self syncType];
}

- (void) setOwner:(NSString *)owner {
    _owner = owner;
    [self syncType];
}

- (void) setGroup:(NSString *)group {
    _group = group;
    [self syncType];
}

- (void) setTargetPath:(NSString *)targetPath {
    _targetPath = targetPath;
    [self syncType];
}

- (void) setTargetPerms:(NSUInteger)targetPermissions {
    _targetPermissions = targetPermissions;
    [self syncType];
}

- (BOOL) isSymlink {
    return LIBSSH2_SFTP_S_ISLNK(_permissions) ? YES : NO;
}

- (NSImage *)imageValue {
    NSImage *ourIcon, *base, *badge = NULL;
    if (_nodeType == kDirentDirectory) {
        base = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
    } else {
        if (self.isSymlink == YES) {
            base = [[NSWorkspace sharedWorkspace] iconForFileType:[_targetPath pathExtension]];
        } else {
            base = [[NSWorkspace sharedWorkspace] iconForFileType:[_path pathExtension]];
        }
        // ourIcon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIconResource)];
    }

    if (self.isSymlink == YES) {
        badge = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kAliasBadgeIcon)];
    }

    ourIcon = [[NSImage alloc] initWithSize:[base size]];
    [ourIcon lockFocus];

    NSRect newImageRect = CGRectZero;
    newImageRect.size = [ourIcon size];
    
    [base drawInRect:newImageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    if (badge) {
        [badge drawInRect:newImageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    }
    
    [ourIcon unlockFocus];

    return ourIcon;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p, Path: %@, Symlink: %@>",
            NSStringFromClass([self class]), self, _path, (self.isSymlink == YES) ? @"YES" : @"NO"];
}

- (NSString *)filename {
    return [_path lastPathComponent];
}

- (NSString *)kind {

    NSString *ourKind = nil;
    if ([self isSymlink] == YES) {
        ourKind = @"Alias";
    } else {
        switch (_nodeType) {
            case kDirentBlockDevice:
                ourKind = @"Block Device";
                break;
            case kDirentCharDevice:
                ourKind = @"Character Device";
                break;
            case kDirentDirectory:
                ourKind = @"Folder";
                break;
            case kDirentPipe:
                ourKind = @"FIFO";
                break;
            case kDirentSocket:
                ourKind = @"Socket";
                break;
            default:
                ourKind = @"File";
                break;
        }
    }

    return ourKind;
}

- (NSNumber *)sizeNumber {
    return [NSNumber numberWithUnsignedLongLong:_size];
}

- (NSString *)parentPath {
    return [_path stringByDeletingLastPathComponent];
}

- (NSString *)permissionsString {
    NSString *direntType;
    long ourPermissions = _permissions;

    if (self.isSymlink == YES) {
        direntType = @"l";
        ourPermissions = _targetPermissions;
    } else {
        switch (_nodeType) {
            case kDirentBlockDevice:
                direntType = @"b";
                break;
            case kDirentCharDevice:
                direntType = @"c";
                break;
            case kDirentDirectory:
                direntType = @"d";
                break;
            case kDirentPipe:
                direntType = @"p";
                break;
            case kDirentSocket:
                direntType = @"s";
                break;
            default:
                direntType = @"-";
                break;
        }
    }

    return [NSString stringWithFormat:@"%@ %@%@%@ %@%@%@ %@%@%@",
            direntType,
            (ourPermissions & LIBSSH2_SFTP_S_IRUSR) ? @"r" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IWUSR) ? @"w" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IXUSR) ? @"x" : @"-",

            (ourPermissions & LIBSSH2_SFTP_S_IRGRP) ? @"r" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IWGRP) ? @"w" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IXGRP) ? @"x" : @"-",

            (ourPermissions & LIBSSH2_SFTP_S_IROTH) ? @"r" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IWOTH) ? @"w" : @"-",
            (ourPermissions & LIBSSH2_SFTP_S_IXOTH) ? @"x" : @"-"
            ];
}

@end
