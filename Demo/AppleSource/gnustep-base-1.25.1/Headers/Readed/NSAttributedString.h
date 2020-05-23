
#ifndef __NSAttributedString_h_GNUSTEP_BASE_INCLUDE
#define __NSAttributedString_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#import	<Foundation/NSObject.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
#import	<Foundation/NSString.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSArray.h>
#import	<Foundation/NSCoder.h>

/*

 这是一个数据类. 这个数据类中包含, 1: 原始的文本值. 2. 范围 3. 范围相关的一个字典, 这个字典里面, 是这个范围里面这个文本展示的一些信息. 例如, 字体, 颜色, 阴影, 删除线等等. iOS 定义了一些 key 值, 然后对应的展示空间, 也就是 LABEL, TEXTView 在绘制的时候, 会读取这些 key 值, 然后根据这些 key 值的 value 值进行展示.
*/
    
@interface NSAttributedString : NSObject <NSCoding, NSCopying, NSMutableCopying>
{
}

//Creating an NSAttributedString
- (id) initWithString: (NSString*)aString;
- (id) initWithAttributedString: (NSAttributedString*)attributedString;
- (id) initWithString: (NSString*)aString attributes: (NSDictionary*)attributes;

//Retrieving character information
- (int) length;
/** Returns the string content of the receiver.<br />
 * NB. this is actually a proxy to the internal content (which may change)
 * so if you need an immutable instance yu should copy the returned value,
 * not jhust retain it.
 */
- (NSString*) string;					//Primitive method!

// 获取某个位置的属性信息, 以及那个位置属性信息影响的范围.
- (NSDictionary*) attributesAtIndex: (int)index
		     effectiveRange: (NSRange*)aRange;	//Primitive method!

// 获取某个位置的属性信息, 以及在某个范围内, 这个属性信息影响的最长范围.
- (NSDictionary*) attributesAtIndex: (int)index
	      longestEffectiveRange: (NSRange*)aRange
			    inRange: (NSRange)rangeLimit;
// 获取某个属性在某个位置的信息, 以及最长影响的范围.
- (id) attribute: (NSString*)attributeName
	 atIndex: (int)index
  effectiveRange: (NSRange*)aRange;
// 加了范围的限制.
- (id) attribute: (NSString*)attributeName atIndex: (int)index
  longestEffectiveRange: (NSRange*)aRange inRange: (NSRange)rangeLimit;

// 比较, 先是 指针, 然后是字符串, 然后是属性及其属性范围.
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
			atIndex: (int)index;
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

#if	defined(__cplusplus)
}
#endif

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSAttributedString+GNUstepBase.h>
#endif

#endif	/* __NSAttributedString_h_GNUSTEP_BASE_INCLUDE */

