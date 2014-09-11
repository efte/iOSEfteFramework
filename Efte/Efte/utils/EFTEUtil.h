//
//  EFTEUtil.h
//  efet-iOS
//
//  Created by Maxwin on 14-5-29.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EFTEUtil : NSObject
+ (NSString *)json2string:(NSDictionary *)json;
+ (id)string2json:(NSString *)str;
@end
