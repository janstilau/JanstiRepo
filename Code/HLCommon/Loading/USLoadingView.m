//
//  USLoadingView.m
//  USEvent
//
//  Created by marujun on 15/10/15.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import "USLoadingView.h"

static USLoadingView *loadingView_only = nil;

@implementation USLoadingView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [indicatorView startAnimating];
}

+ (instancetype)onlyInstance
{
    return loadingView_only;
}

//+ (instancetype)showWithRequestClass:(id)viewOrVcObj
//{
//    return [self showWithRequestClass:viewOrVcObj text:nil inView:nil];
//}
//
//+ (instancetype)showWithRequestClass:(id)viewOrVcObj inView:(UIView *)view
//{
//    return [self showWithRequestClass:viewOrVcObj text:nil inView:view];
//}
//
//+ (instancetype)showWithRequestClass:(id)viewOrVcObj text:(NSString *)text 
//{
//    return [self showWithRequestClass:viewOrVcObj text:nil inView:nil];
//}
//
//+ (instancetype)showWithRequestClass:(id)viewOrVcObj text:(NSString *)text inView:(UIView *)view
//{
//    USLoadingView *loadindView = [self showWithText:text inView:view];
//    
//    UIViewController *vc = nil;
//    if ([viewOrVcObj isKindOfClass:[UIView class]]) {
//        vc = [viewOrVcObj nearsetViewController];
//    }else if([viewOrVcObj isKindOfClass:[UIViewController class]]){
//        vc = viewOrVcObj;
//    }
//    
//    if (vc && [vc parentViewController]) {
//        loadindView.requestClass = [[vc parentViewController] class];
//    }else{
//        loadindView.requestClass = [viewOrVcObj class];
//    }
//    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        loadindView.requestOperation = [HttpManager defaultManager].operationManager.operationQueue.operations.lastObject;
//    });
//    
//    return loadindView;
//}

+ (instancetype)showWithText:(NSString *)text
{
    return [self showWithText:text image:nil inView:nil];
}
+ (instancetype)showWithImage:(UIImage *)image
{
    return [self showWithText:nil image:image inView:nil];
}
+ (instancetype)showWithText:(NSString *)text inView:(UIView *)view
{
    return [self showWithText:text image:nil inView:view];
}
+ (instancetype)showWithImage:(UIImage *)image inView:(UIView *)view
{
    return [self showWithText:nil image:image inView:view];
}

- (void)setLoadingText:(NSString *)text
{
    loadingTextLabel.text = text?:@"";
}
- (void)setLoadingImage:(UIImage *)image
{
    loadingImage.image = image;
}

// 加到指定view
+ (instancetype)showWithText:(NSString *)text image:(UIImage *)image inView:(UIView *)view
{
    if (loadingView_only) {
        [loadingView_only removeFromSuperview];
        loadingView_only = nil;
    }
    
    loadingView_only = [[[NSBundle mainBundle] loadNibNamed:@"USLoadingView" owner:self options:nil] firstObject];
    if (!text || !text.length) {
//        float length = 90;
//        [loadingView_only.centerView autoSetDimensionsToSize:CGSizeMake(length, length)];
//        [loadingView_only.centerView autoRemoveSubviewsConstraint];
//        [loadingView_only->indicatorView autoCenterInSuperview];
    }
    
    view = view ? view : [UIApplication topMostWindow];
    [[loadingView_only initLoadingText:text image:image] showInView:view];
    
    return loadingView_only;
}

//加载中
- (id)initLoadingText:(NSString *)text image:(UIImage *)image
{
    if (image) {
        [self setLoadingImage:image];
        
        indicatorView.alpha = 0;
        loadingTextLabel.alpha = 0;
    }else{
        [self setLoadingText:text];
        
        indicatorView.alpha = 1;
        loadingTextLabel.alpha = 1;
    }
    return self;
}

- (void)showInView:(UIView *)view
{
    [view addSubview:self];
    [self autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    
    self.alpha = 0;
    [UIView animateWithDuration:.1 animations:^{
        self.alpha = 1;
    }];
}

+ (void)removeLoadingView
{
    dispatch_async_on_main_queue(^{
        if (!loadingView_only) {
            return;
        }
        
        loadingView_only.requestOperation = nil;
        
        if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) {
            //在7上加动画容易死机
            [loadingView_only removeFromSuperview];
            loadingView_only = nil;
        }
        else {
            [UIView animateWithDuration:.2 animations:^{
                loadingView_only.alpha = 0;
            } completion:^(BOOL finished) {
                [loadingView_only removeFromSuperview];
                loadingView_only = nil;
            }];
        }
    });
}

+ (void)removeWithNoneAnimation
{
    if (!loadingView_only) {
        return;
    }
    
    dispatch_async_on_main_queue(^{
        [loadingView_only removeFromSuperview];
        loadingView_only = nil;
    });
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    //只有左上角区域可点击
    if (_requestClass && point.x>0&&point.x<64&&point.y>0&&point.y<64) {
        return nil;
    }
    
    return self;
}

- (void)dealloc
{
    DLOG(@"TCLoadingView dealloc");
}

@end
