#import "UITextInputTraits.h"

@interface UITextPosition : NSObject
@end

@interface UITextRange : NSObject
@property (nonatomic, readonly) UITextPosition *start;
@property (nonatomic, readonly) UITextPosition *end;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@end

@protocol UIKeyInput <UITextInputTraits>
@end

@protocol UITextInput <UIKeyInput>
@property (readwrite, copy) UITextRange *selectedTextRange;
@property (nonatomic, readonly) UITextPosition *beginningOfDocument;
@property (nonatomic, readonly) UITextPosition *endOfDocument;
- (NSInteger)offsetFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition;
- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset;
- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition;
@end
