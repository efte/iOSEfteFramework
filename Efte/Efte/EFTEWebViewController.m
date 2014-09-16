//
//  EFTEWebViewController.m
//  efet-iOS
//
//  Created by Maxwin on 14-5-28.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "UIViewController+EFTENavigator.h"
#import "EFTEWebViewController.h"
#import "NSURL+PathExt.h"
#import "EFTEPageManager.h"
#import <objc/runtime.h>
#import "EFTEVersionUtils.h"
#import "EFTEWebView.h"
#import "EFTEDefines.h"

#define EFTE_DEFAULT_USER_AGENT @"Efte/1.0 (efte-for-ios)"

#define JSOnAppear      @"(function(){window.Efte.onAppear();})()"
#define JSOnDisappear   @"(function(){window.Efte.onDisappear();})()"
#define JSOnSaveData    @"(function(){window.Efte.onSaveData();})()"
#define JSOnRestoreData @"(function(){window.Efte.onRestoreData();})()"


@interface EFTEWebViewController ()

@end

@implementation EFTEWebViewController {
    BOOL _viewHadUnload;
    BOOL _needReload;
}

@synthesize networkInfoView = _networkInfoView;
@synthesize webView = _webView;
@synthesize unit = _unit;
@synthesize path = _path;
@synthesize url = _url;

+ (void)initialize {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[self userAgent], @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
}

+ (NSString *)userAgent {
    static NSString *gUserAgent = nil;
    if (gUserAgent == nil) {
        UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        NSString* secretAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        gUserAgent = [secretAgent stringByAppendingFormat:@" %@",EFTE_DEFAULT_USER_AGENT];
        EFTELOG(@"useragent = %@", gUserAgent);
    }
    return gUserAgent;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _data = [NSMutableDictionary new];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    EFTEWebView *webView = [[EFTEWebView alloc] initWithFrame:self.view.bounds];
    webView.controller = self;
    self.webView = webView;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor whiteColor];
    self.webView.opaque = NO;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    for (UIView *view in [[self.webView subviews].firstObject subviews]) {
        if ([view isKindOfClass:[UIImageView class]]) view.hidden = YES;
    }
    
    [self.view addSubview:self.webView];
    
    self.webView.delegate = self;
    
    // load page
    if ((self.unit && self.path) || self.url) {
        [self loadPage];
    }
}

- (void)needReload {
    _needReload = YES;
}

- (BOOL)hidesBottomBarWhenPushed {
    if (self.navigationController.viewControllers.count>1) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)efteJSLoaded {
    return [self jsHasObject:@"window.Efte"];
}

- (BOOL)jsHasObject:(NSString *)jsObjectString {
    return [self jsHasType:jsObjectString type:@"object"];
}

- (BOOL)jsHasFunction:(NSString *)jsFunctionString {
    return [self jsHasType:jsFunctionString type:@"function"];
}

