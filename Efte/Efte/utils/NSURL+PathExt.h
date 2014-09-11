//
//  NSURL+PathExt.h
//  Nova
//
//  Created by Yi Lin on 8/10/12.
//  Copyright (c) 2012 dianping.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (PathExt)

+(NSURL*) systemCacheURL;

+(NSURL*) systemTmpURL;

- (NSDictionary *)paramDic;

- (NSDictionary *)queryParams;

@end
