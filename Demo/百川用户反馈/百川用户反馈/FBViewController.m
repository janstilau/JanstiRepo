//
//  FBViewController.m
//  百川用户反馈
//
//  Created by jansti on 16/11/28.
//  Copyright © 2016年 jansti. All rights reserved.
//

#import "FBViewController.h"
#import "UIView+AutoLayout.h"
#import <YWFeedbackFMWK/YWFeedbackKit.h>
#import <YWFeedbackFMWK/YWFeedbackViewController.h>

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif



@interface FBViewController ()

@property (nonatomic, strong) NSDictionary *extInfo;

@end

@implementation FBViewController

static YWFeedbackKit *_feedbackKit = nil;

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_feedbackKit == nil){
       _feedbackKit = [[YWFeedbackKit alloc] initWithAppKey:@"23549859"];
    }
    self.view.backgroundColor = [UIColor redColor];
    
    _feedbackKit.extInfo = @{@"uid":@"uid",@"name":@"nikename",@"越狱":@"否"};
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    @weakify(self)
    
    [_feedbackKit makeFeedbackViewControllerWithCompletionBlock:^(YWFeedbackViewController *viewController, NSError *error) {
        
        if ( viewController != nil ) {
         
            
            viewController.title = @"反馈界面";
            
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewController];
            nav.navigationBar.clipsToBounds = YES;
            
            [weak_self addChildViewController:nav];
            [weak_self.view addSubview:nav.view];
            [nav.view autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
            
            
            
            viewController.closeBlock = ^(YWFeedbackViewController *feedbackController){
                [nav.view removeFromSuperview];
                [nav removeFromParentViewController];
            };
            
        } else {
            NSLog(@"123123");
        }
    }];
    
    
    
}


@end
