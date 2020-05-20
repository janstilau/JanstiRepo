//
//  ZFPlayerDetailViewController.m
//  ZFPlayer_Example
//
//  Created by 紫枫 on 2018/9/12.
//  Copyright © 2018年 紫枫. All rights reserved.
//  视频详情页

#import "ZFPlayerDetailViewController.h"
#import <ZFPlayer/ZFPlayer.h>
#import <ZFPlayer/ZFAVPlayerManager.h>
#import <ZFPlayer/ZFIJKPlayerManager.h>
#import <ZFPlayer/KSMediaPlayerManager.h>
#import <ZFPlayer/ZFPlayerControlView.h>
#import "ZFSmallPlayViewController.h"
#import "UIImageView+ZFCache.h"
#import "ZFUtilities.h"

static NSString *kVideoCover = @"https://upload-images.jianshu.io/upload_images/635942-14593722fe3f0695.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240";

@interface ZFPlayerDetailViewController ()

@property (nonatomic, strong) UIImageView *containerView;
@property (nonatomic, strong) UIButton *playBtn;

@end

@implementation ZFPlayerDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.playBtn];
    [self.player addPlayerViewToContainerView:self.containerView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat x = 0;
    CGFloat y = CGRectGetMaxY(self.navigationController.navigationBar.frame);
    CGFloat w = CGRectGetWidth(self.view.frame);
    CGFloat h = w*9/16;
    self.containerView.frame = CGRectMake(x, y, w, h);
    
    w = 44;
    h = w;
    x = (CGRectGetWidth(self.containerView.frame)-w)/2;
    y = (CGRectGetHeight(self.containerView.frame)-h)/2;
    self.playBtn.frame = CGRectMake(x, y, w, h);
}


// 这里, 是通过 didMoveToParentViewController 这个函数里面, parent 的 nil 与否判断是否是退出操作的.
// Called after the view controller is added or removed from a container view controller.
/*
 Your view controller can override this method when it wants to react to being added to a container.
 If you are implementing your own container view controller, it must call the didMoveToParentViewController: method of the child view controller after the transition to the new controller is complete or, if there is no transition, immediately after calling the addChildViewController: method.
 The removeFromParentViewController method automatically calls the didMoveToParentViewController: method of the child view controller after it removes the child.
 也就是说, NAVVc, 或者 TabVc 在添加 childVC 的时候, 其实是调用了 didMoveToParentViewController 的了.
 */
- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (!parent) {
        if (self.detailVCPopCallback) {
            self.detailVCPopCallback();
        }
    }
}

- (void)playClick:(UIButton *)sender {
    if (self.detailVCPlayCallback) {
        self.detailVCPlayCallback();
    }
    [self.player addPlayerViewToContainerView:self.containerView];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (self.player.isFullScreen) {
        return UIStatusBarStyleLightContent;
    }
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden {
    /// 如果只是支持iOS9+ 那直接return NO即可，这里为了适配iOS8
    return self.player.isStatusBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationSlide;
}

- (BOOL)shouldAutorotate {
    return self.player.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.player.isFullScreen) {
        return UIInterfaceOrientationMaskLandscape;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (UIImageView *)containerView {
    if (!_containerView) {
        _containerView = [UIImageView new];
        [_containerView setImageWithURLString:kVideoCover placeholder:[ZFUtilities imageWithColor:[UIColor colorWithRed:220/255.0 green:220/255.0 blue:220/255.0 alpha:1] size:CGSizeMake(1, 1)]];
    }
    return _containerView;
}

- (UIButton *)playBtn {
    if (!_playBtn) {
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_playBtn setImage:[UIImage imageNamed:@"new_allPlay_44x44_"] forState:UIControlStateNormal];
        [_playBtn addTarget:self action:@selector(playClick:) forControlEvents:UIControlEventTouchUpInside];
        [_playBtn addBorderLine];
    }
    return _playBtn;
}

@end
