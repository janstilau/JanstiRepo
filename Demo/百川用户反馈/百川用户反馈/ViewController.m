//
//  ViewController.m
//  百川用户反馈
//
//  Created by jansti on 16/11/28.
//  Copyright © 2016年 jansti. All rights reserved.
//

#import "ViewController.h"
#import "FBViewController.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    FBViewController *vc = [[FBViewController alloc] initWithNibName:nil bundle:nil];
    [self presentViewController:vc animated:YES completion:nil];
    
    
}


@end
