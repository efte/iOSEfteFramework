//
//  UIViewController+EFTENavigator.m
//  efet-iOS
//
//  Created by Maxwin on 14-5-31.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEPageManager.h"
#import "EFTEWebViewController.h"
#import "UIViewController+EFTENavigator.h"
#import <objc/runtime.h>
#import "NSURL+PathExt.h"
#import "EFTEEnvironment.h"
#import "EFTEDefines.h"

static const char *efteQueryTag = "efteQueryTag";

@implementation UIViewController (EFTENavigator)

@dynamic efteQuery;

- (void)setEfteQuery:(NSDictionary *)efteQuery
{
    objc_setAssociatedObject(self, efteQueryTag, efteQuery, OBJC_ASSOCIATION_RETAIN);
}

- (NSDictionary *)efteQuery
{
    return objc_getAssociatedObject(self, efteQueryTag);
}

- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path;
{
    [self efteOpenUnit:unit path:path withQuery:nil modal:NO animated:YES];
}

- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path withQuery:(NSDictionary *)query
{
    [self efteOpenUnit:unit path:path withQuery:query modal:NO animated:YES];
}

- (void)efteOpenUnit:(NSString *)unit path:(NSString *)path withQuery:(NSDictionary *)query modal:(BOOL)modal animated:(BOOL)animated
{
    UIViewController *vc = [self viewControllerForUnit:unit path:path];
    if (!vc) {
        return ;
    }
    vc.efteQuery = query;
    if (modal) {
        UINavigationController *nvc = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:nvc animated:animated completion:nil];
        vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(viewDismiss)];
    } else {
        self.hidesBottomBarWhenPushed = NO;
        [self.navigationController pushViewController:vc animated:animated];
        self.hidesBottomBarWhenPushed = YES;
    }
}

- (void)viewDismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openUrl:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        EFTELOG(@"open url error: [%@] is not a valid url", urlString);
        return;
    }
    if ([urlString hasPrefix:@"efte://"]) {
        NSDictionary *query = url.queryParams;
        NSString *unit = url.host;
        NSString *path = url.path;
        [self efteOpenUnit:unit path:path withQuery:query];
    } else {
        NSDictionary *query = url.queryParams;
        [self efteOpenUrl:urlString withQuery:query animated:YES modal:NO];
    }
}

- (void)efteOpenUrl:(NSString *)url withQuery:(NSDictionary *)query animated:(BOOL)animated modal:(BOOL)modal
{
    EFTEWebViewController *vc = [EFTEWebViewController new];
    vc.url = url;
    vc.efteQuery = query;
    if (modal) {
        UINavigationController *nvc = [[[[EFTEEnvironment defaultEnvironment] navigationControllerClass] alloc] initWithRootViewController:vc];
        [self presentViewController:nvc animated:animated completion:nil];
        vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(viewDismiss)];
    } else {
        self.hidesBottomBarWhenPushed = NO;
        [self.navigationController pushViewController:vc animated:animated];
        self.hidesBottomBarWhenPushed = YES;
    }
}

- (UIViewController *)viewControllerForUnit:(NSString *)unit path:(NSString *)path
{
    // efte webviewcontroller
    EFTEWebViewController *vc = [EFTEWebViewController new];
    vc.unit = unit;
    vc.path = path;
    return vc;
}

@end
