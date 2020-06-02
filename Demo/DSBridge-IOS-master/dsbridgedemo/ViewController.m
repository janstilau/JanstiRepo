//
//  ViewController.m
//  jsbridgedemo
//
//  Created by wendu on 17/1/1.
//  Copyright © 2017 wendu. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import "JsEchoApi.h"

@interface ViewController ()

@property (nonatomic, strong) DWKWebView *dwebview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect bounds=self.view.bounds;
    DWKWebView *dwebview=[[DWKWebView alloc] initWithFrame:CGRectMake(0, 25, bounds.size.width, bounds.size.height-25)];
    [self.view addSubview:dwebview];
    dwebview.navigationDelegate=self;
    // load test.html
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    NSString * htmlPath = [[NSBundle mainBundle] pathForResource:@"test"
                                                          ofType:@"html"];
    NSString * htmlContent = [NSString stringWithContentsOfFile:htmlPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    [dwebview loadHTMLString:htmlContent baseURL:baseURL];
    
    _dwebview = dwebview;
    [self webViewRegisterOCCallBack];
    [self ocCallWebViewMethod];
    [self ocCheckWebViewMethod];

}

- (void)webViewRegisterOCCallBack {
    // register api object without namespace
    [_dwebview  addJavascriptObject:[[JsApiTest alloc] init] namespace:nil];
    
    // register api object with namespace "echo"
    [_dwebview addJavascriptObject:[[JsEchoApi alloc] init] namespace:@"echo"];
    
    // open debug mode, Release mode should disable this.
    [_dwebview setDebugMode:true];
    
    [_dwebview customJavascriptDialogLabelTitles:@{@"alertTitle":@"Notification",@"alertBtn":@"OK"}];
}

- (void)ocCallWebViewMethod {
    // call javascript method
    [_dwebview callHandler:@"addValue" arguments:@[@3,@4] completionHandler:^(NSNumber * value){
        NSLog(@"%@",value);
    }];

    [_dwebview callHandler:@"append" arguments:@[@"I",@"love",@"you"] completionHandler:^(NSString * _Nullable value) {
       NSLog(@"call succeed, append string is: %@",value);
    }];

    // this invocation will be return 5 times
    [_dwebview callHandler:@"startTimer" completionHandler:^(NSNumber * _Nullable value) {
        NSLog(@"Timer: %@",value);
    }];

    // namespace syn test
    [_dwebview callHandler:@"syn.addValue" arguments:@[@5,@6] completionHandler:^(NSDictionary * _Nullable value) {
         NSLog(@"Namespace syn.addValue(5,6): %@",value);
    }];
    
    [_dwebview callHandler:@"syn.getInfo" completionHandler:^(NSDictionary * _Nullable value) {
        NSLog(@"Namespace syn.getInfo: %@",value);
    }];
    
    // namespace asyn test
    [_dwebview callHandler:@"asyn.addValue" arguments:@[@5,@6] completionHandler:^(NSDictionary * _Nullable value) {
        NSLog(@"Namespace asyn.addValue(5,6): %@",value);
    }];
    
    [_dwebview callHandler:@"asyn.getInfo" completionHandler:^(NSDictionary * _Nullable value) {
        NSLog(@"Namespace asyn.getInfo: %@",value);
    }];
}

- (void)ocCheckWebViewMethod {
    // test if javascript method exists.
    [_dwebview hasJavascriptMethod:@"addValue" methodExistCallback:^(bool exist) {
        NSLog(@"method 'addValue' exist : %d",exist);
    }];
    
    [_dwebview hasJavascriptMethod:@"XX" methodExistCallback:^(bool exist) {
        NSLog(@"method 'XX' exist : %d",exist);
    }];
    
    [_dwebview hasJavascriptMethod:@"asyn.addValue" methodExistCallback:^(bool exist) {
        NSLog(@"method 'asyn.addValue' exist : %d",exist);
    }];
    
    [_dwebview hasJavascriptMethod:@"asyn.XX" methodExistCallback:^(bool exist) {
        NSLog(@"method 'asyn.XX' exist : %d",exist);
    }];
    
    // set javascript close listener
    [_dwebview setJavascriptCloseWindowListener:^{
        NSLog(@"window.close called");
    } ];
}


@end
