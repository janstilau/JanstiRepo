#ifndef __NSAttributedString_h_GNUSTEP_BASE_INCLUDE
#define __NSAttributedString_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
#import	<Foundation/NSString.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSArray.h>
#import	<Foundation/NSCoder.h>

/*
 非常重要的一个类, YYLabel, YYTextView 都是以这个类为基础进行的构建.
 
 A string that has associated attributes (such as visual style, hyperlinks, or accessibility data) for portions of its text.
 
 */

/*
 m 文件中的实现太过于复杂, 不过简单来首, m 文件中, 会做好 attribute 数组的复制和链接的工作.
 
 NSMutableAttributedString *textM = [[NSMutableAttributedString alloc] initWithString:@"123456789"];
 [textM setAttribute:NSForegroundColorAttributeName value:[UIColor redColor]];
 NSLog(@"%@", textM);
 
 [textM setAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:12] range:NSMakeRange(5, 3)];
 NSLog(@"%@", textM);
 
 [textM removeAttribute:NSFontAttributeName range:NSMakeRange(6, 1)];
 NSLog(@"%@", textM);
 
 
 2020-09-10 13:08:16.862124+0800 MCMoego[80326:3052706] 123456789    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }
 2020-09-10 13:08:16.862288+0800 MCMoego[80326:3052706] 12345    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }678    {
     NSFont = <UICTFont: 0x7f9cfdd22d50> font-family: ".SFUI-Regular"; font-weight: normal; font-style: normal; font-size: 12.00pt,
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }9    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }
 2020-09-10 13:08:16.862407+0800 MCMoego[80326:3052706] 12345    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }6    {
     NSFont = <UICTFont: 0x7f9cfdd22d50> font-family: ".SFUI-Regular"; font-weight: normal; font-style: normal; font-size: 12.00pt,
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }7    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }8    {
     NSFont = <UICTFont: 0x7f9cfdd22d50> font-family: ".SFUI-Regular"; font-weight: normal; font-style: normal; font-size: 12.00pt,
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }9    {
     NSColor = UIExtendedSRGBColorSpace 1 0 0 1,
 }
 */

@interface NSAttributedString : NSObject <NSCoding, NSCopying, NSMutableCopying>
{
}

//Creating an NSAttributedString
- (id) initWithString: (NSString*)aString;
- (id) initWithAttributedString: (NSAttributedString*)attributedString;
- (id) initWithString: (NSString*)aString attributes: (NSDictionary*)attributes;

//Retrieving character information
- (NSUInteger) length;
/** Returns the string content of the receiver.<br />
 * NB. this is actually a proxy to the internal content (which may change)
 * so if you need an immutable instance you should copy the returned value,
 * not just retain it.
 */
- (NSString*) string;					//Primitive method!

//Retrieving attribute information
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
                     effectiveRange: (NSRange*)aRange;	//Primitive method!
- (NSDictionary*) attributesAtIndex: (NSUInteger)index
              longestEffectiveRange: (NSRange*)aRange
                            inRange: (NSRange)rangeLimit;
- (id) attribute: (NSString*)attributeName
         atIndex: (NSUInteger)index
  effectiveRange: (NSRange*)aRange;
- (id) attribute: (NSString*)attributeName atIndex: (NSUInteger)index
longestEffectiveRange: (NSRange*)aRange inRange: (NSRange)rangeLimit;

//Comparing attributed strings
- (BOOL) isEqualToAttributedString: (NSAttributedString*)otherString;

//Extracting a substring
- (NSAttributedString*) attributedSubstringFromRange: (NSRange)aRange;

@end //NSAttributedString


@interface NSMutableAttributedString : NSAttributedString
{
}

//Retrieving character information
- (NSMutableString*) mutableString;

//Changing characters
- (void) deleteCharactersInRange: (NSRange)aRange;

//Changing attributes
- (void) setAttributes: (NSDictionary*)attributes
                 range: (NSRange)aRange;		//Primitive method!
- (void) addAttribute: (NSString*)name value: (id)value range: (NSRange)aRange;
- (void) addAttributes: (NSDictionary*)attributes range: (NSRange)aRange;
- (void) removeAttribute: (NSString*)name range: (NSRange)aRange;

//Changing characters and attributes
- (void) appendAttributedString: (NSAttributedString*)attributedString;
- (void) insertAttributedString: (NSAttributedString*)attributedString
                        atIndex: (NSUInteger)index;
- (void) replaceCharactersInRange: (NSRange)aRange
             withAttributedString: (NSAttributedString*)attributedString;
- (void) replaceCharactersInRange: (NSRange)aRange
                       withString: (NSString*)aString;	//Primitive method!
- (void) setAttributedString: (NSAttributedString*)attributedString;

//Grouping changes
- (void) beginEditing;
- (void) endEditing;

@end //NSMutableAttributedString

#endif /* GS_API_MACOSX */

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSAttributedString+GNUstepBase.h>
#endif

#endif	/* __NSAttributedString_h_GNUSTEP_BASE_INCLUDE */

