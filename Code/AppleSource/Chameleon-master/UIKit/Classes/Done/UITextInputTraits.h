#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) {
    UITextAutocapitalizationTypeNone,
    UITextAutocapitalizationTypeWords,
    UITextAutocapitalizationTypeSentences,
    UITextAutocapitalizationTypeAllCharacters,
};

typedef NS_ENUM(NSInteger, UITextAutocorrectionType) {
    UITextAutocorrectionTypeDefault,
    UITextAutocorrectionTypeNo,
    UITextAutocorrectionTypeYes,
};

typedef NS_ENUM(NSInteger, UIKeyboardAppearance) {
    UIKeyboardAppearanceDefault,
    UIKeyboardAppearanceAlert,
};

typedef NS_ENUM(NSInteger, UIKeyboardType) {
    UIKeyboardTypeDefault,
    UIKeyboardTypeASCIICapable,
    UIKeyboardTypeNumbersAndPunctuation,
    UIKeyboardTypeURL,
    UIKeyboardTypeNumberPad,
    UIKeyboardTypePhonePad,
    UIKeyboardTypeNamePhonePad,
    UIKeyboardTypeEmailAddress,
    UIKeyboardTypeDecimalPad,
    UIKeyboardTypeTwitter,
    UIKeyboardTypeAlphabet = UIKeyboardTypeASCIICapable
};

typedef NS_ENUM(NSInteger, UIReturnKeyType) {
    UIReturnKeyDefault,
    UIReturnKeyGo,
    UIReturnKeyGoogle,
    UIReturnKeyJoin,
    UIReturnKeyNext,
    UIReturnKeyRoute,
    UIReturnKeySearch,
    UIReturnKeySend,
    UIReturnKeyYahoo,
    UIReturnKeyDone,
    UIReturnKeyEmergencyCall,
};

@protocol UITextInputTraits <NSObject>
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType; // 自动大写
@property (nonatomic) UITextAutocorrectionType autocorrectionType; // 自动更正
@property (nonatomic) BOOL enablesReturnKeyAutomatically; // 自动 returnKey 可按状态切换
@property (nonatomic) UIKeyboardAppearance keyboardAppearance; // 键盘颜色风格
@property (nonatomic) UIKeyboardType keyboardType; // 键盘种类
@property (nonatomic) UIReturnKeyType returnKeyType; // 回车键类型
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@end
