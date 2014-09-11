//
//  EFTELog.h
//  Core
//
//  Created by ZhouHui on 12-6-30.
//  Copyright (c) 2012年 dianping.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EFTEEnvironment.h"

#define EFTELOG(format, ...) if([[EFTEEnvironment defaultEnvironment] isDebug]) {__EFTELog(@__FILE__, __LINE__, [NSString stringWithFormat:format, ## __VA_ARGS__]);}


void __EFTELog(NSString *file, NSInteger line, NSString * content);

