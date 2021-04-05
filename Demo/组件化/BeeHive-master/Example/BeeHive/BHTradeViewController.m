//
//  BHTradeViewController.m
//  BeeHive
//
//  Created by 一渡 on 7/14/15.
//  Copyright (c) 2015 一渡. All rights reserved.
//

#import "BHTradeViewController.h"
#import "BeeHive.h"


@implementation BHTradeViewController

@synthesize itemId=_itemId;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame)-100, 0, 200, 300)];
    label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"%@", self.itemId];
    
    [self.view addSubview:label];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame)-50,
                                                               CGRectGetMaxY(label.frame)-20,
                                                               100,
                                                               80)];
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    btn.backgroundColor = [UIColor blackColor];
    
    [btn setTitle:@"点我" forState:UIControlStateNormal];
    
    [btn addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btn];
}


// 业务代码里面, #import "BHService.h"
// 这样, 业务代码里面, 就能够取到所需要的 protocol 的定义了. 然后在需要服务的时候, 调用 [BeeHive shareInstance] 来获取到 Protocol Imp 的对象, 然后使用 protocol 中定义的方法来获得服务.
// 到底, 实现类是什么, 不用暴露在业务类的代码里面.
-(void)click:(UIButton *)btn
{
    id<TradeServiceProtocol> obj = [[BeeHive shareInstance] createService:@protocol(TradeServiceProtocol)];
    if ([obj isKindOfClass:[UIViewController class]]) {
        obj.itemId = @"12313231231";
        [self.navigationController pushViewController:(UIViewController *)obj animated:YES];
    }
}

@end
