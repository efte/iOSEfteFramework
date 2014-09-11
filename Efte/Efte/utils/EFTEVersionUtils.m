//
//  EFTEVersionUtils.m
//  CRM-Mobile
//
//  Created by ZhouHui on 14-6-21.
//  Copyright (c) 2014年 大众点评. All rights reserved.
//

#import "EFTEVersionUtils.h"

double EFTE_IPHONE_OS_MAIN_VERSION() {
	static double __efte_iphone_os_main_version = 0.0;
	if(__efte_iphone_os_main_version == 0.0) {
		NSString *sv = [[UIDevice currentDevice] systemVersion];
		NSScanner *sc = [[NSScanner alloc] initWithString:sv];
		if(![sc scanDouble:&__efte_iphone_os_main_version])
			__efte_iphone_os_main_version = -1.0;
	}
	return __efte_iphone_os_main_version;
}

BOOL EFTE_IPHONE_OS_7() {
	return EFTE_IPHONE_OS_MAIN_VERSION() >= 7.0;
}
