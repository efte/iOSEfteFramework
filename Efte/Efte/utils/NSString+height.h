//
//  NSString+height.h
//  Dianping
//
//  Created by zhou cindy on 12-4-13.
//  Copyright (c) 2012年 dianping. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@interface NSString (height)

-(CGFloat) heightWithFont:(UIFont*) font lineBreakMode:(NSLineBreakMode) mode withWidth:(CGFloat)width;
-(CGSize) nvSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)mode;
-(CGSize) nvSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size;
-(CGSize) nvSizeWithFont:(UIFont *)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode;
-(CGSize) nvSizeWithFont:(UIFont *)font;
@end
