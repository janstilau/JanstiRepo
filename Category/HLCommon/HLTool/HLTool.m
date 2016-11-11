//
//  HLTool.m
//  HLMagic
//
//  Created by FredHoolai on 3/5/14.
//  Copyright (c) 2014 chen ying. All rights reserved.
//

#import "HLTool.h"
#import "JPEngine.h"
#import "JPCleaner.h"
#import "AppDelegate.h"
#import <Photos/Photos.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "Hospital.h"
#import "NoticeManager.h"
#import "USOrderListViewController.h"
#import "USMessageDetailViewController.h"
#import <Contacts/Contacts.h>
#import <AddressBook/AddressBook.h>

@implementation NSString (ImageURL)

- (NSString *)fullImageURL
{
    if (!self.length) return self;
    
    if([self hasPrefix:@"http"]){
        return self;
    }
    return ImageUrl(self);
}

- (NSString *)fullMiniImageURL
{
    return [self fullThumbImageURLWithMinPixel:50];
}

- (NSString *)fullSmallImageURL
{
    return [self fullThumbImageURLWithMinPixel:200];
}

- (NSString *)fullThumbImageURLWithMinPixel:(NSInteger)minPixel
{
    if (!self.length) return self;
    
    NSString *fullUrl = [self fullImageURL];
    
    NSString *lastComponent = [NSString stringWithFormat:@"_%@x.jpg", @(minPixel)];
    
    return [fullUrl stringByReplacingOccurrencesOfString:@".jpg" withString:lastComponent];
}

- (NSString *)fullThumbImageURLWithSize:(CGSize)size
{
    if (!self.length) return self;
    
    NSString *fullUrl = [self fullImageURL];
    
    NSString *lastComponent = [NSString stringWithFormat:@"_%dx%d.jpg", (int)size.width, (int)size.height];
    
    return [fullUrl stringByReplacingOccurrencesOfString:@".jpg" withString:lastComponent];
}

@end

@implementation HLTool

+ (NSInteger)globalConfig
{
    NSNumber *flag = [userDefaults objectForKey:UserDefaultKey_ConfigFlags];
    if (flag) {
        return [flag integerValue];
    }
    return 0; //默认都不显示
}

// 保存照片到相册
+ (void)writeImageToHTAlbum:(UIImage *)image
{
    if(NSClassFromString(@"PHPhotoLibrary")){
        [PHPhotoLibrary writeImage:image toAlbum:HTAlbumName completionHandler:^(PHAsset *asset, NSError *error) {
            if (error) {
                [USSuspensionView showWithMessage:@"保存失败"];
            } else {
                [USSuspensionView showWithMessage:@"已保存到相册"];
            }
        }];
        
        return;
    }
    
    [ALAssetsLibrary writeImage:image toAlbum:HTAlbumName completionHandler:^(ALAsset *asset, NSError *error) {
        if (error) {
            [USSuspensionView showWithMessage:@"保存失败"];
        } else {
            [USSuspensionView showWithMessage:@"已保存到相册"];
        }
    }];
}

// 通用的通过远程数据推送进行页面跳转，如：推送通知、banner、广告位
+ (void)remotePushViewWithPayload:(NSDictionary *)payload
{
    int type = [payload[@"type"] intValue];
    switch (type) {
        case 1:{  //H5页面： {"type":1, "url":"http://www.baidu.com", "title":"happyin"}
            USSafariViewController *safarVC = [USSafariViewController initWithTitle:payload[@"title"] url:payload[@"url"]];
            [_applicationContext.navigationController pushViewController:safarVC animated:YES];
            
            break;
        }
        case 2:{  //订单列表页： {"type":2}
            USOrderListViewController *orderVC = [USOrderListViewController viewController];
            [_applicationContext.navigationController pushViewController:orderVC animated:YES];
            
            break;
        }
        case 3:{  //不再支持修改联系方式
            break;
        }
        case 4:{  //消息详情页： {"type":4, @"msg_id":@"1"}
            USMessageDetailViewController *messageVC = [USMessageDetailViewController viewController];
            messageVC.messageId = payload[@"msg_id"];
            [_applicationContext.navigationController pushViewController:messageVC animated:YES];
            
            break;
        }
    }
}

+ (BOOL)cameraGranted
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted ||
        authStatus == AVAuthorizationStatusDenied)
    {
        if (&UIApplicationOpenSettingsURLString) {
            USAlertView *alert = [USAlertView initWithTitle:@"您的相机访问权限被禁止" message:@"请在设置-胡桃钱包-相机权限中开启" cancelButtonTitle:@"取消" otherButtonTitles:@"去开启", nil];
            [alert showWithCompletionBlock:^(NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }
            }];
        } else {
            [USAlertView showWithMessage:@"请在设备的\"设置-隐私-相机\"中允许访问相机。"];
        }
        
        return NO;
    } else {
        return YES;
    }
}

