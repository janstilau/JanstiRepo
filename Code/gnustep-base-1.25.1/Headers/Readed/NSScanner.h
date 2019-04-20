
#ifndef __NSScanner_h_GNUSTEP_BASE_INCLUDE
#define __NSScanner_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDecimal.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSCharacterSet.h>

#if	defined(__cplusplus)
extern "C" {
#endif
    
/*
 A string parser that scans for substrings or characters in a character set, and for numeric values from decimal, hexadecimal, and floating-point representations.
 */

@interface NSScanner : NSObject <NSCopying>
{
#if	GS_EXPOSE(NSScanner)
@private
    NSString		*_string;
    NSCharacterSet	*_charactersToBeSkipped;
    BOOL			(*_skipImp)(NSCharacterSet*, SEL, unichar); // 这样写是为了提高效率????
    NSDictionary		*_locale;
    NSUInteger		_scanLocation;
    unichar		_decimal;
    BOOL			_caseSensitive;
    BOOL			_isUnicode;
#endif
#if     GS_NONFRAGILE
#else
    /* Pointer to private additional data used to avoid breaking ABI
     * when we don't have the non-fragile ABI available.
     * Use this mechanism rather than changing the instance variable
     * layout (see Source/GSInternal.h for details).
     */
@private id _internal GS_UNUSED_IVAR;
#endif
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
    
#if	defined(__cplusplus)
}
#endif

#endif /* __NSScanner_h_GNUSTEP_BASE_INCLUDE */
