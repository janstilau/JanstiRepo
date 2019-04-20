#ifndef __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE
#define __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSRange.h>
#import	<Foundation/NSString.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/*
 An NSCharacterSet object represents a set of Unicode-compliant characters.
 NSString and NSScanner objects use NSCharacterSet objects to group characters together for searching operations, so that they can find any of a particular set of characters during a search.
 The cluster’s two public classes, NSCharacterSet and NSMutableCharacterSet, declare the programmatic interface for static and dynamic character sets, respectively.
 
 The objects you create using these classes are referred to as character set objects (and when no confusion will result, merely as character sets).
 Because of the nature of class clusters, character set objects aren’t actual instances of the NSCharacterSet or NSMutableCharacterSet classes but of one of their private subclasses.
 Although a character set object’s class is private, its interface is public, as declared by these abstract superclasses, NSCharacterSet and NSMutableCharacterSet.
 The character set classes adopt the NSCopying and NSMutableCopying protocols, making it convenient to convert a character set of one type to the other.
 
 The NSCharacterSet class declares the programmatic interface for an object that manages a set of Unicode characters (see the NSString class cluster specification for information on Unicode).
 characterIsMember the primitiveMethod
 NSCharacterSet’s principal primitive method, characterIsMember:, provides the basis for all other instance methods in its interface.
 A subclass of NSCharacterSet needs only to implement this method, plus mutableCopyWithZone:, for proper behavior. F
 or optimal performance, a subclass should also override bitmapRepresentation, which otherwise works by invoking characterIsMember: for every possible Unicode value.
 
 NSCharacterSet is “toll-free bridged” with its Core Foundation counterpart, CFCharacterSetRef. See Toll-Free Bridging for more information on toll-free bridging.
 */
    
@class NSData;
    
/**
 *  Represents a set of unicode characters.  Used by [NSScanner] and [NSString]
 *  for parsing-related methods.
 这是一个数据类.
 */
@interface NSCharacterSet : NSObject <NSCoding, NSCopying, NSMutableCopying>

/**
 *  Returns a character set containing letters, numbers, and diacritical
 *  marks.  Note that "letters" includes all alphabetic as well as Chinese
 *  characters, etc..
 */
+ (id) alphanumericCharacterSet;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/**
 *  Returns a character set containing letters in the unicode
 *  Titlecase category.
 */
+ (id) capitalizedLetterCharacterSet;
#endif

/**
 * Returns a character set containing control and format characters.
 */
+ (id) controlCharacterSet;

/**
 * Returns a character set containing characters that represent
 * the decimal digits 0 through 9.
 */
+ (id) decimalDigitCharacterSet;

/**
 * Returns a character set containing individual characters that
 * can be represented also by a composed character sequence.
 */
+ (id) decomposableCharacterSet;

/**
 * Returns a character set containing unassigned and explicitly illegal
 * character values.
 */
+ (id) illegalCharacterSet;

/**
 *  Returns a character set containing letters, including all alphabetic as
 *  well as Chinese characters, etc..
 */
+ (id) letterCharacterSet;

/**
 * Returns a character set that contains the lowercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in uppercase and/or titlecase.
 */
+ (id) lowercaseLetterCharacterSet;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/**
 * Returns a character set containing the newline characters, values
 * 0x000A and 0x000D and nextline 0x0085 character.
 */
+ (id) newlineCharacterSet;
#endif

/**
 *  Returns a character set containing characters for diacritical marks, which
 *  are usually only rendered in conjunction with another character.
 */
+ (id) nonBaseCharacterSet;

/**
 *  Returns a character set containing punctuation marks.
 */
+ (id) punctuationCharacterSet;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/**
 *  Returns a character set containing mathematical symbols, etc..
 */
+ (id) symbolCharacterSet;
#endif

/**
 * Returns a character set that contains the uppercase characters.
 * This set does not include caseless characters, only those that
 * have corresponding characters in lowercase and/or titlecase.
 */
+ (id) uppercaseLetterCharacterSet;

/**
 * Returns a character set that contains the whitespace characters,
 * plus the newline characters, values 0x000A and 0x000D and nextline
 * 0x0085 character.
 */
+ (id) whitespaceAndNewlineCharacterSet;

/**
 * Returns a character set that contains the whitespace characters.
 */
+ (id) whitespaceCharacterSet;

/**
 * Returns a character set containing characters as encoded in the
 * data object (8192 bytes)
 */
+ (id) characterSetWithBitmapRepresentation: (NSData*)data;

/**
 *  Returns set with characters in aString, or empty set for empty string.
 *  Raises an exception if given a nil string.
 */
+ (id) characterSetWithCharactersInString: (NSString*)aString;

/**
 *  Returns set containing unicode index range given by aRange.
 */
+ (id) characterSetWithRange: (NSRange)aRange;

#if OS_API_VERSION(GS_API_OPENSTEP, GS_API_MACOSX)
/**
 *  Initializes from a bitmap (8192 bytes representing 65536 values).<br />
 *  Each bit set in the bitmap represents the fact that a character at
 *  that position in the unicode base plane exists in the characterset.<br />
 *  File must have extension "<code>.bitmap</code>".
 *  To get around this load the file into data yourself and use
 *  [NSCharacterSet -characterSetWithBitmapRepresentation].
 */
+ (id) characterSetWithContentsOfFile: (NSString*)aFile;
#endif

/**
 * Returns a bitmap representation of the receiver's character set
 * (suitable for archiving or writing to a file), in an NSData object.<br />
 */
- (NSData*) bitmapRepresentation;

/**
 * Returns YES if the receiver contains <em>aCharacter</em>, NO if
 * it does not.
 */
- (BOOL) characterIsMember: (unichar)aCharacter;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/**
 * Returns YES if the receiver contains at least one character in the
 * specified unicode plane.
 */
- (BOOL) hasMemberInPlane: (uint8_t)aPlane;
#endif

/**
 * Returns a character set containing only characters that the
 * receiver does not contain.
 */
- (NSCharacterSet*) invertedSet;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/**
 * Returns YES is all the characters in aSet are present in the receiver.
 */
- (BOOL) isSupersetOfSet: (NSCharacterSet*)aSet;

/**
 * Returns YES is the specified 32-bit character is present in the receiver.
 */
- (BOOL) longCharacterIsMember: (UTF32Char)aCharacter;
#endif
@end
    
    /**
     *  An [NSCharacterSet] that can be modified.
     */
    @interface NSMutableCharacterSet : NSCharacterSet

/**
 *  Adds characters specified by unicode indices in aRange to set.
 */
- (void) addCharactersInRange: (NSRange)aRange;

/**
 *  Adds characters in aString to set.
 */
- (void) addCharactersInString: (NSString*)aString;

/**
 *  Set intersection of character sets.
 */
- (void) formIntersectionWithCharacterSet: (NSCharacterSet*)otherSet;

/**
 *  Set union of character sets.
 */
- (void) formUnionWithCharacterSet: (NSCharacterSet*)otherSet;

/**
 *  Drop given range of characters.  No error for characters not currently in
 *  set.
 */
- (void) removeCharactersInRange: (NSRange)aRange;

/**
 *  Drop characters in aString.  No error for characters not currently in
 *  set.
 */
- (void) removeCharactersInString: (NSString*)aString;

/**
 *  Remove all characters currently in set and add all other characters.
 */
- (void) invert;

@end
    
#if	defined(__cplusplus)
}
#endif

#endif /* __NSCharacterSet_h_GNUSTEP_BASE_INCLUDE*/
