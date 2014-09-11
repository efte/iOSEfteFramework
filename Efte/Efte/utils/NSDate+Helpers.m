//
//  NSDate+Helpers.m
//  PMCalendarDemo
//
//  Created by Pavel Mazurin on 7/14/12.
//  Copyright (c) 2012 Pavel Mazurin. All rights reserved.
//

#import "NSDate+Helpers.h"

@implementation NSDate (Helpers)

- (NSDate *)dateWithoutTime
{
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:(NSYearCalendarUnit 
                                                          | NSMonthCalendarUnit 
                                                          | NSDayCalendarUnit ) 
                                                fromDate:self];
	
	return [calendar dateFromComponents:components];
}

- (NSDate *)dateForMonth
{
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:(NSYearCalendarUnit
                                                         | NSMonthCalendarUnit )
                                               fromDate:self];
	
	return [calendar dateFromComponents:components];
}

- (NSDate *) dateByAddingDays:(NSInteger) days months:(NSInteger) months years:(NSInteger) years
{
	NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
	dateComponents.day = days;
	dateComponents.month = months;
	dateComponents.year = years;
	
    return [[NSCalendar currentCalendar] dateByAddingComponents:dateComponents
                                                         toDate:self
                                                        options:0];    
}

- (NSDate *) dateByAddingDays:(NSInteger) days
{
    return [self dateByAddingDays:days months:0 years:0];
}

- (NSDate *) dateByAddingMonths:(NSInteger) months
{
    return [self dateByAddingDays:0 months:months years:0];
}

- (NSDate *) dateByAddingYears:(NSInteger) years
{
    return [self dateByAddingDays:0 months:0 years:years];
}

- (NSDate *) monthStartDate 
{
    NSDate *monthStartDate = nil;
	[[NSCalendar currentCalendar] rangeOfUnit:NSMonthCalendarUnit
                                    startDate:&monthStartDate 
                                     interval:NULL
                                      forDate:self];

	return monthStartDate;
}

- (NSUInteger) numberOfDaysInMonth
{
    return [[NSCalendar currentCalendar] rangeOfUnit:NSDayCalendarUnit 
                                              inUnit:NSMonthCalendarUnit 
                                             forDate:self].length;
}

- (NSUInteger) weekday
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSDateComponents *weekdayComponents = [gregorian components:NSWeekdayCalendarUnit fromDate:self];
    
    return [weekdayComponents weekday];
}

- (BOOL) isWeekend {
    NSUInteger weekday = [self weekday];
    return (weekday == 7 || weekday == 1);
}

- (NSString *) weekdayChinese {
    NSUInteger weekDay = [self weekday];
    switch (weekDay) {
        case 2:
            return @"一";
        case 3:
            return @"二";
        case 4:
            return @"三";
        case 5:
            return @"四";
        case 6:
            return @"五";
        case 7:
            return @"六";
        case 1:
            return @"日";
        default:
            break;
    }
    return @"";
}

- (NSUInteger) day
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSDateComponents *weekdayComponents = [gregorian components:NSDayCalendarUnit fromDate:self];
    
    return [weekdayComponents day];
}

- (NSString *) dateStringWithFormat:(NSString *) format
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
		
	return [formatter stringFromDate:self];
}

- (NSString *)dateTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
	return [formatter stringFromDate:self];
}

- (BOOL)isSameDay:(NSDate *)aDate {
    if (!aDate) {
        return NO;
    }
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *theDateComponents = [gregorian components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:self];
    NSDateComponents *compareComponents = [gregorian components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:aDate];
	if (theDateComponents.year!=compareComponents.year || theDateComponents.month!=compareComponents.month || theDateComponents.day!=compareComponents.day) {
		return NO;
	} else {
		return YES;
	}
}

+ (id)dateWithString:(NSString *)timeString {
	return [self dateWithString:timeString format:@"yyyy-MM-dd HH:mm:ss"];
}

+ (id)dateWithString:(NSString *)timeString format:(NSString *)dateFormat {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[dateFormatter setLocale:locale];
	[dateFormatter setDateFormat:dateFormat];
	
	return [dateFormatter dateFromString:timeString];
}

+ (NSString *)nowDateTimeString {
    NSDate *now = [NSDate date];
    return [now dateStringWithFormat:@"yyyy-MM-dd H:mm:ss"];
}

@end
