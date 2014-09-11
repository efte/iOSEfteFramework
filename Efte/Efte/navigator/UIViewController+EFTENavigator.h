//
//  EFTEWebViewController+EFTENavigator.h
//  efet-iOS
//
//  Created by Maxwin on 14-5-31.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (EFTENavigator)
@property (strong, nonatomic) NSDictionary *efteQuery;

- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path;
- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path withQuery:(NSDictionary *)query;
- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path withQuery:(NSDictionary *)query modal:(BOOL)modal animated:(BOOL)animated;
- (void)efteOpenUrl:(NSString *)url withQuery:(NSDictionary *)query animated:(BOOL)animated modal:(BOOL)modal;

- (void)openUrl:(NSString *)urlString;
@end
