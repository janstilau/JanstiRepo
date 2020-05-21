#define	EXPOSE_NSDateFormatter_IVARS	1
#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSCalendar.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSFormatter.h"
#import "Foundation/NSDateFormatter.h"
#import "Foundation/NSCoder.h"

#if defined(HAVE_UNICODE_UDAT_H)
#define id id_ucal
#include <unicode/udat.h>
#undef id
#endif
#if defined(HAVE_UNICODE_UDATPG_H)
#include <unicode/udatpg.h>
#endif

// This is defined to be the same as UDAT_RELATIVE
#define FormatterDoesRelativeDateFormatting (1<<16)
#define BUFFER_SIZE 1024

@interface NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat;
- (void) _setSymbols: (NSArray *)array : (NSInteger)symbol;
- (NSArray *) _getSymbols: (NSInteger)symbol;
@end

static inline NSInteger
NSToUDateFormatStyle (NSDateFormatterStyle style)
{
#if GS_USE_ICU == 1
    NSInteger relative =
    (style & FormatterDoesRelativeDateFormatting) ? UDAT_RELATIVE : 0;
    switch (style)
    {
        case NSDateFormatterNoStyle:
            return (relative | UDAT_NONE);
        case NSDateFormatterShortStyle:
            return (relative | UDAT_SHORT);
        case NSDateFormatterMediumStyle:
            return (relative | UDAT_MEDIUM);
        case NSDateFormatterLongStyle:
            return (relative | UDAT_LONG);
        case NSDateFormatterFullStyle:
            return (relative | UDAT_FULL);
    }
#endif
    return -1;
}


#define	GSInternal		NSDateFormatterInternal
#include	"GSInternal.h"


@implementation NSDateFormatter

static NSDateFormatterBehavior _defaultBehavior = 0;

- (id) init
{
    self = [super init];
    if (self == nil)
        return nil;
    
    self->_behavior = _defaultBehavior;
    self->_locale = RETAIN([NSLocale currentLocale]);
    self->_timeZone = RETAIN([NSTimeZone defaultTimeZone]);
    
    [self _resetUDateFormat];
    
    return self;
}

- (BOOL) allowsNaturalLanguage
{
    return _allowsNaturalLanguage;
}

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
                                 withDefaultAttributes: (NSDictionary*)attr
{
    return nil;
}

- (NSString*) dateFormat
{
    return _dateFormat;
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
    return [self stringForObjectValue: anObject];
}

- (BOOL) getObjectValue: (id*)anObject
              forString: (NSString*)string
       errorDescription: (NSString**)error
{
    NSCalendarDate	*d;
    
    if ([string length] == 0)
    {
        d = nil;
    }
    else
    {
        d = [NSCalendarDate dateWithString: string calendarFormat: _dateFormat];
    }
    if (d == nil)
    {
        if (_allowsNaturalLanguage)
        {
            d = [NSCalendarDate dateWithNaturalLanguageString: string];
        }
        if (d == nil)
        {
            if (error)
            {
                *error = @"Couldn't convert to date";
            }
            return NO;
        }
    }
    if (anObject)
    {
        *anObject = d;
    }
    return YES;
}

- (id) initWithDateFormat: (NSString *)format
     allowNaturalLanguage: (BOOL)flag
{
    self = [self init];
    if (self == nil)
        return nil;
    
    [self setDateFormat: format];
    _allowsNaturalLanguage = flag;
    self->_behavior = NSDateFormatterBehavior10_0;
    return self;
}

- (BOOL) isPartialStringValid: (NSString*)partialString
             newEditingString: (NSString**)newString
             errorDescription: (NSString**)error
{
    if (newString)
    {
        *newString = nil;
    }
    if (error)
    {
        *error = nil;
    }
    return YES;
}

- (NSString*) stringForObjectValue: (id)anObject
{
    if ([anObject isKindOfClass: [NSDate class]] == NO)
    {
        return nil;
    }
    return [anObject descriptionWithCalendarFormat: _dateFormat
                                          timeZone: [NSTimeZone defaultTimeZone]
                                            locale: nil];
}



