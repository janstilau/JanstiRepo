//
//  USLoadingView.h
//  USEvent
//
//  Created by marujun on 15/10/15.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "USIndicatorView.h"

@interface USLoadingView : UIView
{
    __weak IBOutlet UILabel *loadingTextLabel;
    __weak IBOutlet UIImageView *loadingImage;
    __weak IBOutlet USIndicatorView *indicatorView;
    __weak IBOutlet UIImageView *bgView;
}

@property (assign, nonatomic) Class requestClass;
@property (assign, nonatomic) NSURLSessionTask *requestOperation;

@property (weak, nonatomic) IBOutlet UIView *centerView;

+ (instancetype)onlyInstance;

//+ (instancetype)showWithRequestClass:(id)viewOrVcObj;
//+ (instancetype)showWithRequestClass:(id)viewOrVcObj inView:(UIView *)view;
//+ (instancetype)showWithRequestClass:(id)viewOrVcObj text:(NSString *)text;

+ (instancetype)showWithText:(NSString *)text;
+ (instancetype)showWithText:(NSString *)text inView:(UIView *)view;

+ (instancetype)showWithImage:(UIImage *)image;
+ (instancetype)showWithImage:(UIImage *)image inView:(UIView *)view;

- (void)setLoadingImage:(UIImage *)image;
- (void)setLoadingText:(NSString *)text;

+ (void)removeLoadingView;
+ (void)removeWithNoneAnimation;

@end
