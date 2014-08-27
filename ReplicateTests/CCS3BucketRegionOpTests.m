//
//  CCS3BucketRegionOpTests.m
//  Replicate
//
//  Created by Alex Zepeda on 8/14/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CCS3BucketRegionOp.h"
#import "CCFileTransferBase.h"

@interface CCS3BucketRegionOpTests : XCTestCase {
    CCS3BucketRegionOp  *op;
    NSDictionary        *options;
}

@end

@implementation CCS3BucketRegionOpTests

- (void)setUp
{
    [super setUp];

    op = [CCS3BucketRegionOp alloc];

    NSMutableDictionary *ourOptions = [NSMutableDictionary dictionaryWithCapacity:5];
    [ourOptions setObject:[NSURL URLWithString:@"s3://nasanex/"] forKey:@"URL"];
    options = [ourOptions copy];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testLiveBucket
{
    NSString *ourTargetRegion = @"us-west-2";
    NSString *ourRegion = [[op initWithOptions:options andController:nil] executeWithXML:nil usingBlock:nil];
    XCTAssertEqualObjects(ourRegion, ourTargetRegion, @"Region should be %@", ourTargetRegion);
}

- (void)testSuccessfulXMLResponse {
    NSString *ourTargetRegion = @"us-west-99";
    NSString *rawXML = [NSString stringWithFormat:@"\
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>                                                              \
    <LocationConstraint xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">%@</LocationConstraint>   \
    ", ourTargetRegion];
    NSXMLDocument *testXML = [[NSXMLDocument alloc] initWithXMLString:rawXML options:NSXMLDocumentTidyXML error:nil];

    NSString *ourRegion = [[op initWithOptions:options andController:nil] executeWithXML:testXML usingBlock:nil];
    XCTAssertEqualObjects(ourRegion, ourTargetRegion, @"Region should be %@", ourTargetRegion);
}

- (void)testFailedXMLResponse {
    NSString *ourTargetRegion = @"us-west-99";
    NSString *rawXML = [NSString stringWithFormat:@"\
    <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\
    <Error>\
        <Code>AuthorizationHeaderMalformed</Code>\
        <Message>The authorization header is malformed; the region 'any' is wrong; expecting 'us-west-2'</Message>\
        <Region>%@</Region>\
        <RequestId>nonsense</RequestId>\
        <HostId>host/host</HostId>\
    </Error>\
    ", ourTargetRegion];
    NSXMLDocument *testXML = [[NSXMLDocument alloc] initWithXMLString:rawXML options:NSXMLDocumentTidyXML error:nil];

    NSString *ourRegion = [[op initWithOptions:options andController:nil] executeWithXML:testXML usingBlock:nil];
    XCTAssertEqualObjects(ourRegion, ourTargetRegion, @"Region should be %@", ourTargetRegion);
}

@end
