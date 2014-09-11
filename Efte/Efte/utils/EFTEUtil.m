//
//  EFTEUtil.m
//  efet-iOS
//
//  Created by Maxwin on 14-5-29.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEUtil.h"
#import "EFTEDefines.h"

@implementation EFTEUtil

+ (NSString *)json2string:(NSDictionary *)json
{
    @try {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (error) {
            return nil;
        }
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    @catch (NSException *exception) {
        return nil;
    }
}

+ (id)string2json:(NSString *)str
{
    if (str == nil) {
        return nil;
    }
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error) {
        EFTELOG(@"%s [%@]", __PRETTY_FUNCTION__, error);
        return nil;
    }
    return json;
}

@end
