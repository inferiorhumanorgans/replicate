//
//  CCSSH.m
//  Replicate
//
//  Created by Alex Zepeda on 8/4/14.
//  Copyright (c) 2014 Inferior Human Organs, Inc. All rights reserved.
//

#import "CCSSH.h"
#import "CCKeyManagement.h"
#import "CCDirectoryEntry.h"
#import "CCFileTransferWindowController.h"

#include <libssh2.h>
#include <libssh2_sftp.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#define CC_BUFSIZ 2048
#define CC_READBUFSIZ 102400

struct CCSFTPPrivate {
    int                 socket;
    struct sockaddr_in  sin;
    const char          *fingerprint;
    char                *userauthlist;
    
    LIBSSH2_SESSION     *session;
    LIBSSH2_SFTP        *sftp_session;
    LIBSSH2_SFTP_HANDLE *sftp_handle;
};

static int waitsocket(struct CCSFTPPrivate *d)
{
    struct timeval timeout;
    int rc;
    fd_set fd;
    fd_set *writefd = NULL;
    fd_set *readfd = NULL;
    int dir;
    
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    
    FD_ZERO(&fd);
    
    FD_SET(d->socket, &fd);
    
    /* now make sure we wait in the correct direction */
    if (d->session) {
        dir = libssh2_session_block_directions(d->session);

        if (dir & LIBSSH2_SESSION_BLOCK_INBOUND) {
            readfd = &fd;
        }
        
        if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND) {
            writefd = &fd;
        }
    } else {
        readfd = &fd;
        writefd = &fd;
    }
    
    rc = select(d->socket + 1, readfd, writefd, NULL, &timeout);

    return rc;
}

@implementation CCSSH

- init {
    if ((self = [super init])) {
        priv = malloc(sizeof(struct CCSFTPPrivate));
        memset(priv, 0, sizeof(struct CCSFTPPrivate));

        lockToken = [NSDate date];
        dqtControl = dispatch_queue_create([[NSString stringWithFormat:@"sftp-control-queue-%@", lockToken] UTF8String], DISPATCH_QUEUE_SERIAL);
        dqtTransfer = dispatch_queue_create([[NSString stringWithFormat:@"sftp-transfer-queue-%@", lockToken] UTF8String], DISPATCH_QUEUE_CONCURRENT);

        currentState = kCCStatNULL;
    }
    return self;
}

- (void)dealloc
{
    if (priv) {
        free(priv);
    }
    // Unregister for notifications
}

- (void)verifyHostKey {
    [self postStatusChanged:kCCStatBusy];

    __weak id localMutex = lockToken;
    struct CCSFTPPrivate *d = priv;

    dispatch_async(dqtControl, ^(void){
        NSLog(@"Verify host key");
        size_t len;
        int type;
        
        LIBSSH2_KNOWNHOSTS *known_hosts = NULL;
        @synchronized(localMutex) {
            known_hosts = libssh2_knownhost_init(d->session);
        }
        if (!known_hosts) {
            [self postStatusChanged:kCCStatHostVerificationFailed withUserKey:@"VerificationStatus" andValue:@"Couldn't find known hosts"];
            return;
        }
        
        NSString *known_hostsfile = [@"~/.ssh/known_hosts" stringByExpandingTildeInPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:known_hostsfile] != YES) {
            NSLog(@"Known hosts file doesn't appear to exist.");
        }

        libssh2_knownhost_readfile(known_hosts, [known_hostsfile UTF8String], LIBSSH2_KNOWNHOST_FILE_OPENSSH);

        const char *fingerprint = libssh2_session_hostkey(d->session, &len, &type);
        if (fingerprint) {
            struct libssh2_knownhost *host;
            switch(libssh2_knownhost_checkp(known_hosts, [[self.url host] UTF8String], self.port,
                                           fingerprint, len,
                                           (LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW),
                                            &host)) {
                case LIBSSH2_KNOWNHOST_CHECK_FAILURE:
                    [self postStatusChanged:kCCStatHostVerificationFailed withUserKey:@"VerificationStatus" andValue:@"Unknown error"];
                    break;
                case LIBSSH2_KNOWNHOST_CHECK_NOTFOUND:
                    [self postStatusChanged:kCCStatHostVerificationSucceeded withUserKey:@"VerificationStatus" andValue:@"Untrusted host"];
                    break;
                case LIBSSH2_KNOWNHOST_CHECK_MATCH:
                    [self postStatusChanged:kCCStatHostVerificationSucceeded];
                    break;
                case LIBSSH2_KNOWNHOST_CHECK_MISMATCH:
                    [self postStatusChanged:kCCStatHostVerificationFailed withUserKey:@"VerificationStatus" andValue:@"Keys don't match"];
                    break;
            }
        } else {
            [self postStatusChanged:kCCStatHostVerificationFailed withUserKey:@"VerificationStatus" andValue:@"Fingerprint couldn't be found"];
        }
        
        if (known_hosts) {
            libssh2_knownhost_free(known_hosts);
        }

        return;
    });
}

