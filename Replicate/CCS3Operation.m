//
//  CCS3Operation.m
//  Replicate
//
//  Created by Alex Zepeda on 8/7/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

NSString *emptyPayloadHash  = @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

#import "CCS3Operation.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

#import "CCS3BlockingConnection.h"

static NSData *sha256(NSData *salt, NSData *data)
{
    CCHmacContext context;
    
    CCHmacInit(&context, kCCHmacAlgSHA256, [salt bytes], [salt length]);

    if (data) {
        CCHmacUpdate(&context, [data bytes], [data length]);
    }
    
    unsigned char digestRaw[CC_SHA256_DIGEST_LENGTH];
    NSInteger digestLength = CC_SHA256_DIGEST_LENGTH;
    
    CCHmacFinal(&context, digestRaw);
    
    return [NSData dataWithBytes:digestRaw length:digestLength];}

static NSString *sha256Hex(NSData *salt, NSData *data)
{
    NSString *hash;
    const char *cHMAC = [sha256(salt, data) bytes];
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02hhx", cHMAC[i]];
    hash = output;
    return hash;
}

static NSString *hexEncode(NSString *string) {
    NSUInteger len = [string length];
    unichar *chars = malloc(len * sizeof(unichar));
    
    [string getCharacters:chars];
    
    NSMutableString *hexString = [NSMutableString new];
    for (NSUInteger i = 0; i < len; i++) {
        if ((int)chars[i] < 16) {
            [hexString appendString:@"0"];
        }
        [hexString appendString:[NSString stringWithFormat:@"%x", chars[i]]];
    }
    free(chars);
    
    return hexString;
}


static NSString *hashString(NSString *stringToHash) {
    NSData *dataToHash = [stringToHash dataUsingEncoding:NSUTF8StringEncoding];

    if ([dataToHash length] > UINT32_MAX) {
        return nil;
    }

    const void *cStr = [dataToHash bytes];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    
    CC_SHA256(cStr, (uint32_t)[dataToHash length], result);
    
    NSData *hash = [[NSData alloc] initWithBytes:result length:CC_SHA256_DIGEST_LENGTH];

    return [[NSString alloc] initWithData:hash encoding:NSASCIIStringEncoding];
}

@implementation CCS3Operation

- (id)init {
    if ((self = [super init])) {
        dqtTransfer = nil;

        awsBucket = nil;
        awsObject = nil;

        awsRegion = @"us-east-1";
        awsService = @"s3";

        awsParameters = nil;
    }

    return self;
}

- (id)initWithOptions:(NSDictionary *)someOptions andController:(NSObject<CCInterrogationProtocol> *)aController {
    if ((self = [self init])) {
        theOptions = someOptions;

        NSURL *repURL = [theOptions objectForKey:@"URL"];

        awsBucket = [repURL host];
        isAnonymous = ([repURL user] == nil) ? YES : NO;
        additionalHeaders = [NSMutableDictionary dictionary];
        controller = aController;

        awsRegion = [someOptions objectForKey:@"aws-region"];
        if (awsRegion == nil) {
            awsRegion = @"us-east-1";
        }
    }

    return self;
}

+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController {
    return [CCS3Operation excecuteNamedOperation:anOperation withController:aController andOptions:nil];
}

+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController andOptions:(NSDictionary *)someOptions {
    return [CCS3Operation excecuteNamedOperation:anOperation withController:aController andOptions:someOptions andBlock:nil];
}

+ (id)excecuteNamedOperation:(NSString *)anOperation withController:(NSObject<CCInterrogationProtocol> *)aController andOptions:(NSDictionary *)someOptions andBlock:(void(^)(NSData *))aBlock {
    CCS3Operation *op = [NSClassFromString([NSString stringWithFormat:@"CCS3%@Op", anOperation]) alloc];
    return [[op initWithOptions:someOptions andController:aController] executeUsingBlock:aBlock];
}


- (NSString *)canonicalRequest {
    NSMutableDictionary *canonicalDictionary = [NSMutableDictionary dictionaryWithCapacity:[additionalHeaders count] + 1];
    for (NSString *header in additionalHeaders) {
        [canonicalDictionary setObject:additionalHeaders[header] forKey: header];
    }
    [canonicalDictionary setObject:[theURL host] forKey:@"host"];

    NSArray *signedHeaders = [[[canonicalDictionary allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] mutableCopy];

    NSMutableArray *canonicalHeaders = [NSMutableArray arrayWithCapacity:[canonicalDictionary count]];
    for (NSString *header in signedHeaders) {
        [canonicalHeaders addObject:[NSString stringWithFormat:@"%@:%@", header, canonicalDictionary[header]]];
    }

    NSString *query = NULL;
    if ([theURL query] != nil) {
        // http://cybersam.com/ios-dev/proper-url-percent-encoding-in-ios
        CFStringRef tmp = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) [theURL query], NULL, (CFStringRef) @"!*'();:@+$,/?%#[]", kCFStringEncodingUTF8);
        query = [(__bridge NSString *)tmp copy];
        CFRelease(tmp);
    }
    
    NSString *canonicalRequest = [NSString
                                  stringWithFormat:@"%@\n%@\n%@\n%@\n\n%@\n%@",
                                  @"GET",                                           // HTTPMethod
                                  [theURL path],                                    // CanonicalURI
                                  [theURL query] ? query : @"",            // CanonicalQueryString
                                  [canonicalHeaders componentsJoinedByString:@"\n"],// CanonicalHeaders
                                  [signedHeaders componentsJoinedByString:@";"],    // SignedHeaders
                                  emptyPayloadHash                                  // HashedPayload
                                  ];

    return canonicalRequest;
}