+ (BOOL)contactsGranted{
    
    BOOL hasGetAuth = NO;
    
    void (^failAlertBlock)() = ^(){
        
        if (&UIApplicationOpenSettingsURLString) {
            USAlertView *alert = [USAlertView initWithTitle:@"您的相机访问权限被禁止" message:@"请在设置-胡桃钱包-通信录权限中开启" cancelButtonTitle:@"取消" otherButtonTitles:@"去开启", nil];
            [alert showWithCompletionBlock:^(NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }
            }];
        }
        else {
            [USAlertView showWithMessage:@"请在设备的\"设置-隐私-通信录\"中允许访问通信录。"];
        }
    };
    
    
    if (NSClassFromString(@"CNContact") && SystemVersionGreaterThanOrEqualTo(@"9.0")) {
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        if (status == CNAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
        else {
            failAlertBlock();
        }
    }
    else {
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
        else {
            failAlertBlock();
        }
    }
    
    return hasGetAuth;
}

//是否开启相册权限
+ (BOOL)photoAlbumGranted
{
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    if (author == kCLAuthorizationStatusRestricted || author == kCLAuthorizationStatusDenied) {
        //无权限
        if (&UIApplicationOpenSettingsURLString) {
            USAlertView *alert = [USAlertView initWithTitle:@"您的照片访问权限被禁止" message:@"请在设置-胡桃钱包-照片权限中开启" cancelButtonTitle:@"取消" otherButtonTitles:@"去开启", nil];
            [alert showWithCompletionBlock:^(NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }
            }];
        } else {
            [USAlertView showWithMessage:@"请在设备的\"设置-隐私-照片\"中允许访问相册。"];
        }
        
        return NO;
    } else {
        return YES;
    }
}

//迁移老数据
+ (void)migrateOldVersionData
{
    
}

