//
//  CCS3BucketListOpTests.m
//  Replicate
//
//  Created by Alex Zepeda on 8/11/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CCS3BucketListOp.h"
#import "CCFileTransferBase.h"

@interface CCS3BucketListOpTests : XCTestCase {
    NSDictionary *options;

}

@end

@implementation CCS3BucketListOpTests

- (void)setUp {
    [super setUp];

    NSMutableDictionary *ourOptions = [NSMutableDictionary dictionaryWithCapacity:5];
    [ourOptions setObject:[NSURL URLWithString:@"s3://nasanex/"] forKey:@"URL"];
    [ourOptions setObject:@"/" forKey:@"directory"];
    [ourOptions setObject:@"us-east-1" forKey:@"aws-region"];
    options = [ourOptions copy];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOperationShouldListExpectedRootResults {
    NSArray *expectedResults;
    NSMutableArray *ourResults = [NSMutableArray arrayWithCapacity:6];
    
    for (NSString *dirname in [NSArray arrayWithObjects:@"AVHRR", @"Landsat", @"MODIS", @"NAIP", @"NEX-DCP30", @"NEX-GDDP", nil]) {
        [ourResults addObject:[NSDictionary
                               dictionaryWithObjects:[NSArray arrayWithObjects:@"!!isdir", dirname, nil]
                               forKeys:[NSArray arrayWithObjects:@"isdir", CCStatDirent_Path, nil]]];
    }
    
    expectedResults = [ourResults copy];

    NSString *rawXML = @"\
    <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>            \
        <ListBucketResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">\
            <Name>nasanex</Name>                                            \
            <Prefix></Prefix>                                               \
            <Marker></Marker>                                               \
            <MaxKeys>1000</MaxKeys>                                         \
            <Delimiter>/</Delimiter>                                        \
            <IsTruncated>false</IsTruncated>                                \
            <CommonPrefixes>                                                \
                <Prefix>AVHRR/</Prefix>                                     \
            </CommonPrefixes>                                               \
            <CommonPrefixes>                                                \
                <Prefix>Landsat/</Prefix>                                   \
            </CommonPrefixes>                                               \
            <CommonPrefixes>                                                \
                <Prefix>MODIS/</Prefix>                                     \
            </CommonPrefixes>                                               \
            <CommonPrefixes>                                                \
                <Prefix>NAIP/</Prefix>                                      \
            </CommonPrefixes>                                               \
            <CommonPrefixes>                                                \
                <Prefix>NEX-DCP30/</Prefix>                                 \
            </CommonPrefixes>                                               \
            <CommonPrefixes>                                                \
                <Prefix>NEX-GDDP/</Prefix>                                  \
            </CommonPrefixes>                                               \
        </ListBucketResult>                                                 \
    ";
    NSXMLDocument *testXML = [[NSXMLDocument alloc] initWithXMLString:rawXML options:NSXMLDocumentTidyXML error:nil];

    CCS3BucketListOp *op = [CCS3BucketListOp alloc];
    NSArray *directoryContents = [[op initWithOptions:options andController:nil] executeWithXML:testXML usingBlock:nil];
    for (NSDictionary *result in directoryContents) {
        NSString *filename = [result objectForKey:CCStatDirent_Path];
        XCTAssertEqual([expectedResults containsObject:result], YES, @"Results %@ should be in %@", filename, expectedResults);
    }

    XCTAssertEqual([directoryContents count], [expectedResults count], @"Bucket should contain the expected number of results");
}

@end
