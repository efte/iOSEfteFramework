//
//  NSURL+PathExt.m
//  Nova
//
//  Created by Yi Lin on 8/10/12.
//  Copyright (c) 2012 dianping.com. All rights reserved.
//

#import "NSURL+PathExt.h"

@implementation NSURL (PathExt)

////////////////////////////////////////////////////////////////////////////////
//
//	Returns the URL to the application's Documents folder
//
+(NSURL*) systemCacheURL
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
    
	NSArray *documentFolders = [defaultManager URLsForDirectory:NSCachesDirectory
													  inDomains:NSUserDomainMask];
	NSURL *outURL = [documentFolders lastObject];
    return outURL;
}

////////////////////////////////////////////////////////////////////////////////
//
//	Returns the URL to the application's Documents folder
//
+(NSURL*) systemTmpURL
{
    NSString *tmpPath = NSTemporaryDirectory();
    NSURL *outURL = nil;
    if(tmpPath)
        outURL = [NSURL URLWithString:tmpPath];
    return outURL;
}

- (NSDictionary *)paramDic {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    NSArray *pairs = [[self query] componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
		
		if ([elements count] <= 1) {
			return nil;
		}
		
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

-(NSDictionary *)queryParams
{
    if(!self.query) {
        return  nil;
    }
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    NSArray *keyValuePairs = [self.query componentsSeparatedByString:@"&"];
    for(id kv in keyValuePairs) {
        NSRange r = [kv rangeOfString:@"="];
        if (r.length == 0) continue;
        
        NSString *key = [kv substringToIndex:r.location];
        NSString *value = [kv substringFromIndex:r.location + r.length];
        CFStringRef origStr =
        CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                (CFStringRef)(value),
                                                                CFSTR(""),
                                                                kCFStringEncodingUTF8);
        [ret setValue:(__bridge NSString*)(origStr) forKey:key];
        CFRelease(origStr);
    }
    
    return ret;
}

@end