- (NSString *)scope {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyyMMdd"];

    NSString *awsScope = [NSString stringWithFormat:@"%@/%@/%@/aws4_request",
                          [dateFormatter stringFromDate:theDate],
                          awsRegion,
                          awsService
                         ];

    dateFormatter = nil;
    return awsScope;
}

- (NSString *)stringToSign {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyyMMdd"];

    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
    NSString *stringToSign = [NSString stringWithFormat:@"AWS4-HMAC-SHA256\n%@\n%@\n%@",
                              [dateFormatter stringFromDate:theDate],
                              [self scope],
                              hexEncode(hashString([self canonicalRequest]))
                              ];
    dateFormatter = nil;
    return stringToSign;
}

- (NSString *)authorizationHeaderForURLRequest:(NSMutableURLRequest *)aRequest {
    [additionalHeaders setObject:emptyPayloadHash forKey:@"x-amz-content-sha256"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyyMMdd"];

    NSString *password = [controller getPassword];

    if ([password length] == 0) {
        password = [controller getAnswerForQuestion:@"Password:"];
        [controller storePassword:password];
    }

    NSData *signature = sha256([[NSString stringWithFormat:@"AWS4%@", password]
                                dataUsingEncoding:NSASCIIStringEncoding],
                               [[dateFormatter stringFromDate:theDate] dataUsingEncoding:NSASCIIStringEncoding]);
    password = nil;
    signature = sha256(signature, [awsRegion dataUsingEncoding:NSASCIIStringEncoding]);
    signature = sha256(signature, [awsService dataUsingEncoding:NSASCIIStringEncoding]);
    signature = sha256(signature, [@"aws4_request" dataUsingEncoding:NSASCIIStringEncoding]);
    
    NSString *FinalSignature = sha256Hex(signature, [[self stringToSign] dataUsingEncoding:NSASCIIStringEncoding]);
    
    NSString *authHeader = [NSString stringWithFormat:@"AWS4-HMAC-SHA256 Credential=%@/%@,SignedHeaders=host;x-amz-content-sha256,Signature=%@", [[theOptions objectForKey:@"URL"] user], [self scope], FinalSignature];

    [aRequest setValue:authHeader forHTTPHeaderField:@"Authorization"];

    dateFormatter = nil;
    return authHeader;
}

- (id)execute {
    return [self executeUsingBlock:nil];
}

- (id)executeUsingBlock:(void(^)(NSData *))aBlock {
    return [self executeWithXML:nil usingBlock:aBlock];
}

- (id)executeWithXML:(NSXMLDocument *)someXML usingBlock:(void (^)(NSData *))aBlock {
    NSMutableData *data = [NSMutableData data];
    theDate = [NSDate date];
    if (awsBucket) {
        theURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.s3.amazonaws.com/", awsBucket]];
        if (awsObject) {
            theURL = [NSURL URLWithString:awsObject relativeToURL:theURL];
        }

        if (awsParameters) {
            theURL = [NSURL URLWithString:awsParameters relativeToURL:theURL];
        }
    } else {
        theURL = [NSURL URLWithString:@"https://s3.amazonaws.com/"];
    }

    NSLog(@"URL: %@", [theURL absoluteString]);

    NSMutableURLRequest *ourRequest;

    if (someXML == nil) {
        ourRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
        // [ourRequest setHTTPMethod:@"HEAD"];
    } else {
        NSString *base64String = [[someXML XMLData] base64EncodedStringWithOptions:0];
        NSString *base64URL = [NSString stringWithFormat:@"data:text/xml;base64,%@", base64String];
        ourRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:base64URL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    }
    
    if (isAnonymous == NO) {
        [self authorizationHeaderForURLRequest:ourRequest];
    }

    // Wed, 01 Mar 2006 12:00:00 GMT
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
    [ourRequest setValue:[dateFormatter stringFromDate:theDate] forHTTPHeaderField:@"Date"];
    
    for (NSString *header in additionalHeaders) {
        if ([header compare:@"host"] != NSOrderedSame) {
            [ourRequest setValue:additionalHeaders[header] forHTTPHeaderField:header];
        }
    }

    // Default block.  Copies everything to an NSData object and tries to parse it as if it's XML.
    void (^block)(NSData *) = ^(NSData *localData){
        if (localData != nil) {
            [data appendData:[localData copy]];
        } else {
            // An error occurred
            NSLog(@"Error?");
        }
    };

    httpStatusCode = [CCS3BlockingConnection connectionWithRequest:ourRequest callback:((aBlock != nil) ? aBlock : block)];

    // We should probably check for httpStatusCode == -1 and not commit...
    switch(httpStatusCode) {
        case 400:
        case 403:
            break;
        default: {
            [controller commitPassword];
        }
    }
    if ([data length] > 0) {
        [data appendBytes:"\0" length:1];
        NSError *xmlError = nil;
        xmlResponse = [[NSXMLDocument alloc] initWithXMLString:[NSString stringWithUTF8String:[data bytes]] options:NSXMLDocumentTidyXML error:&xmlError];
    }

    //fprintf(stderr, "%s\n", [[xmlResponse XMLStringWithOptions:NSXMLNodePrettyPrint] UTF8String]);

    return xmlResponse;
}

@end
