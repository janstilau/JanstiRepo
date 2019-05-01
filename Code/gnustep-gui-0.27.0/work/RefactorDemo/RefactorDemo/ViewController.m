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
    
    CALayer *layer = [[CALayer alloc] init];
    layer.frame = CGRectMake(20, 100, 200, 200);
    layer.backgroundColor = [[UIColor blueColor] CGColor];
    layer.contents  = (__bridge id) [[UIImage imageNamed:@"img.jpg"] CGImage];
    layer.contentsGravity = kCAGravityResize;
    layer.contentsScale = [[UIScreen mainScreen] scale];
    layer.masksToBounds = YES;
    layer.contentsScale = 30.0;
    layer.contentsCenter = CGRectMake(0.49, 0.49, 0.01, 0.01);
    
    [self.view.layer addSublayer:layer];
    
    layer = [[CALayer alloc] init];
    layer.frame = CGRectMake(20, 500, 200, 200);
    layer.backgroundColor = [[UIColor blueColor] CGColor];
    layer.contents  = (__bridge id) [[UIImage imageNamed:@"img.jpg"] CGImage];
    layer.contentsGravity = kCAGravityCenter;
    layer.contentsScale = 30.0;
    [self.view.layer addSublayer:layer];
   
}


@end
