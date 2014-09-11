//
//  NSString+Utils.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-7-6.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "NSString+Utils.h"

@implementation NSString (Utils)

+ (instancetype)creatUUIDString {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return uuid;
}

@end
