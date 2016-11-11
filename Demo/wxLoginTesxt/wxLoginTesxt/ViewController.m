//
//  ViewController.m
//  wxLoginTesxt
//
//  Created by justin lau on 16/5/1.
//  Copyright © 2016年 justin lau. All rights reserved.
//

#import "ViewController.h"
#import "WXApi.h"

#define  kAppKey @"wxe63a6af33be57b5d"
#define  kAppSecret @"bc88d2d1352bff72c3c3e66628c2f89d"



@interface ViewController ()
@property (nonatomic, copy) NSString *code;

@property (nonatomic, copy) NSString *access_token;
@property (nonatomic, copy) NSString *refresh_token;

@property (nonatomic, copy) NSString *openId;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
}


/*! @brief 收到一个来自微信的请求，第三方应用程序处理完后调用sendResp向微信发送结果
 *
 * 收到一个来自微信的请求，异步处理完成后必须调用sendResp发送处理结果给微信。
 * 可能收到的请求有GetMessageFromWXReq、ShowMessageFromWXReq等。
 * @param req 具体请求内容，是自动释放的
 */
-(void) onReq:(BaseReq*)req{
    
    NSLog(@"has receive wx requ");
    NSLog(@"%@",req);
    
}



/*! @brief 发送一个sendReq后，收到微信的回应
 *
 * 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。
 * 可能收到的处理结果有SendMessageToWXResp、SendAuthResp等。
 * @param resp具体的回应内容，是自动释放的
 */
-(void) onResp:(BaseResp*)resp{
    
    
    SendAuthResp *authResp = (SendAuthResp *)resp;
    _code = authResp.code;
    
}


- (IBAction)code:(id)sender {
    
    SendAuthReq *authReq = [[SendAuthReq alloc] init];
    authReq.scope = @"snsapi_userinfo" ;
    authReq.state = @"woyaocaowufan";
    
    [WXApi sendReq:authReq];
    
}

- (IBAction)token:(id)sender {
    
    
    NSString *urlString =[NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code",kAppKey,kAppSecret,_code];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *dataStr = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        NSData *data = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"%@",dict);
        
        self.access_token = dict[@"access_token"];
        self.refresh_token = dict[@"refresh_token"];
        self.openId = dict[@"openid"];
        
        
        
    });
    
}

- (IBAction)info:(id)sender {
    
    NSString *infoUrlString = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@",_access_token,_openId];
    NSURL *infoUrl = [NSURL URLWithString:infoUrlString];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSString *infoResult = [NSString stringWithContentsOfURL:infoUrl encoding:NSUTF8StringEncoding error:nil];
        NSData *infoData = [infoResult dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *infoDict = [NSJSONSerialization JSONObjectWithData:infoData options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"%@",infoDict);
        
    });
    
    
}

- (IBAction)refresh:(id)sender {
    
    NSString *refreshUrlString = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/refresh_token?appid=%@&grant_type=refresh_token&refresh_token=%@",kAppKey,_refresh_token];
    NSURL *refreshUrl = [NSURL URLWithString:refreshUrlString];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSString *result = [NSString stringWithContentsOfURL:refreshUrl encoding:NSUTF8StringEncoding error:nil];
        NSData *resultData = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"%@",resultDict);
        
    });
    
}





- (void)test{
    
    UITextField *textField;
    textField.enablesReturnKeyAutomatically = YES;
    
    
    
}




























@end
