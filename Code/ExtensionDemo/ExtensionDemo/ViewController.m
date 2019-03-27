//
//  ViewController.m
//  ExtensionDemo
//
//  Created by JustinLau on 2019/3/26.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSURLConnectionDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURLRequest *request;
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    
    
}


@end
