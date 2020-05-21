#import "UIStringDrawing.h"
#import "UIScrollView.h"
#import "UIDataDetectors.h"
#import "UITextInput.h"

extern NSString *const UITextViewTextDidBeginEditingNotification;
extern NSString *const UITextViewTextDidChangeNotification;
extern NSString *const UITextViewTextDidEndEditingNotification;

@class UIColor, UIFont, UITextView;

@protocol UITextViewDelegate <NSObject, UIScrollViewDelegate>
@optional
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;
- (void)textViewDidBeginEditing:(UITextView *)textView;
- (BOOL)textViewShouldEndEditing:(UITextView *)textView;
- (void)textViewDidEndEditing:(UITextView *)textView;
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewDidChange:(UITextView *)textView;
- (void)textViewDidChangeSelection:(UITextView *)textView;
@end

@interface UITextView : UIScrollView <UITextInput>
- (void)scrollRangeToVisible:(NSRange)range;
- (BOOL)hasText;

@property (nonatomic) UITextAlignment textAlignment; // stub, not yet implemented!
@property (nonatomic) NSRange selectedRange;
@property (nonatomic, getter=isEditable) BOOL editable;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic) UIDataDetectorTypes dataDetectorTypes;
@property (nonatomic, assign) id<UITextViewDelegate> delegate;
@property (readwrite, strong) UIView *inputAccessoryView;
@property (readwrite, strong) UIView *inputView;
@end
