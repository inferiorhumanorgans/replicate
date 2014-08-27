//
//  CCMainWindowControllerTests.m
//  Replicate
//
//  Created by Alex Zepeda on 8/11/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CCFileTransferWindowController.h"

@interface CCMainWindowControllerTests : XCTestCase {
    CCFileTransferWindowController *controller;
}

@end

@implementation CCMainWindowControllerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    controller = [[CCFileTransferWindowController alloc] init];
    XCTAssertNotNil(controller);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testShouldBeAbleToFindControllerFromSFTPScheme {
    id foo = [controller getFileTransferInstanceForScheme:@"sftp"];
    XCTAssertNotNil(foo);
}

- (void)testShouldBeAbleToFindControllerFromS3Scheme {
    id foo = [controller getFileTransferInstanceForScheme:@"s3"];
    XCTAssertNotNil(foo);
}

- (void)testShouldNotBeAbleToFindControllerFromBogusScheme {
    id foo = [controller getFileTransferInstanceForScheme:@"nope"];
    XCTAssertNil(foo);
}

@end
