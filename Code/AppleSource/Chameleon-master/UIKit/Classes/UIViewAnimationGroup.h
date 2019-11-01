#import "UIView.h"

typedef NS_ENUM(NSInteger, UIViewAnimationGroupTransition) {
    UIViewAnimationGroupTransitionNone,
    UIViewAnimationGroupTransitionFlipFromLeft,
    UIViewAnimationGroupTransitionFlipFromRight,
    UIViewAnimationGroupTransitionCurlUp,
    UIViewAnimationGroupTransitionCurlDown,
    UIViewAnimationGroupTransitionFlipFromTop,
    UIViewAnimationGroupTransitionFlipFromBottom,
    UIViewAnimationGroupTransitionCrossDissolve,
};

extern BOOL UIViewAnimationOptionIsSet(UIViewAnimationOptions options, UIViewAnimationOptions option);

@interface UIViewAnimationGroup : NSObject

- (id)initWithAnimationOptions:(UIViewAnimationOptions)options;
- (id)actionForView:(UIView *)view forKey:(NSString *)keyPath;
- (void)setTransitionView:(UIView *)view shouldCache:(BOOL)cache;
- (NSArray *)allAnimatingViews;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) void *context;
@property (nonatomic, copy) void (^completionBlock)(BOOL finished);
@property (nonatomic, assign) BOOL allowUserInteraction;
@property (nonatomic, assign) BOOL beginsFromCurrentState;
@property (nonatomic, assign) UIViewAnimationCurve curve;
@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, strong) id delegate;
@property (nonatomic, assign) SEL didStopSelector;
@property (nonatomic, assign) SEL willStartSelector;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL repeatAutoreverses;
@property (nonatomic, assign) float repeatCount;
@property (nonatomic, assign) UIViewAnimationGroupTransition transition;

- (void)commit;

@end