+ (NSDateFormatterBehavior) defaultFormatterBehavior
{
    return _defaultBehavior;
}

+ (void) setDefaultFormatterBehavior: (NSDateFormatterBehavior)behavior
{
    _defaultBehavior = behavior;
}

- (NSDateFormatterBehavior) formatterBehavior
{
    return self->_behavior;
}

- (void) setFormatterBehavior: (NSDateFormatterBehavior)behavior
{
    self->_behavior = behavior;
}

- (BOOL) generatesCalendarDates
{
    return NO; // FIXME
}

- (void) setGeneratesCalendarDates: (BOOL)flag
{
    return; // FIXME
}

- (NSDate *) dateFromString: (NSString *) string
{
#if GS_USE_ICU == 1
    NSDate *result = nil;
    UDate date;
    UChar *text;
    int32_t textLength;
    UErrorCode err = U_ZERO_ERROR;
    int32_t pPos = 0;
    
    textLength = [string length];
    text = malloc(sizeof(UChar) * textLength);
    if (text == NULL)
        return nil;
    
    [string getCharacters: text range: NSMakeRange (0, textLength)];
    
    date = udat_parse (self->_formatter, text, textLength, &pPos, &err);
    if (U_SUCCESS(err))
        result =
        [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)(date / 1000.0)];
    
    free(text);
    return result;
#else
    return nil;
#endif
}

- (NSString *) stringFromDate: (NSDate *) date
{
#if GS_USE_ICU == 1
    NSString *result;
    int32_t length;
    unichar *string;
    UDate udate = [date timeIntervalSince1970] * 1000.0;
    UErrorCode err = U_ZERO_ERROR;
    
    length = udat_format (self->_formatter, udate, NULL, 0, NULL, &err);
    string = malloc(sizeof(UChar) * (length + 1));
    err = U_ZERO_ERROR;
    udat_format (self->_formatter, udate, string, length, NULL, &err);
    if (U_SUCCESS(err))
    {
        result = AUTORELEASE([[NSString allocWithZone: NSDefaultMallocZone()]
                              initWithBytesNoCopy: string
                              length: length * sizeof(UChar)
                              encoding: NSUnicodeStringEncoding
                              freeWhenDone: YES]);
        return result;
    }
    
    free(string);
    return nil;
#else
    return nil;
#endif
}

- (BOOL) getObjectValue: (out id *) obj
              forString: (NSString *) string
                  range: (inout NSRange *) range
                  error: (out NSError **) error
{
    return NO; // FIXME
}

- (void) setDateFormat: (NSString *)string
{
    ASSIGNCOPY(_dateFormat, string);
    [self _resetUDateFormat];
}

- (NSDateFormatterStyle) dateStyle
{
    return self->_dateStyle;
}

- (void) setDateStyle: (NSDateFormatterStyle)style
{
    self->_dateStyle = style;
    [self _resetUDateFormat];
}

- (NSDateFormatterStyle) timeStyle
{
    return self->_timeStyle;
}

- (void) setTimeStyle: (NSDateFormatterStyle)style
{
    self->_timeStyle = style;
    [self _resetUDateFormat];
}

- (NSCalendar *) calendar
{
    return [self->_locale objectForKey: NSLocaleCalendar];
}

- (void) setCalendar: (NSCalendar *)calendar
{
    NSMutableDictionary *dict;
    NSLocale *locale;
    
    dict = [[NSLocale componentsFromLocaleIdentifier:
             [self->_locale localeIdentifier]] mutableCopy];
    [dict setValue: calendar forKey: NSLocaleCalendar];
    locale = [[NSLocale alloc] initWithLocaleIdentifier:
              [NSLocale localeIdentifierFromComponents: dict]];
    [self setLocale: locale];
    /* Don't have to use udat_setCalendar here because -setLocale: will take care
     of setting the calendar when it resets the formatter. */
    RELEASE(locale);
    RELEASE(dict);
}