- (BOOL)jsHasType:(NSString *)jsTypeString type:(NSString *)typeString {
    NSString *jsString = [NSString stringWithFormat:@"typeof %@", jsTypeString];
    NSString *efteResult = [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    if ([efteResult caseInsensitiveCompare:typeString] == NSOrderedSame) {
        return YES;
    }
    return NO;
}

- (void)backAction {
    if ([self efteJSLoaded]) {
        NSString *js = @"window.Efte.action.back();";
        [self.webView performSelector:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js afterDelay:0];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)setPath:(NSString *)path
{
    _path = path;
    if (self.isViewLoaded) {
        [self loadPage];
    }
}

- (void)loadPage
{
    NSURL *url = nil;
    if (_url) {
        url = [NSURL URLWithString:_url];
    } else {
        url = [[EFTEPageManager sharedInstance] url4unit:self.unit path:self.path];
    }
    
    [self.webView stopLoading];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
    [self.webView loadRequest:request];
}

#pragma mark - js bridge
- (NSString *)jsScheme
{
    return @"js://";
}

- (NSString *)urlScheme
{
    return @"efte://";
}

- (BOOL)webView:(UIWebView *)web shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    //recordOperation([NSString stringWithFormat:@"[JS2Native] %@", request.URL]);
    if ([request.URL.absoluteString hasPrefix:[self jsScheme]]) {
        [self handleMessage:[request.URL queryParams]];
        return NO;
    }
    
    if ([request.URL.absoluteString hasPrefix:[self urlScheme]]) {
        NSDictionary *query = request.URL.queryParams;
        NSString *unit = request.URL.host;
        NSString *path = request.URL.path;
        [self efteOpenUnit:unit path:path withQuery:query];
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (_viewHadUnload) {
        [self webViewRestore];
        _viewHadUnload = NO;
    }
}

- (void)handleMessage:(NSDictionary *)param
{
    SEL selector = [self selectorForMethod:param[@"method"]];
    if (selector == nil) return;
    if (![self respondsToSelector:selector]) {
        EFTELOG(@"cannot handle[%@]", param);
        return ;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector withObject:[self string2json:param[@"args"]]];
#pragma clang diagnostic pop
    
}

- (SEL)selectorForMethod:(NSString *) method {
    if ([method length] == 0) return nil;
    NSString *objcMethod = [[@"jsapi_" stringByAppendingString:method] stringByAppendingString:@":"];
    return NSSelectorFromString(objcMethod);
}

- (NSDictionary *)string2json:(NSString *)str
{
    if (str == nil) return nil;
    
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error != nil) { // parse json error
        EFTELOG(@"parse json error: %@", error);
    }
    return json;
}

- (NSString *) stringFromDictionary:(NSDictionary *) dictionary {
    if (![NSJSONSerialization isValidJSONObject:dictionary]) return @"";
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


- (void) jsCallbackForId:(NSString *) callbackId withRetValue:(id) ret {
    NSString *retString = nil;
    if ([NSJSONSerialization isValidJSONObject:ret]) {
        retString = [self stringFromDictionary:ret];
    } else {
        retString = [NSString stringWithFormat:@"\'%@\'", ret];
    }
    NSString *js = [NSString stringWithFormat:@"window.Efte && window.Efte.callback && window.Efte.callback(%@,%@);", callbackId, retString];
    [self.webView performSelector:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js afterDelay:0];
}

- (NSString *)apiMethodPrefix {
    return @"jsapi_";
}

- (NSString *)apiNameFromMethodName:(NSString *) name {
    NSString *nameWithoutPrefix = [name substringFromIndex:[[self apiMethodPrefix] length]];
    NSString *apiName = [nameWithoutPrefix substringToIndex:[nameWithoutPrefix length] -1];
    return apiName;
}

- (NSArray *) jsapiMethodsListForClass:(Class)cls {
    NSUInteger count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    
    for (NSInteger i = 0; i < count; i++) {
        NSString *methodName = @(sel_getName(method_getName(methods[i])));
        if ([methodName hasPrefix:[self apiMethodPrefix]]) {
            [array addObject:[self apiNameFromMethodName:methodName]];
        }
    }
    free(methods);
    return array;
}

- (NSArray *)jsapiMethodList {
    Class cls = self.class;
    NSMutableArray *methods = [NSMutableArray array];
    while (cls && [NSStringFromClass(cls) hasPrefix:@"NV"]) {
        [methods addObjectsFromArray:[self jsapiMethodsListForClass:cls]];
        cls = cls.superclass;
    }
    return methods;
}

- (BOOL)shouldInjectJs{
    return NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_needReload) {
        if ((self.unit && self.path) || self.url) {
            [self loadPage];
        }
        _needReload = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([self jsHasFunction:@"window.Efte.onAppear"]) {
        [self.webView stringByEvaluatingJavaScriptFromString:JSOnAppear];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([self jsHasFunction:@"window.Efte.onDisappear"]) {
        [self.webView stringByEvaluatingJavaScriptFromString:JSOnDisappear];
    }
}

- (void)viewWillUnload {
    [super viewWillUnload];
    
    if ([self jsHasFunction:@"window.Efte.onSaveData"]) {
        [self.webView stringByEvaluatingJavaScriptFromString:JSOnSaveData];
    }
    _viewHadUnload = YES;
}

- (void)webViewRestore {
    if ([self jsHasFunction:@"window.Efte.onRestoreData"]) {
        [self.webView stringByEvaluatingJavaScriptFromString:JSOnRestoreData];
    }
}

- (void)dealloc {
    EFTELOG(@"%@ dealloced!!!!!!!!!!!!!!!!!", NSStringFromClass([self class]));
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
