#import <Foundation/Foundation.h>

@interface UIFont : NSObject {
@package
    CTFontRef _font;
}

+ (UIFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize;
+ (NSArray *)familyNames;
+ (NSArray *)fontNamesForFamilyName:(NSString *)familyName;

+ (UIFont *)systemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)fontSize;

- (UIFont *)fontWithSize:(CGFloat)fontSize;

@property (nonatomic, readonly, strong) NSString *fontName;
@property (nonatomic, readonly) CGFloat ascender;
@property (nonatomic, readonly) CGFloat descender;
@property (nonatomic, readonly) CGFloat lineHeight;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGFloat xHeight;
@property (nonatomic, readonly) CGFloat capHeight;
@property (nonatomic, readonly, strong) NSString *familyName;
@end
