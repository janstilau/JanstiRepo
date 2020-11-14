#import <Foundation/Foundation.h>

@class UIImage, UIColor;

@interface UIPasteboard : NSObject
+ (UIPasteboard *)generalPasteboard;

- (void)addItems:(NSArray *)items;
- (void)setData:(NSData *)data forPasteboardType:(NSString *)pasteboardType;
- (void)setValue:(id)value forPasteboardType:(NSString *)pasteboardType;

@property (nonatomic,copy) NSURL *URL;
@property (nonatomic,copy) NSArray *URLs;
@property (nonatomic,copy) NSString *string;
@property (nonatomic,copy) NSArray *strings;
@property (nonatomic, copy) UIImage *image;
@property (nonatomic, copy) NSArray *images;
@property (nonatomic, copy) UIColor *color;
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray *items;
@end
