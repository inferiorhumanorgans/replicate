//
//  ReplicateTests.m
//  ReplicateTests
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CCSSH.h"

@interface CCSSHTests : XCTestCase

@end

@implementation CCSSHTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitShouldReturnObject
{
    CCSSH *ssh = [[CCSSH alloc] init];
    XCTAssertNotNil(ssh);
}

@end
