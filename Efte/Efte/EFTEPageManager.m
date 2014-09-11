//
//  EFTEPageManager.m
//  efet-iOS
//
//  Created by Maxwin on 14-5-29.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEPageManager.h"
#import "EFTEUtil.h"
#import "EFTEPackageController.h"

@interface EFTEPageManager ()
@end

@implementation EFTEPageManager

+ (instancetype)sharedInstance
{
    static EFTEPageManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self class] new];
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (NSURL *)url4unit:(NSString *)unit path:(NSString *)path
{
//    NSString *prefix = [EFTEDebugTableViewController prefixPath];
    NSString *clearPath = path;
    if ([clearPath hasPrefix:@"/"]) {
        clearPath = [path substringFromIndex:1];
    }
    if ([clearPath hasSuffix:@".html"]) {
        clearPath = [clearPath substringToIndex:(clearPath.length-@".html".length)];
    }
//    if (prefix && ![prefix isEqualToString:@"*"]) {
//        NSString *url = [NSString stringWithFormat:@"%@/%@/latest/%@.html", prefix, unit, clearPath];
//        return [NSURL URLWithString:url];
//    }
    NSString *pkgPath = [[EFTEPackageController sharedInstance] pathForPkg:unit];
    NSString *url = [NSString stringWithFormat:@"%@/%@.html", pkgPath, clearPath];
    return [NSURL fileURLWithPath:url];
}

@end
