# Common 组件

## netWork

``` c++

#define CUSTOM_API_DOMAIN      [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_CustomApiDomain]

#define SERVER_API_DOMAIN      [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_ApiDomain]
#define SERVER_SPREAD_DOMAIN   [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_SpreadDomain]
#define SERVER_TUBE_DOMAIN     [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_TubeDomain]
#define SERVER_LOG_DOMAIN      [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_LogDomain]
#define SERVER_UPLOAD_DOMAIN   [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_UploadDomain]
#define SERVER_IMAGE_DOMAIN    [[NSUserDefaults standardUserDefaults] objectForKey:UserDefaultKey_DownloadDomain]

//-------外网------
//#define INIT_DOMAIN      CUSTOM_API_DOMAIN?:@"https://api.happyin.com.cn"
//#define API_DOMAIN       SERVER_API_DOMAIN?:INIT_DOMAIN
//#define IMAGE_DOMAIN     SERVER_IMAGE_DOMAIN?:@"hipub-10023356.file.myqcloud.com"
//#define UPLOAG_DOMAIN    SERVER_UPLOAD_DOMAIN?:INIT_DOMAIN
//#define TUBE_DOMAIN      SERVER_TUBE_DOMAIN?:@"push.happyin.com.cn:7237"
//#define SPREAD_DOMAIN    SERVER_SPREAD_DOMAIN?:@"push.happyin.com.cn:7239"


//-------模拟外网测试------
//#define INIT_DOMAIN      CUSTOM_API_DOMAIN?:@"119.29.77.36:9984"
//#define API_DOMAIN       SERVER_API_DOMAIN?:INIT_DOMAIN
//#define IMAGE_DOMAIN     SERVER_IMAGE_DOMAIN?:@"us-10000031.file.myqcloud.com"
//#define UPLOAG_DOMAIN    SERVER_UPLOAD_DOMAIN?:INIT_DOMAIN
//#define TUBE_DOMAIN      SERVER_TUBE_DOMAIN?:@"119.29.44.245:1237"
//#define SPREAD_DOMAIN    SERVER_SPREAD_DOMAIN?:@"119.29.44.245:1236"


//-------审核环境测试------
//#define INIT_DOMAIN      CUSTOM_API_DOMAIN?:@"ios.himoca.com"
//#define API_DOMAIN       SERVER_API_DOMAIN?:INIT_DOMAIN
//#define IMAGE_DOMAIN     SERVER_IMAGE_DOMAIN?:INIT_DOMAIN
//#define UPLOAG_DOMAIN    SERVER_UPLOAD_DOMAIN?:INIT_DOMAIN
//#define TUBE_DOMAIN      SERVER_TUBE_DOMAIN?:@"119.29.44.245:9237"
//#define SPREAD_DOMAIN    SERVER_SPREAD_DOMAIN?:@"119.29.44.245:9236"


// 内网9969  闫涛 9962   周阳 9961  王萌萌 9960  李壮壮 9964  王帅兵 9965
//-------后端人员开发环境------
#define API_DEV_PORT     9969   //和开发人员调试的时候直接修改这个端口号
#define INIT_DOMAIN      CUSTOM_API_DOMAIN?:[NSString stringWithFormat:@"dev.happyin.com.cn:%d",API_DEV_PORT]
#define API_DOMAIN       CUSTOM_API_DOMAIN?:INIT_DOMAIN
#define IMAGE_DOMAIN     SERVER_IMAGE_DOMAIN?:@"hipubdev-10006628.file.myqcloud.com"
#define UPLOAG_DOMAIN    CUSTOM_API_DOMAIN?:INIT_DOMAIN
#define TUBE_DOMAIN      SERVER_TUBE_DOMAIN?:@"push.happyin.com.cn:7237"
#define SPREAD_DOMAIN    SERVER_SPREAD_DOMAIN?:@"push.happyin.com.cn:7239"

//-------生成完整URL------
#define APIVersion          @"100"
#define HappyInHostSuffix   @"happyin.com.cn"

#define MC_URL_HOST(HOST)         ([(HOST) hasPrefix:@"http"]?(HOST):[@"http://" stringByAppendingString:(HOST)])
#define BASE_URL_INIT             [NSString stringWithFormat:@"%@/", MC_URL_HOST(CUSTOM_API_DOMAIN?:INIT_DOMAIN)]
#define BASE_URL_API              [NSString stringWithFormat:@"%@/", MC_URL_HOST(API_DOMAIN)]
#define BASE_URL_IMAGE            [NSString stringWithFormat:@"%@/", MC_URL_HOST(IMAGE_DOMAIN)]
#define BASE_URL_UPLOAD           [NSString stringWithFormat:@"%@/", MC_URL_HOST(UPLOAG_DOMAIN)]

FOUNDATION_EXPORT NSString *InitUrl(NSString *relativeUrl);
FOUNDATION_EXPORT NSString *GeneralUrl(NSString *relativeUrl);
FOUNDATION_EXPORT NSString *ImageUrl(NSString *relativeUrl);
FOUNDATION_EXPORT NSString *UploadUrl(NSString *relativeUrl);

//-------------App--------------------------
#define url_system_domain                   InitUrl(@"Catalog/System/GetDomainInfo")                    //获取域名信息
#define url_submit_active                   GeneralUrl(@"Catalog/Advert/active")                        //激活

//注册登录
#define url_verify_captcha                  GeneralUrl(@"Catalog/User/verifyCaptcha")                   //验证短信验证码
#define url_login                           GeneralUrl(@"Catalog/User/register")                        //登陆


+ (void)updateSystemDomain:(void (^)(void))complete
{
    [NetManager getCacheToUrl:url_system_domain params:nil complete:^(BOOL successed, HttpResponse *response) {
        
        if (successed && !response.is_cache) {
            NSDictionary *result = response.payload;
            
            //API接口
            NSString *apiDomain = result[@"init_domain"];
            if (apiDomain && apiDomain.length) {
                [userDefaults setObject:apiDomain forKey:UserDefaultKey_ApiDomain];
            }
            
            //上传文件
            NSString *uploadIp = result[@"upload_domain"];
            if (uploadIp && uploadIp.length) {
                [userDefaults setObject:uploadIp forKey:UserDefaultKey_UploadDomain];
            }
            
            //下载文件
            NSString *downloadIp = result[@"download_domain"];
            if (downloadIp && downloadIp.length) {
                [userDefaults setObject:downloadIp forKey:UserDefaultKey_DownloadDomain];
            }
            
            //上传日志文件
            NSString *logIp = result[@"log_service"];
            if (logIp && logIp.length) {
                [userDefaults setObject:logIp forKey:UserDefaultKey_LogDomain];
            }
            
            //设置日志级别
            if (result[@"log_level"]) {
                [USLogger setLogLevel:[result[@"log_level"] intValue]];
            }
            
            //Spread推送
            NSArray *spread_service =  result[@"spread_service"];
            if (spread_service && [spread_service isKindOfClass:[NSArray class]] && spread_service.count) {
                [userDefaults setObject:[spread_service componentsJoinedByString:@","] forKey:UserDefaultKey_SpreadDomain];
            }
            
            //Tube消息
            NSArray *tube_service =  result[@"tube_service"];
            if (tube_service && [tube_service isKindOfClass:[NSArray class]] && tube_service.count) {
                [userDefaults setObject:[tube_service componentsJoinedByString:@","] forKey:UserDefaultKey_TubeDomain];
            }
            
            //系统配置
            if (result[@"flags"]) {
                [userDefaults setObject:result[@"flags"] forKey:UserDefaultKey_ConfigFlags];
            }
            
        }
        
        complete?complete():nil;
    }];

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    FLOG(@"AppDelegate ------> ApplicationWillEnterForeground");
    
    _applicationContext.hasSwitchToOtherApp = NO;
    
    [HLTool updateSystemDomain:^{
        
        //后台刷新模式下不去进行socket连接和首页刷新
        if (_applicationContext.fetchingInBackground) {
            return;
        }
        
        if ([HLTool globalConfig]) {
            [[SpreadManager defaultManager] connect];
        }
        
        _applicationContext.configLoaded = YES;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ConfigLoadSuccess object:nil];
    }];
}

get responseObject:  {
    c = 200;
    h = "";
    m = "";
    n = "";
    p =     {
        download_domain = "https://devel-10041765.file.myqcloud.com";
        flags = "1";
        init_domain = "http://dev.happyin.com.cn";
        log_level = "4";
        spread_service =         (
            "push.happyin.com.cn:7239"
        );
        upload_domain = "http://dev.happyin.com.cn";
    };
    ts = 1539856223000;
}
}
```

