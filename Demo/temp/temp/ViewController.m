//
//  ViewController.m
//  temp
//
//  Created by JustinLau on 2019/7/5.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSDictionary *vipInfo = @{
                              @"type": @(1),
                              @"data": @{}
                              };
    NSDictionary *hehe = @{
                           @"gameInfo": vipInfo
                           };
    NSData *jsonedValue = [NSJSONSerialization dataWithJSONObject:hehe options:0 error:nil];
    NSString *jsonText = [[NSString alloc] initWithData:jsonedValue encoding:NSUTF8StringEncoding];
    NSLog(@"%@", jsonText);
}


@end
