#ifndef __NSScanner_h_GNUSTEP_BASE_INCLUDE
#define __NSScanner_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDecimal.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSCharacterSet.h>

/*
 * NSScanner class
 */
@interface NSScanner : NSObject <NSCopying>
{
@public
    NSString		*_string;
    NSCharacterSet	*_charactersToBeSkipped;
    BOOL			(*_skipImp)(NSCharacterSet*, SEL, unichar);
    NSDictionary		*_locale;
    NSUInteger		_scanLocation;
    unichar		_decimal;
    BOOL			_caseSensitive;
    BOOL			_isUnicode;
}

/*
 * Creating an NSScanner
 */
+ (id) localizedScannerWithString: (NSString*)aString;
+ (id) scannerWithString: (NSString*)aString;
- (id) initWithString: (NSString*)aString;

/*
 * Getting an NSScanner's string
 */
- (NSString*) string;

/*
 * Configuring an NSScanner
 */
- (NSUInteger) scanLocation;
- (void) setScanLocation: (NSUInteger)anIndex;

- (BOOL) caseSensitive;
- (void) setCaseSensitive: (BOOL)flag;

- (NSCharacterSet*) charactersToBeSkipped;
- (void) setCharactersToBeSkipped: (NSCharacterSet *)aSet;

- (NSDictionary*)locale;
- (void)setLocale:(NSDictionary*)localeDictionary;

/*
 * Scanning a string
 */
- (BOOL) scanInt: (int*)value;
- (BOOL) scanHexInt: (unsigned int*)value;
- (BOOL) scanLongLong: (long long*)value;
- (BOOL) scanFloat: (float*)value;
- (BOOL) scanDouble: (double*)value;
- (BOOL) scanString: (NSString*)string intoString: (NSString**)value;
- (BOOL) scanCharactersFromSet: (NSCharacterSet*)aSet
                    intoString: (NSString**)value;
- (BOOL) scanUpToString: (NSString*)string intoString: (NSString**)value;
- (BOOL) scanUpToCharactersFromSet: (NSCharacterSet*)aSet 
                        intoString: (NSString**)value;
- (BOOL) isAtEnd;

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
- (BOOL) scanRadixUnsignedInt: (unsigned int*)value;
- (BOOL) scanRadixUnsignedLongLong: (unsigned long long*)value;
#endif
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) scanDecimal: (NSDecimal*)value;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
- (BOOL) scanHexLongLong: (unsigned long long*)value;
/** Not implemented */
- (BOOL) scanHexDouble: (double *)result;
/** Not implemented */
- (BOOL) scanHexFloat: (float *)result;
/** Not implemented */
- (BOOL) scanInteger: (NSInteger *)value;
#endif
@end

#endif /* __NSScanner_h_GNUSTEP_BASE_INCLUDE */
