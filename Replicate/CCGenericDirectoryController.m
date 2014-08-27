//
//  CCGenericDirectoryController.m
//  Replicate
//
//  Created by Alex Zepeda on 8/6/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCGenericDirectoryController.h"

#include "libssh2_sftp.h"

#import "CCSSH.h"
#import "CCDirectoryEntry.h"

@implementation CCGenericDirectoryController

@synthesize ssh;

- (void) awakeFromNib {
    
}


- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
    [session enumerateDraggingItemsWithOptions:0
                                            forView:tableView
                                            classes:[NSArray arrayWithObject:[NSPasteboardItem class]]
                                      searchOptions:nil
                                         usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
                                             draggingItem.imageComponentsProvider = ^(void) {
                                                 NSUInteger       rowIdx    = [rowIndexes indexGreaterThanOrEqualToIndex:idx];
                                                 CCDirectoryEntry *dirent   = [[self arrangedObjects] objectAtIndex:rowIdx];
                                                 NSString         *filename = [dirent filename];

                                                 NSDraggingImageComponent *component;
                                                 NSMutableArray           *components = [NSMutableArray arrayWithCapacity:2];
 
                                                 component = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
                                                 component.frame = NSMakeRect(0, 0, 16, 16);
                                                 component.contents = [dirent imageValue];
                                                 [components addObject:component];

                                                 NSRect theRect = [filename boundingRectWithSize:component.frame.size options:0 attributes:nil];
                                                 NSSize theSize = NSMakeSize(ceil(theRect.size.width), ceil(theRect.size.height));

                                                 component = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
                                                 component.frame = CGRectIntegral(NSMakeRect(20.25, 0.25, theSize.width, theSize.height));
                                                 component.contents = [[NSImage alloc] initWithSize:theSize];
                                                 
                                                 [component.contents lockFocus];
                                                 [filename drawAtPoint:NSZeroPoint withAttributes:nil];
                                                 [component.contents unlockFocus];

                                                 [components addObject:component];
                                                 
                                                 return components;
                                             };

                                             *stop = NO;
                                         }];
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *filenameExtensions = [NSMutableArray array];
    NSArray *draggedFilenames = [self.arrangedObjects objectsAtIndexes:rowIndexes];
    for (CCDirectoryEntry *dirent in draggedFilenames) {
        NSLog(@"Dirent: %@", dirent);
        [filenameExtensions addObject:[[dirent filename] pathExtension]];
    }
    
    if ([filenameExtensions count] > 0) {
        [pboard declareTypes:[NSArray arrayWithObjects:NSFilesPromisePboardType, nil] owner:self];
        [pboard setPropertyList:filenameExtensions forType:NSFilesPromisePboardType];
    }
    return YES;
}

- (NSArray *)tableView:(NSTableView *)aTableView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedRowsWithIndexes:(NSIndexSet *)indexSet {
    NSLog(@"namesOfPromisedFilesDroppedAtDestination");
    NSArray *draggedFilenames = [self.arrangedObjects objectsAtIndexes:indexSet];
    NSMutableArray *filenames = [NSMutableArray array];
    for (CCDirectoryEntry *dirent in draggedFilenames) {
        NSString *filename = [dirent filename];
        NSString *destPath = [[dropDestination path] stringByAppendingPathComponent:filename];
        
        NSLog(@"Destination: %@, exists: %d", destPath, [[NSFileManager defaultManager] fileExistsAtPath:destPath]);
        // Prompt if overwriting!!!
        [ssh copyFileFrom:dirent.path to:destPath];
        [filenames addObject:filename];
    }
    NSLog(@"Returning: %@", filenames);
    return filenames;
}

- (void)downloadAnObject:(CCDirectoryEntry *)aDirent {
    if (aDirent.nodeType == kDirentDirectory) {
        NSLog(@"We don't support recursive downloading... yet");
        return;
    }

    NSString *dest = nil;
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setExtensionHidden:NO];
    [savePanel setCanCreateDirectories:YES];
    [savePanel setNameFieldStringValue:[aDirent filename]];
    
    NSInteger result = [savePanel runModal];
    
    if (result != NSOKButton) {
        NSLog(@"Cancelled");
        return;
    }
    
    dest = [[savePanel URL] path];
    [ssh copyFileFrom:aDirent.path to:dest];
}

- (void)doubleClick:(NSArray *)someSelectedObjects {
    // Right now we don't handle a double click with multple selected files
    if ([someSelectedObjects count] != 1) {
        return;
    }
    
    CCDirectoryEntry *dirent = [someSelectedObjects objectAtIndex:0];
    if (dirent.nodeType == kDirentDirectory) {
        [ssh changeDirectory:[dirent path]];
    } else {
        [self downloadAnObject:dirent];
    }
}

@end