- (NSArray *)getSupportedAuthMethodsForUser:(NSString *)aUsername {
    const char *username_cstring = [aUsername UTF8String];
    const char *userauthlist;
    @synchronized(lockToken) {
        do {
            userauthlist = libssh2_userauth_list(priv->session, username_cstring, (unsigned int)strlen(username_cstring));
            if (!userauthlist) {
                if (libssh2_session_last_errno(priv->session) == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(priv);
                } else {
                    [self closeSessionWithReason:@"Failed to find valid authentication methods"];
                    return [NSArray array];
                }
            }
        } while (!userauthlist);
    }
    NSArray *chunks = [[NSString stringWithUTF8String:userauthlist] componentsSeparatedByString: @","];
    return chunks;
}

- (void)authenticateWithServer {
    [self postStatusChanged:kCCStatBusy];

    struct CCSFTPPrivate *d = priv;
    NSObject<CCInterrogationProtocol> *c = self.controller;

    dispatch_async(dqtControl, ^(void) {
        NSArray *authMethods = [self getSupportedAuthMethodsForUser:[self.url user]];
        NSLog(@"Auth methods: %@", authMethods);
        for (NSString *authMethod in authMethods) {
            NSLog(@"Trying %@ authentication", authMethod);
            if ([authMethod compare:@"publickey"] == NSOrderedSame) {
                // NEEDS LOCKING
                const char *privKeyPath = [[@"~/.ssh/id_rsa"stringByExpandingTildeInPath] UTF8String];
                const char *pubKeyPath = [[@"~/.ssh/id_rsa.pub" stringByExpandingTildeInPath] UTF8String];
                
                int retries = 2;
                int ret;
                const char *password = [[CCKeyManagement GetKeyPassword] UTF8String];

                libssh2_session_set_blocking(d->session, 1);
                do {
                    ret=libssh2_userauth_publickey_fromfile(d->session, [[self.url user] UTF8String], pubKeyPath, privKeyPath, password);
                    if ((ret == LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED) && (retries > 0)) {
                        NSString *input = [self.controller getAnswerForQuestion:@"Password for key:"];
                        
                        // If cancel was pressed
                        if ([input length] == 0) {
                            break;
                        }

                        password = [input UTF8String];
                        retries--;
                    }
                } while((ret == LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED) && (retries > 0));
                libssh2_session_set_blocking(d->session, 0);

                if (ret) {
                    NSLog(@"PubKey auth failed");
                } else {
                    [self postStatusChanged:kCCStatAuthenticationSucceeded withUserKey:@"AuthenticationMethod" andValue:authMethod];
                    return;
                }
            } else if ([authMethod compare:@"password"] == NSOrderedSame) {
                int ret;
                BOOL wasAsked = NO;
                NSString *theUsername = [self.url user];
                NSString *thePassword = [c getPassword];

                if ([thePassword length] == 0) {
                    thePassword = [c getAnswerForQuestion:@"Password:"];
                    wasAsked = YES;
                }

                libssh2_session_set_blocking(d->session, 1);
                ret = libssh2_userauth_password(d->session, [theUsername UTF8String], [thePassword UTF8String]);
                libssh2_session_set_blocking(d->session, 0);

                if (ret) {
                    NSLog(@"PasswordAuth failed");
                    thePassword = NULL;
                } else {
                    if (wasAsked == YES) {
                        [c storePassword:thePassword];
                        [c commitPassword];
                    }
                    [self postStatusChanged:kCCStatAuthenticationSucceeded withUserKey:@"AuthenticationMethod" andValue:authMethod];
                    return;
                }

            } else if ([authMethod compare:@"keyboard-interactive"] == NSOrderedSame) {
                libssh2_session_set_blocking(d->session, 1);
                int rc = libssh2_userauth_keyboard_interactive(d->session, [[self.url user] UTF8String], &kbd_callback);
                libssh2_session_set_blocking(d->session, 0);
                if (rc) {
                    NSLog(@"InteractiveAuth failed");
                    break;
                } else {
                    [[self controller] commitPassword];
                    [self postStatusChanged:kCCStatAuthenticationSucceeded withUserKey:@"AuthenticationMethod" andValue:authMethod];
                    return;
                }
            } else {
                NSLog(@"We don't know how to handle this kind of authentication");
            }
        }

        [self postStatusChanged:kCCStatAuthenticationFailed];
    });
    return;
}

