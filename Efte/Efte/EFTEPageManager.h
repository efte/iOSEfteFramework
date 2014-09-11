//
//  EFTEPageManager.h
//  efet-iOS
//
//  Created by Maxwin on 14-5-29.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EFTEPageManager : NSObject

+ (instancetype)sharedInstance;

- (NSURL *)url4unit:(NSString *)unit path:(NSString *)path;

@end