在之前的 app 中,  SERVER_API_DOMAIN, SERVER_SPREAD_DOMAIN 都是通过偏好设置读取出来的. 在 APP 启动的时候, 会通过 url_system_domain 读取各个 domain 的值, 然后存储到偏好设置当中. 在之后的发送网络请求的时候, 会去偏好设置里面读取各个 domain 的值, 然后生成完整的连接. 也就是说, 在之前的 app 里面, 各个domain 的值是可以通过 url_system_domain 进行修改的.

CUSTOM_API_DOMAIN 的用处在于, 可以在调试环境下进行一次域名的变化. 在 App 中, 写了一个配置 ViewController, 在里面可以填写域名的配置, 而配置好的值, 就存到了 CUSTOM_API_DOMAIN. 如果有 CUSTOM_API_DOMAIN, 通过上面的宏我们知道, 在拼接完整的 url 的时候, 就会以CUSTOM_API_DOMAIN 的值作为域名.

IMAGE_DOMAIN, UPLOAG_DOMAIN, TUBE_DOMAIN, SPREAD_DOMAIN 都是之前的技术, 现在就 INITDomain, 和 APIDomain 起作用.

在现在萌股之后的代码里面, 策略发生了改变.

#define DOMAIN_RELEASE   @"https://app.moego.net"
#define DOMAIN_TEST      @"http://t.app.moego.net"
#define INIT_DOMAIN      CUSTOM_API_DOMAIN ?: ENV_RELEASE ? DOMAIN_RELEASE : DOMAIN_TEST
#define API_DOMAIN       SERVER_API_DOMAIN?:INIT_DOMAIN

域名的信息写死到了代码里面, 没有url_system_domain获取各个 Domain 域名的过程了, 虽然上面的代码结构保留了, 但是通过取偏好设置拼接完整 url 的过程, 现在不会再发生了. 现在的域名是直接通过宏拼接出来的.

## NotificationName 和 UserDefaultKey

这些作为一种全局名称, 统一定义在这里面, 这两个文件包含在 PCH 中, 现在的问题是, 只要新增一个名称, 因为是 PCH 的变化, 就要大量时间的重新编译. 而这两个文件是经常会改动的. 事实上, 应该在用到的地方包含头文件, 不应该放到 pch 文件中.

## MacroTool