- (int)setupSession {
    [self closeSession];
    currentDirectory = NULL;

    @synchronized(lockToken) {
        priv->session = libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)self.controller);
    }

    if (!priv->session) {
        printf("Session initialization failed\n");
        return -1;
    }

    @synchronized(lockToken) {
        libssh2_session_set_blocking(priv->session, 0);
        signal(SIGPIPE, SIG_IGN);
        libssh2_session_flag(priv->session, LIBSSH2_FLAG_SIGPIPE, 0);
        libssh2_session_flag(priv->session, LIBSSH2_FLAG_COMPRESS, 1);
    }
    return 0;
}

- (void)closeSessionWithReason:(NSString *)aReason {
    @synchronized(lockToken) {
        if (priv->session) {
            libssh2_session_disconnect(priv->session, "No Reason");
            libssh2_session_free(priv->session);
            priv->session = 0;
        }
    }
    [self postStatusChanged:kCCStatDisconnected];

    if (aReason == nil) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSAlert *alert = [NSAlert
                          alertWithMessageText:[[NSRunningApplication currentApplication] localizedName]
                          defaultButton:@"OK"
                          alternateButton:nil
                          otherButton:nil
                          informativeTextWithFormat:aReason];
        [alert runModal];
    });
}

- (void)connect {
    [self postStatusChanged:kCCStatBusy];

    __weak id localMutex = lockToken;
    struct CCSFTPPrivate *d = priv;

    // Fill in the username if it's missing.
    if ((self.url.user == nil) || (self.url.user.length == 0)) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:self.url resolvingAgainstBaseURL:NO];
        [urlComponents setUser:NSUserName()];
        self.url = [urlComponents URL];
    }
    

    // http://stackoverflow.com/questions/16283652/understanding-dispatch-async
    dispatch_async(dqtControl, ^(void) {
        [self postStatusChanged:kCCStatConnecting];

        int rc;

        struct hostent *hostinfo = gethostbyname([[self.url host] UTF8String]);

        if (!hostinfo) {
            [self closeSessionWithReason: [NSString stringWithFormat:@"Could not find host: %@", [self.url host]]];
            [self postStatusChanged:kCCStatDisconnected];
            return; // Error
        }

        @synchronized(localMutex) {
            d->socket = socket(AF_INET, SOCK_STREAM, 0);

            // Disable SIGPIPE -- in case the server suddenly closes the connection.
            int sockopt = 1;
            setsockopt(d->socket, SOL_SOCKET, SO_NOSIGPIPE, &sockopt, sizeof(sockopt));
            
            memset(&d->sin, 0, sizeof(struct sockaddr_in));
            d->sin.sin_family = AF_INET;
            d->sin.sin_port = htons(self.port);
            memcpy(&(d->sin.sin_addr.s_addr), hostinfo->h_addr_list[0], hostinfo->h_length);
            
            if (connect(d->socket, (struct sockaddr*)(&d->sin),
                        sizeof(struct sockaddr_in))) {
                [self closeSessionWithReason: [NSString stringWithFormat:@"Failed to connect to server: %s", strerror(errno)]];
                return; // Error
            }

            while ((rc = libssh2_session_handshake(d->session, d->socket)) == LIBSSH2_ERROR_EAGAIN) {
                waitsocket(d);
            }
        }

        if (rc) {
            [self closeSessionWithReason: [NSString stringWithFormat:@"Failure establishing SSH session: %d", rc]];
            return; // Error
        }
        [self postStatusChanged:kCCStatConnected];
        return;

    });
}