- (NSDate *) defaultDate
{
    return nil;  // FIXME
}

- (void) setDefaultDate: (NSDate *)date
{
    return; // FIXME
}

- (NSLocale *) locale
{
    return self->_locale;
}

- (void) setLocale: (NSLocale *)locale
{
    if (locale == self->_locale)
        return;
    RELEASE(self->_locale);
    
    self->_locale = RETAIN(locale);
    [self _resetUDateFormat];
}

- (NSTimeZone *) timeZone
{
    return self->_timeZone;
}

- (void) setTimeZone: (NSTimeZone *)tz
{
    if (tz == self->_timeZone)
        return;
    RELEASE(self->_timeZone);
    
    self->_timeZone = RETAIN(tz);
    [self _resetUDateFormat];
}

- (NSDate *) twoDigitStartDate
{
#if GS_USE_ICU == 1
    UErrorCode err = U_ZERO_ERROR;
    return [NSDate dateWithTimeIntervalSince1970:
            (udat_get2DigitYearStart (self->_formatter, &err) / 1000.0)];
#else
    return nil;
#endif
}

- (void) setTwoDigitStartDate: (NSDate *)date
{
#if GS_USE_ICU == 1
    UErrorCode err = U_ZERO_ERROR;
    udat_set2DigitYearStart (self->_formatter,
                             ([date timeIntervalSince1970] * 1000.0),
                             &err);
#else
    return;
#endif
}


- (NSString *) AMSymbol
{
#if GS_USE_ICU == 1
    NSArray *array = [self _getSymbols: UDAT_AM_PMS];
    
    return [array objectAtIndex: 0];
#else
    return nil;
#endif
}

- (void) setAMSymbol: (NSString *) string
{
    return;
}

- (NSString *) PMSymbol
{
#if GS_USE_ICU == 1
    NSArray *array = [self _getSymbols: UDAT_AM_PMS];
    
    return [array objectAtIndex: 1];
#else
    return nil;
#endif
}

- (void) setPMSymbol: (NSString *)string
{
    return;
}

- (NSArray *) weekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_WEEKDAYS];
#else
    return;
#endif
}

- (NSArray *) shortWeekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_SHORT_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setShortWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_SHORT_WEEKDAYS];
#else
    return;
#endif
}

- (NSArray *) monthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_MONTHS];
#else
    return nil;
#endif
}

- (void) setMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_MONTHS];
#else
    return;
#endif
}

- (NSArray *) shortMonthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_SHORT_MONTHS];
#else
    return nil;
#endif
}

- (void) setShortMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_SHORT_MONTHS];
#else
    return;
#endif
}

- (NSArray *) eraSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_ERAS];
#else
    return nil;
#endif
}

- (void) setEraSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_ERAS];
#else
    return;
#endif
}

- (NSDate *) gregorianStartDate
{
    return nil;
}

- (void) setGregorianStartDate: (NSDate *)date
{
    return;
}

- (NSArray *) longEraSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_ERA_NAMES];
#else
    return nil;
#endif
}

- (void) setLongEraSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_ERA_NAMES];
#else
    return;
#endif
}


- (NSArray *) quarterSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_QUARTERS];
#else
    return nil;
#endif
}

- (void) setQuarterSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_QUARTERS];
#else
    return;
#endif
}

- (NSArray *) shortQuarterSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_SHORT_QUARTERS];
#else
    return nil;
#endif
}

- (void) setShortQuarterSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_SHORT_QUARTERS];
#else
    return;
#endif
}

- (NSArray *) standaloneQuarterSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_QUARTERS];
#else
    return nil;
#endif
}

- (void) setStandaloneQuarterSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_QUARTERS];
#else
    return;
#endif
}

- (NSArray *) shortStandaloneQuarterSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_SHORT_QUARTERS];
#else
    return nil;
#endif
}

- (void) setShortStandaloneQuarterSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_SHORT_QUARTERS];
#else
    return;
#endif
}

- (NSArray *) shortStandaloneMonthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_SHORT_MONTHS];
#else
    return nil;
#endif
}

- (void) setShortStandaloneMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_SHORT_MONTHS];
#else
    return;
#endif
}

- (NSArray *) standaloneMonthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_MONTHS];
#else
    return nil;
#endif
}

- (void) setStandaloneMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_MONTHS];
#else
    return;
#endif
}

- (NSArray *) veryShortMonthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_NARROW_MONTHS];
#else
    return nil;
#endif
}

- (void) setVeryShortMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_NARROW_MONTHS];
#else
    return;
#endif
}

- (NSArray *) veryShortStandaloneMonthSymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_NARROW_MONTHS];
#else
    return nil;
#endif
}

- (void) setVeryShortStandaloneMonthSymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_NARROW_MONTHS];
#else
    return;
#endif
}

- (NSArray *) shortStandaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_SHORT_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setShortStandaloneWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_SHORT_WEEKDAYS];
#else
    return;
#endif
}

- (NSArray *) standaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setStandaloneWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_WEEKDAYS];
#else
    return;
#endif
}

- (NSArray *) veryShortWeekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_SHORT_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setVeryShortWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_SHORT_WEEKDAYS];
#else
    return;
#endif
}

- (NSArray *) veryShortStandaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
    return [self _getSymbols: UDAT_STANDALONE_NARROW_WEEKDAYS];
#else
    return nil;
#endif
}

- (void) setVeryShortStandaloneWeekdaySymbols: (NSArray *)array
{
#if GS_USE_ICU == 1
    [self _setSymbols: array : UDAT_STANDALONE_NARROW_WEEKDAYS];
#else
    return;
#endif
}

+ (NSString *) localizedStringFromDate: (NSDate *) date
                             dateStyle: (NSDateFormatterStyle) dateStyle
                             timeStyle: (NSDateFormatterStyle) timeStyle
{
    NSString *result;
    NSDateFormatter *fmt = [[self alloc] init];
    
    [fmt setDateStyle: dateStyle];
    [fmt setTimeStyle: timeStyle];
    
    result = [fmt stringFromDate: date];
    RELEASE(fmt);
    
    return result;
}

+ (NSString *) dateFormatFromTemplate: (NSString *) aTemplate
                              options: (NSUInteger) opts
                               locale: (NSLocale *) locale
{
#if GS_USE_ICU == 1
    unichar pat[BUFFER_SIZE];
    unichar skel[BUFFER_SIZE];
    int32_t patLen;
    int32_t skelLen;
    UDateTimePatternGenerator *datpg;
    UErrorCode err = U_ZERO_ERROR;
    
    datpg = udatpg_open ([[locale localeIdentifier] UTF8String], &err);
    if (U_FAILURE(err))
        return nil;
    
    if ((patLen = [aTemplate length]) > BUFFER_SIZE)
        patLen = BUFFER_SIZE;
    [aTemplate getCharacters: pat range: NSMakeRange(0, patLen)];
    
    skelLen = udatpg_getSkeleton (datpg, pat, patLen, skel, BUFFER_SIZE, &err);
    if (U_FAILURE(err))
        return nil;
    
    patLen =
    udatpg_getBestPattern (datpg, skel, skelLen, pat, BUFFER_SIZE, &err);
    
    udatpg_close (datpg);
    return [NSString stringWithCharacters: pat length: patLen];
#else
    return nil;
#endif
}

- (BOOL) doesRelativeDateFormatting
{
    return (self->_dateStyle & FormatterDoesRelativeDateFormatting) ? YES : NO;
}

- (void) setDoesRelativeDateFormatting: (BOOL)flag
{
    self->_dateStyle |= FormatterDoesRelativeDateFormatting;
}
@end

