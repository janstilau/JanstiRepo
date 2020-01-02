//
//  ViewController.m
//  clipDemo
//
//  Created by JustinLau on 2019/12/19.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"
#import "ClipView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor yellowColor];
    ClipView *clipView = [[ClipView alloc] init];
    CGSize size = self.view.frame.size;
    clipView.frame = CGRectMake(0, 100, size.width, 500);
    [self.view addSubview:clipView];
}


@end
