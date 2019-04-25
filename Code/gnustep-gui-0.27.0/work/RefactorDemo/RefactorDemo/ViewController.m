//
//  ViewController.m
//  RefactorDemo
//
//  Created by JustinLau on 2019/4/23.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"
#import "MCGradientView.h"

@interface ViewController ()



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    MCGradientView *gradient = [[MCGradientView alloc] initWithFrame:CGRectMake(20, 50, 400, 200)];
    gradient.colors = @[[UIColor redColor], [UIColor grayColor]];
    gradient.layer.cornerRadius = 100;
    gradient.layer.masksToBounds = YES;
    [self.view addSubview:gradient];
}


@end
