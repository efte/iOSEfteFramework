//
//  NSData+Base64.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-7-8.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "NSData+Base64.h"
#import "EFTEVersionUtils.h"

@implementation NSData (Base64)

- (NSString *)base64EncodingString {
    if (EFTE_IPHONE_OS_7()) {
        return [self base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    } else {
        return [self base64Encoding];
    }
}

@end
