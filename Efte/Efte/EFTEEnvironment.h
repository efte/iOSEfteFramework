//
//  EFTEEnvironment.h
//  CRM-Mobile
//
//  Created by ZhouHui on 14-8-8.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EFTEEnvironment : NSObject

/**
 EFTEEnvironment以单例模式运行
 具体的App运行环境需要复写defaultEnvironment入口
 */
+ (EFTEEnvironment *)defaultEnvironment;

/**
 调试开关是否已打开
 */
- (BOOL)isDebug;
- (void)setDebug:(BOOL)isDebug;

/**
 硬件版本
 */
- (NSString *)platformString;

/**
 一次session代表一次进程
 置为后台不会导致sessionId改变
 */
- (NSString *)sessionId;

/**
 设备的型号
 iPhone, iPad, iPod, iOS (is unknown)
 */
- (NSString *)deviceModel;

- (NSString *)envConfig;
- (NSString *)localPackageZipPath;

- (Class)navigationControllerClass;

/**
 The class of EFTEWebViewController
 must confirm EFTEWebViewController protocal
 */
- (Class)EFTEWebViewControllerClass;

@end


/**
 业务层是否处于Debug模式
 */
#define ISDEBUG [[EFTEEnvironment defaultEnvironment] isDebug]

void EFTEInternalSetDefaultEnvironment(EFTEEnvironment *env);




