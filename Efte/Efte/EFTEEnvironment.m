//
//  EFTEEnvironment.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-8-8.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEEnvironment.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "EFTEWebViewController.h"

static EFTEEnvironment *__env = nil;

#ifdef DEBUG
static BOOL __isDebug = YES;
#else
static BOOL __isDebug = NO;
#endif

void EFTEInternalSetDefaultEnvironment(EFTEEnvironment *env) {
    __env = env;
}

@implementation EFTEEnvironment {
    NSString *sessionId;
}
+ (EFTEEnvironment *)defaultEnvironment {
    if(__env) {
        return __env;
    } else {
        return [[EFTEEnvironment alloc] init];
    }
}

- (BOOL)isDebug {
    return __isDebug;
}

- (void)setDebug:(BOOL)isDebug {
    __isDebug = isDebug;
}

- (NSString *)platformString{
	size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

- (NSString *)sessionId {
    if(!sessionId) {
        CFUUIDRef uuidObj = CFUUIDCreate(nil);
        NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuidObj);
        CFRelease(uuidObj);
		sessionId = uuid;
    }
    return sessionId;
}

- (NSString *)deviceModel {
    NSString *modelName = [[UIDevice currentDevice] model];
    if([modelName hasPrefix:@"iPhone"])
        return @"iPhone";
    else if([modelName hasPrefix:@"iPod"])
        return @"iPod";
    else if([modelName hasPrefix:@"iPad"])
        return @"iPad";
    return @"iOS";
}

- (NSString *)envConfig {
    return @"";
}

- (NSString *)localPackageZipPath {
    return @"";
}

- (Class)navigationControllerClass {
    return [UINavigationController class];
}

- (Class)EFTEWebViewControllerClass {
    return [EFTEWebViewController class];
}

@end

