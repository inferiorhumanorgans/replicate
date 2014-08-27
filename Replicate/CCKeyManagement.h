//
//  CCKeyManagement.h
//  Replicate
//
//  Created by Alex Zepeda on 8/2/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <libssh2.h>

@interface CCKeyManagement : NSObject
    + (NSString *)GetKeyPassword;
@end

void kbd_callback(const char *name, size_t name_len,
                         const char *instruction, size_t instruction_len, int num_prompts,
                         const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                         LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                         void **abstract);