- (void)initializeSFTP {
    [self postStatusChanged:kCCStatBusy];

    __weak id localMutex = lockToken;
    struct CCSFTPPrivate *d = priv;

    dispatch_async(dqtControl, ^(void) {
        @synchronized(localMutex) {
            do {
                d->sftp_session = libssh2_sftp_init(d->session);
                if (!d->sftp_session) {
                    if (libssh2_session_last_errno(d->session) == LIBSSH2_ERROR_EAGAIN) {
                        waitsocket(d);
                    } else {
                        [self closeSessionWithReason:@"Failed to initialize SFTP subsystem"];
                        return;
                    }
                }
            } while (!d->sftp_session);
        }
        [self postStatusChanged:kCCStatReady];
    });

    [self changeDirectory:@"."];
}

- (void)changeDirectory:(NSString *)aDirectory {
    NSLog(@"Current state %d", currentState);

    id localMutex = lockToken;
    struct CCSFTPPrivate *d = priv;

    if (currentState == kCCStatDisconnected) {
        return;
    }
    [self postStatusChanged:kCCStatBusy];

    dispatch_async(dqtControl, ^(void){
        NSLog(@"cd %@", aDirectory);

        char buf[CC_BUFSIZ];
        NSString *newPath;
        NSMutableDictionary *userInfo;
        LIBSSH2_SFTP_HANDLE *hnd = NULL;

        if (!self->currentDirectory) {
            memset(&buf, 0, CC_BUFSIZ);
            @synchronized(localMutex) {
                int rc;
                while ((rc = libssh2_sftp_realpath(d->sftp_session, "", buf, CC_BUFSIZ-1)) < 0) {
                    if (rc == LIBSSH2_ERROR_EAGAIN) {
                        waitsocket(d);
                    } else {
                        // error
                        return;
                    }
                }
            }
            self->currentDirectory = [NSString stringWithUTF8String:buf];
        }

        if ([aDirectory hasPrefix:@"/"]) {
            newPath = aDirectory;
        } else {
            newPath = [[NSArray arrayWithObjects: self->currentDirectory, aDirectory, nil] componentsJoinedByString:@"/"];
        }

        memset(&buf, 0, CC_BUFSIZ);
        @synchronized(localMutex) {
            int rc;
            while ((rc = libssh2_sftp_realpath(d->sftp_session, [newPath UTF8String], buf, CC_BUFSIZ-1)) < 0) {
                if (rc == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(d);
                } else {
                    // error
                    return;
                }
            }

            do {
                hnd = libssh2_sftp_opendir(d->sftp_session, [newPath UTF8String]);
                if (!hnd) {
                    if (libssh2_session_last_errno(d->session) == LIBSSH2_ERROR_EAGAIN) {
                        waitsocket(d);
                    } else {
                        newPath = [self->currentDirectory copy];
                        if (!(hnd = libssh2_sftp_opendir(d->sftp_session, [newPath UTF8String]))) {
                            NSLog(@"Fuck.");
                            return;
                        }
                    }
                } else {
                    newPath = [NSString stringWithUTF8String:buf];
                }

            } while(!hnd);
        }

        LIBSSH2_SFTP_ATTRIBUTES stat;
        NSMutableArray *directoryContents = [NSMutableArray arrayWithCapacity:500];
 
        @synchronized(localMutex) {
            do {
                memset(&buf, 0, CC_BUFSIZ);
                memset(&stat, 0, sizeof(LIBSSH2_SFTP_ATTRIBUTES));

                ssize_t readDirRC = libssh2_sftp_readdir(hnd, buf, CC_BUFSIZ-1, &stat);
                CCDirectoryEntry *dirent = nil;
                if (readDirRC > 0) {
                    // Success
                    NSString *filename = [NSString stringWithUTF8String:buf];
                    dirent = [CCDirectoryEntry
                              direntFromAttributes: [newPath stringByAppendingPathComponent:filename]
                              size:                 stat.filesize
                              mtime:                [NSDate dateWithTimeIntervalSince1970:stat.mtime]
                              permissions:          stat.permissions
                              owner:                [NSString stringWithFormat:@"%lu", stat.uid]
                              group:                [NSString stringWithFormat:@"%lu", stat.gid]
                    ];

                    if ([dirent isSymlink]) {
                        NSString *fullLinkPath = [newPath stringByAppendingPathComponent:filename];
                        int rc;
                        LIBSSH2_SFTP_ATTRIBUTES symStatBuf;
                        const char *path = NULL;
                        char symBuf[CC_BUFSIZ];
                        memset(&symBuf, 0, CC_BUFSIZ);

                        path = [fullLinkPath UTF8String];
                        while ((rc = libssh2_sftp_realpath(d->sftp_session, path, symBuf, CC_BUFSIZ-1)) < 0) {
                            if (rc == LIBSSH2_ERROR_EAGAIN) {
                                waitsocket(d);
                            } else {
                                // error
                                return;
                            }
                        }

                        memset(&symStatBuf, 0, sizeof(LIBSSH2_SFTP_ATTRIBUTES));
                        while ((rc = libssh2_sftp_stat(d->sftp_session, symBuf, &symStatBuf)) < 0) {
                            if (rc == LIBSSH2_ERROR_EAGAIN) {
                                waitsocket(d);
                            } else {
                                // error
                                return;
                            }
                        }
                        dirent.targetPath = [NSString stringWithUTF8String:symBuf];
                        dirent.targetPermissions = symStatBuf.permissions;
                    }

                    [directoryContents addObject:dirent];
                    memset(&buf, 0, CC_BUFSIZ);
                    memset(&stat, 0, sizeof(LIBSSH2_SFTP_ATTRIBUTES));
                } else if (readDirRC == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(d);
                } else {
                    break;
                }
            } while(true);
            libssh2_sftp_closedir(hnd);
        }

        self->currentDirectory = [newPath copy];
        
        userInfo = [NSMutableDictionary dictionary];
        [userInfo setObject:self->currentDirectory forKey:CCStatIdle_CurrentDirectory];

        [userInfo setObject:directoryContents forKey:CCStatIdle_DirectoryContents];
        [self postStatusChanged:kCCStatIdle withUserData:userInfo];
    });
}