+ (void)updateSystemDomain:(void (^)(void))complete
{
    [NetManager getCacheToUrl:url_system_domain params:nil complete:^(BOOL successed, HttpResponse *response) {
        
        if (successed && !response.is_cache) {
            NSDictionary *result = response.payload[@"domain"];
            
            //API接口
            NSString *apiDomain = result[@"initDomain"];
            if (apiDomain && apiDomain.length) {
                [userDefaults setObject:apiDomain forKey:UserDefaultKey_ApiDomain];
            }
            
            //上传文件
            NSString *uploadIp = result[@"uploadDomain"];
            if (uploadIp && uploadIp.length) {
                [userDefaults setObject:uploadIp forKey:UserDefaultKey_UploadDomain];
            }
            
            //下载文件
            NSString *downloadIp = result[@"downloadDomain"];
            if (downloadIp && downloadIp.length) {
                [userDefaults setObject:downloadIp forKey:UserDefaultKey_DownloadDomain];
            }
            
            //设置日志级别
            if (result[@"logLevel"]) {
                [USLogger setLogLevel:[result[@"logLevel"] intValue]];
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
            
            //JS补丁
            if (result[@"js_patch"]) {
                //清除本地已经下载的Patch文件
                NSString *filePath = [NSData diskCachePathWithURL:result[@"js_patch"]];
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                
                [NSData dataWithURL:result[@"js_patch"] completed:^(NSData *data) {
                    if(data) {
                        NSString *script = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        [userDefaults setObject:script forKey:UserDefaultKey_JSPatchScript];
                        [userDefaults synchronize];
                        
                        [JPEngine evaluateScript:script];
                    }
                }];
            }
            else {
                [JPCleaner cleanAll];
                [userDefaults removeObjectForKey:UserDefaultKey_JSPatchScript];
            }
            
            [[NoticeManager defaultManager] handleSystemInfo:response.payload];
            
            [userDefaults synchronize];
            
//            //JSPatch补丁测试代码
//            NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"patch" ofType:@"js"];
//            NSString *script = [NSString stringWithContentsOfFile:sourcePath encoding:NSUTF8StringEncoding error:nil];
//            [JPEngine evaluateScript:script];
            
//            [self submitAppActive]; //自动注册所以不需要激活接口了
        }
        
        [self requestUpdateHosptitalData];
        
        complete?complete():nil;
    }];
}

+ (void)requestUpdateHosptitalData
{
    NSString *hversion = [userDefaults objectForKey:USHospitalDataVersion]?:@"8";
    NSString *iversion = [userDefaults objectForKey:USInstallmentDataVersion]?:@"8";
    
    NSDictionary *params = @{@"hospital_ts":hversion, @"installment_ts":iversion};
    [NetManager getCacheToUrl:url_hospital_data params:params complete:^(BOOL successed, HttpResponse *response) {
        if (successed) {
            [Hospital importDataWithPayload:response.payload];
        }
    }];
}

//提交激活状态到服务器端
+ (void)submitAppActive
{
    if (![userDefaults objectForKey:UserDefaultKey_submittedActive]) {
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *name = [[[UIDevice currentDevice] name] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setValue:appVersion forKey:@"app_version"];
        
        NSDictionary *wifiInfo = [UIDevice wifiInfo];
        if (wifiInfo) {
            [params setValue:wifiInfo[@"SSID"] forKey:@"ssid"];
            [params setValue:wifiInfo[@"BSSID"] forKey:@"bssid"];
        }
        
        [params setValue:[UIDevice idfv] forKey:@"idfv"];
        [params setValue:[UIDevice idfa] forKey:@"idfa"];
        
        [params setValue:name forKey:@"name"];
        [params setValue:[UIDevice deviceModel] forKey:@"model"];
        [params setValue:[UIDevice deviceName] forKey:@"product"];
        [params setValue:@([UIDevice jailbroken]) forKey:@"jailbroken"];
        [params setValue:[[UIDevice currentDevice] systemVersion] forKey:@"os_version"];
        
        [NetManager getCacheToUrl:url_submit_active params:params complete:^(BOOL successed, HttpResponse *response) {
            if (successed) {
                [userDefaults setObject:@YES forKey:UserDefaultKey_submittedActive];
                [userDefaults synchronize];
            }
        }];
    }
}

//检测内存状态，如果是内存占用过多则关闭应用
+ (void)detectionMemoryPressureLevel
{
    BOOL levelWarning = [UIDevice usedMemoryInBytes] > 200.0*1024*1024;
    
    WLOG(@"device availableMemory: %@",[UIDevice freeMemory]);
    WLOG(@"application usedMemory: %@",[UIDevice usedMemory]);
    
    UIApplication *application = [UIApplication sharedApplication];
    if (levelWarning && application.applicationState == UIApplicationStateBackground && !_applicationContext.hasSwitchToOtherApp) {
        [(AppDelegate *)application.delegate applicationWillTerminate:application];
        
        WLOG(@"HTWallet应用即将退出！！！！");
        exit(0);
    }
}

//返回客服电话
+ (NSArray *)servicePhoneNumbers
{
    NSArray *serviceNumbers = [userDefaults objectForKey:UserDefaultKey_ServicePhoneNumbers];
    
    if (serviceNumbers && [serviceNumbers isKindOfClass:[NSArray class]] && serviceNumbers.count) {
        return serviceNumbers;
    }
    
    return @[@"400-777-9755"];
}

+ (void)popupServicePhonesSheet
{
    NSArray *serviceArray = [self servicePhoneNumbers];
    if (serviceArray.count == 1) {
        NSString *phoneNumber = [serviceArray firstObject];
        NSString *phoneText = [NSString stringWithFormat:@"拨打%@",phoneNumber];
        USActionSheet * bottomSheet = [USActionSheet initWithTitle:nil cancelButtonTitle:@"取消" destructiveButtonTitle:phoneText otherButtonTitles:@"复制号码", nil];
        [bottomSheet showWithCompletionBlock:^(NSInteger buttonIndex) {
            if (buttonIndex == 1) {
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@",phoneNumber]];
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url];
                };
            }
            else if (buttonIndex == 2) {
                [[UIPasteboard generalPasteboard] setString:phoneNumber];
                [USSuspensionView showWithMessage:@"已复制到剪切板"];
            }
        }];
    }
    else {
        NSMutableArray *resultTextArray = [NSMutableArray array];
        [serviceArray enumerateObjectsUsingBlock:^(NSString*  serviceNumber, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *UIText = [NSString stringWithFormat:@"拨打 %@",serviceNumber];
            [resultTextArray addObject:UIText];
        }];
        
        USActionSheet * bottomSheet = [USActionSheet initWithTitle:nil cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitleArray:resultTextArray];
        [bottomSheet showWithCompletionBlock:^(NSInteger buttonIndex) {
            if (!buttonIndex) return;
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@",serviceArray[buttonIndex-1]]];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
    }
}

@end
