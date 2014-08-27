//
//  main.m
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[])
{
    signal(SIGPIPE, SIG_IGN);
    return NSApplicationMain(argc, argv);
}
