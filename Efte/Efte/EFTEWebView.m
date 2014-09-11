//
//  EFTEWebView.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-7-6.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEWebView.h"
#import "EFTEDefines.h"

@implementation EFTEWebView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script {
    if (self.controller) {
        //recordOperation([NSString stringWithFormat:@"[Native2JS] %@", script]);
        return [super stringByEvaluatingJavaScriptFromString:script];
    } else {
        EFTELOG(@"check webview controller is dealloced!!!");
        return nil;
    }
}

@end
