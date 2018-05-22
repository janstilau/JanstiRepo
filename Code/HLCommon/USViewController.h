//
//  USViewController.h
//  USEvent
//
//  Created by marujun on 15/9/8.
//  Copyright (c) 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "USTransitionAnimator.h"

@interface USNavigationBar : UINavigationBar

@property(nonatomic, strong) UILabel *bottomLine;

@end

@interface USViewController : UIViewController
{
    float _topInset;
    
    NSString *_hint;
    USNavigationTransitionOption _transitionOption;
}

@property(nonatomic, strong) NSString *hint;
@property(nonatomic, assign) float topInset;

@property(nonatomic, strong) USNavigationBar *navigationBar;
@property(nonatomic, strong) UINavigationItem *myNavigationItem;

@property (nonatomic, assign) USNavigationTransitionOption transitionOption;

/** 是否允许显示状态栏上的返回顶部提示 */
@property (nonatomic, assign) BOOL enableStatusBarTip;

/** 是否允许屏幕边缘侧滑手势 */
@property (nonatomic, assign) BOOL enableScreenEdgePanGesture;


- (void)updateDisplay;

+ (instancetype)viewController;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

/** 提前加载(CollectionView、TableView)可视范围内的图片，cell需要重写loadingImageUrl或者loadingImageUrlArray方法！！！ */
- (void)bringVisibleImageLoadingForward:(UIScrollView *)scrollView;

- (UIViewController *)viewControllerWillPushForLeftDirectionPan;

@end