@implementation NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat
{
#if GS_USE_ICU == 1
    UChar *pat = NULL;
    UChar *tzID;
    int32_t patLength = 0;
    int32_t tzIDLength;
    UDateFormatStyle timeStyle;
    UDateFormatStyle dateStyle;
    UErrorCode err = U_ZERO_ERROR;
    
    if (self->_formatter)
        udat_close (self->_formatter);
    
    tzIDLength = [[self->_tz name] length];
    tzID = malloc(sizeof(UChar) * tzIDLength);
    [[self->_tz name] getCharacters: tzID];
    
    if (self->_dateFormat)
    {
        patLength = [self->_dateFormat length];
        pat = malloc(sizeof(UChar) * patLength);
        [self->_dateFormat getCharacters: pat];
    }
    timeStyle = pat ? UDAT_PATTERN : NSToUDateFormatStyle (self->_timeStyle);
    dateStyle = pat ? UDAT_PATTERN : NSToUDateFormatStyle (self->_dateStyle);
    self->_formatter = udat_open (timeStyle, dateStyle,
                                  [[self->_locale localeIdentifier] UTF8String],
                                  tzID, tzIDLength, pat, patLength, &err);
    if (U_FAILURE(err))
        self->_formatter = NULL;
    if (pat)
        free(pat);
    free(tzID);
#else
    return;
#endif
}

#if GS_USE_ICU == 1
static inline void
symbolRange(NSInteger symbol, int *from)
{
    switch (symbol)
    {
        case UDAT_SHORT_WEEKDAYS:
        case UDAT_STANDALONE_NARROW_WEEKDAYS:
        case UDAT_STANDALONE_SHORT_WEEKDAYS:
        case UDAT_STANDALONE_WEEKDAYS:
        case UDAT_WEEKDAYS:
            /* In ICU days of the week number from 1 rather than zero.
             */
            *from = 1;
            break;
            
        default:
            *from = 0;
            break;
    }
}
#endif

- (void) _setSymbols: (NSArray*)array : (NSInteger)symbol
{
#if GS_USE_ICU == 1
    int idx;
    int count = udat_countSymbols (self->_formatter, symbol);
    
    symbolRange(symbol, &idx);
    if ([array count] == count - idx)
    {
        while (idx < count)
        {
            int           length;
            UChar         *value;
            UErrorCode    err = U_ZERO_ERROR;
            NSString      *string = [array objectAtIndex: idx];
            
            length = [string length];
            value = malloc(sizeof(unichar) * length);
            [string getCharacters: value range: NSMakeRange(0, length)];
            udat_setSymbols(self->_formatter, symbol, idx,
                            value, length, &err);
            free(value);
            ++idx;
        }
    }
#endif
    return;
}

- (NSArray *) _getSymbols: (NSInteger)symbol
{
#if GS_USE_ICU == 1
    NSMutableArray        *mArray;
    int                   idx;
    int                   count;
    
    count = udat_countSymbols(self->_formatter, symbol);
    symbolRange(symbol, &idx);
    mArray = [NSMutableArray arrayWithCapacity: count - idx];
    while (idx < count)
    {
        int               length;
        unichar           *value;
        NSString          *str;
        NSZone            *z = [self zone];
        UErrorCode        err = U_ERROR_LIMIT;
        
        length
        = udat_getSymbols(self->_formatter, symbol, idx, NULL, 0, &err);
        value = NSZoneMalloc(z, sizeof(unichar) * (length + 1));
        err = U_ZERO_ERROR;
        udat_getSymbols(self->_formatter, symbol, idx, value, length, &err);
        if (U_SUCCESS(err))
        {
            str = [[NSString allocWithZone: z]
                   initWithBytesNoCopy: value
                   length: length * sizeof(unichar)
                   encoding: NSUnicodeStringEncoding
                   freeWhenDone: YES];
            [mArray addObject: str];
            RELEASE(str);
        }
        else
        {
            NSZoneFree (z, value);
        }
        
        ++idx;
    }
    
    return [NSArray arrayWithArray: mArray];
#else
    return nil;
#endif
}
@end