- (void)copyFileFrom:(NSString *)src to:(NSString *)dest {
    NSLog(@"Copy from '%@' to '%@'", src, dest);

    id localMutex = lockToken;
    struct CCSFTPPrivate *d = priv;

    [self postStatusChanged:kCCStatBusy];
    dispatch_async(dqtTransfer, ^(void){
        LIBSSH2_SFTP_HANDLE *sftp_handle = NULL;
        @synchronized(localMutex) {
            do {
                sftp_handle = libssh2_sftp_open(d->sftp_session, [src UTF8String], LIBSSH2_FXF_READ, 0);

                if (!sftp_handle) {
                    if (libssh2_session_last_errno(d->session) == LIBSSH2_ERROR_EAGAIN) {
                        waitsocket(d);
                    } else {
                        // Error
                        NSLog(@"Error: %@", src);
                        [self postStatusChanged:kCCStatIdle];
                        return;
                    }
                }
                
            } while(!sftp_handle);
        }

        LIBSSH2_SFTP_ATTRIBUTES statbuf;
        memset(&statbuf, 0, sizeof(LIBSSH2_SFTP_ATTRIBUTES));
        int rc;
        @synchronized(localMutex) {
            while ((rc = libssh2_sftp_stat(d->sftp_session, [src UTF8String], &statbuf)) < 0) {
                if (rc == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(d);
                } else {
                    // error
                    return;
                }
            }
        }

        [self postStatusChanged:kCCStatTransferNew withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLongLong:statbuf.filesize]];
        
        int fd = open(dest.UTF8String, (O_RDWR | O_CREAT | O_TRUNC), (S_IRUSR | S_IWUSR));
        lseek(fd, 0, SEEK_SET);

        ssize_t lengthRead = 0;
        char *dataRead = malloc(CC_READBUFSIZ);
        memset(dataRead, 0, CC_READBUFSIZ);

        while (true) {
            @synchronized(localMutex) {
                while ((lengthRead = libssh2_sftp_read(sftp_handle, dataRead, CC_READBUFSIZ)) == LIBSSH2_ERROR_EAGAIN) {
                    waitsocket(d);
                };
            }
            if (lengthRead <= 0) {
                break;
            }

            write(fd, dataRead, lengthRead);
            [self postStatusChanged:kCCStatTransferUpdate withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLongLong:lengthRead]];
        }

        close(fd);
        free(dataRead);
        @synchronized(localMutex) {
            libssh2_sftp_close(sftp_handle);
        }
        [self postStatusChanged:kCCStatTransferDone withUserKey:CCStatTransfer_Size andValue:[NSNumber numberWithUnsignedLong:statbuf.filesize]];
        [self postStatusChanged:kCCStatIdle];
    });
}

- (NSString *)getCurrentDirectory {
    return currentDirectory;
}
@end
