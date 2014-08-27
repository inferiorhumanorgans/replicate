//
//  CCKeyManagement.m
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCKeyManagement.h"
#import "CCInterrogationProtocol.h"

@implementation CCKeyManagement
+ (NSString *)GetKeyPassword {
    
    NSString *keyPath = [@"~/.ssh/id_rsa" stringByExpandingTildeInPath];
    NSString *ret = NULL;
    const char *utfKeyPath = [keyPath UTF8String];

    char *passwordData = 0;
    UInt32 passwordLength;

    OSStatus status = SecKeychainFindGenericPassword (NULL, 0, NULL, (UInt32)strlen(utfKeyPath), utfKeyPath, &passwordLength, (void**)&passwordData, NULL);
    if (status == errSecSuccess) {
        ret = [NSString stringWithUTF8String:passwordData];
    } else {
        ret = @"";
    }

    if (passwordData) {
        SecKeychainItemFreeContent(NULL, passwordData);
    }

    return(ret);
}

@end

void kbd_callback(const char *name, size_t name_len,
                         const char *instruction, size_t instruction_len, int num_prompts,
                         const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                         LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                         void **abstract)
{
    NSObject<CCInterrogationProtocol> *controller = (__bridge NSObject<CCInterrogationProtocol> *)*abstract;

    NSLog(@"Performing keyboard-interactive authentication.");
    NSLog(@"Number of prompts: %d", num_prompts);

    for (int i = 0; i < num_prompts; i++) {
        NSString *prompt = [[NSString alloc] initWithBytes:prompts[i].text length:prompts[i].length encoding:NSUTF8StringEncoding];
        NSString *answer = nil;

        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^Password for.*:$" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:prompt options:0 range:NSMakeRange(0, [prompt length])];

        if (numberOfMatches > 0) {
            answer = [controller getPassword];
        }

        if ([answer length] == 0) {
            answer = [controller getAnswerForQuestion:prompt];
            [controller storePassword:answer];
        }

        if ([answer length] > 0) {
            responses[i].text = strdup([answer UTF8String]);
            responses[i].length = (unsigned int)strlen(responses[i].text);
        } else {
            NSLog(@"Abort input");
            return;
        }
    }
}
