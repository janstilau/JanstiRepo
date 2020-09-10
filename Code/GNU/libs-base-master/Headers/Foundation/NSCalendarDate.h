#ifndef __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE
#define __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDate.h>

@class	NSTimeZone;
@class	NSTimeZoneDetail;

@interface NSCalendarDate : NSDate
{
#if	GS_EXPOSE(NSCalendarDate)
    NSTimeInterval	_seconds_since_ref;
    NSString		*_calendar_format;
    NSTimeZone		*_time_zone;
#endif
}

// Getting an NSCalendar Date
+ (id) calendarDate;
+ (id) dateWithString: (NSString*)description
       calendarFormat: (NSString*)format;
+ (id) dateWithString: (NSString*)description
       calendarFormat: (NSString*)format
               locale: (NSDictionary*)dictionary;
+ (id) dateWithYear: (NSInteger)year
              month: (NSUInteger)month
                day: (NSUInteger)day
               hour: (NSUInteger)hour
             minute: (NSUInteger)minute
             second: (NSUInteger)second
           timeZone: (NSTimeZone*)aTimeZone;

// Initializing an NSCalendar Date
- (id) initWithString: (NSString*)description;
- (id) initWithString: (NSString*)description
       calendarFormat: (NSString*)format;
- (id) initWithString: (NSString*)description
       calendarFormat: (NSString*)fmt
               locale: (NSDictionary*)locale;
- (id) initWithYear: (NSInteger)year
              month: (NSUInteger)month
                day: (NSUInteger)day
               hour: (NSUInteger)hour
             minute: (NSUInteger)minute
             second: (NSUInteger)second
           timeZone: (NSTimeZone*)aTimeZone;

// Retrieving Date Elements
- (NSInteger) dayOfCommonEra;
- (NSInteger) dayOfMonth;
- (NSInteger) dayOfWeek;
- (NSInteger) dayOfYear;
- (NSInteger) hourOfDay;
- (NSInteger) minuteOfHour;
- (NSInteger) monthOfYear;
- (NSInteger) secondOfMinute;
- (NSInteger) yearOfCommonEra;

/**
 * <p>Returns a calendar date formed by adding the specified offsets to the
 * receiver.  The offsets are added in order, years, then months, then
 * days, then hours then minutes then seconds, so if you add 1 month and
 * forty days to 20th September, the result will be 9th November.
 * </p>
 * <p>This method understands leap years and tries to adjust for daylight
 * savings time changes so that it preserves expected clock time.
 * </p>
 * <p>The returned date has the calendar format and timezone of the receiver.
 * </p>
 */
- (NSCalendarDate*) addYear: (NSInteger)year
                      month: (NSInteger)month
                        day: (NSInteger)day
                       hour: (NSInteger)hour
                     minute: (NSInteger)minute
                     second: (NSInteger)second;

// Getting String Descriptions of Dates
- (NSString*) description;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format;
- (NSString*) descriptionWithCalendarFormat: (NSString*)format
                                     locale: (NSDictionary*)locale;
- (NSString*) descriptionWithLocale: (id)locale;

// Getting and Setting Calendar Formats
- (NSString*) calendarFormat;
- (void) setCalendarFormat: (NSString*)format;

// Getting and Setting Time Zones
- (void) setTimeZone: (NSTimeZone*)aTimeZone;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (NSTimeZone*) timeZone;
#endif
#if OS_API_VERSION(GS_API_OPENSTEP, GS_API_MACOSX)
- (NSTimeZoneDetail*) timeZoneDetail;
#endif

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

@interface NSCalendarDate (GregorianDate)

- (NSInteger) lastDayOfGregorianMonth: (NSInteger)month year: (NSInteger)year;
- (NSInteger) absoluteGregorianDay: (NSInteger)day
                             month: (NSInteger)month
                              year: (NSInteger)year;
- (void) gregorianDateFromAbsolute: (NSInteger)d
                               day: (NSInteger*)day
                             month: (NSInteger*)month
                              year: (NSInteger*)year;

@end

#endif

#if OS_API_VERSION(GS_API_OPENSTEP, GS_API_MACOSX)
@interface NSCalendarDate (OPENSTEP)

- (NSCalendarDate*) dateByAddingYears: (NSInteger)years
                               months: (NSInteger)months
                                 days: (NSInteger)days
                                hours: (NSInteger)hours
                              minutes: (NSInteger)minutes
                              seconds: (NSInteger)seconds;

- (void) years: (NSInteger*)years
        months: (NSInteger*)months
          days: (NSInteger*)days
         hours: (NSInteger*)hours
       minutes: (NSInteger*)minutes
       seconds: (NSInteger*)seconds
     sinceDate: (NSDate*)date;
@end
#endif

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSCalendarDate+GNUstepBase.h>
#endif

#endif  /* __NSCalendarDate_h_GNUSTEP_BASE_INCLUDE*/
