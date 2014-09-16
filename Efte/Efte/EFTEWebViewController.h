//
//  EFTEWebViewController.h
//  efet-iOS
//
//  Created by Maxwin on 14-5-28.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EFTEDefines.h"
#import "UIViewController+EFTENavigator.h"


@protocol EFTEWebViewController <NSObject>

@property (strong, nonatomic) UIView *networkInfoView;
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) NSString *unit;
@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *url;

@end



@interface EFTEWebViewController : UIViewController <UIWebViewDelegate, EFTEWebViewController>
{
    NSMutableDictionary *_data;
}

@property (readonly, nonatomic) BOOL efteJSLoaded;

- (void)jsCallbackForId:(NSString *) callbackId withRetValue:(id) ret;
- (void)loadPage;

- (BOOL)jsHasObject:(NSString *)jsObjectString;
- (BOOL)jsHasFunction:(NSString *)jsFunctionString;

// set a flag, when viewWillAppear trigered, the function loadPage will be called
- (void)needReload;

- (void)backAction;

@end
