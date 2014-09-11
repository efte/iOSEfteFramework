//
//  NSString+height.m
//  Dianping
//
//  Created by zhou cindy on 12-4-13.
//  Copyright (c) 2012年 dianping. All rights reserved.
//

#import "NSString+height.h"

@implementation NSString (height)

-(CGFloat) heightWithFont:(UIFont*)font lineBreakMode:(NSLineBreakMode) mode withWidth:(CGFloat)width {
	if(self == nil || [self length] == 0)
		return 0;
	
	CGSize constraint = CGSizeMake(width, 9999.0f);
	CGSize theSize = [self nvSizeWithFont:font constrainedToSize:constraint lineBreakMode:mode];
	return theSize.height;
}

-(CGSize) nvSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)mode
{
    if (!self || self.length == 0) {
        return CGSizeZero;
    }
    if ([self respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        NSDictionary * attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
        //IOS7 测量字符串问题，需向下取整
        CGSize sbSize = [self boundingRectWithSize:size options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil].size;
        sbSize.height = ceilf(sbSize.height);
        sbSize.width = ceilf(sbSize.width);
        return sbSize;
    } else {
        return [self sizeWithFont:font constrainedToSize:size lineBreakMode:mode];
    }
}

-(CGSize) nvSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size
{
    return [self nvSizeWithFont:font constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
}

-(CGSize) nvSizeWithFont:(UIFont *)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode
{
    return [self nvSizeWithFont:font constrainedToSize:CGSizeMake(width, MAXFLOAT) lineBreakMode:lineBreakMode];
}

-(CGSize) nvSizeWithFont:(UIFont *)font
{
    return [self nvSizeWithFont:font constrainedToSize:CGSizeMake(MAXFLOAT, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping];
}

@end
