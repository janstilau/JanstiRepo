/**
 * Created by BeeHive.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the GNU GENERAL PUBLIC LICENSE.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import "BHServiceProtocol.h"
#import "BHConfig.h"
#import "BHAppDelegate.h"

typedef enum
{
    BHEnvironmentDev = 0,
    BHEnvironmentTest,
    BHEnvironmentStage,
    BHEnvironmentProd
}BHEnvironmentType;

// 这个类, 其实就是一个单例数据类. 为各个模块提供共享配置数据的.
@interface BHContext : NSObject <NSCopying>

// 记录了当前的环境
@property(nonatomic, assign) BHEnvironmentType env;

// 记录了当前的用户配置, 里面是一个 NSDictionary, 所以可以自由扩展.
@property(nonatomic, strong) BHConfig *config;

//application appkey
@property(nonatomic, strong) NSString *appkey;
//customEvent>=1000
@property(nonatomic, assign) NSInteger customEvent;

// 记录 Application 类
@property(nonatomic, strong) UIApplication *application;
// 记录 启动的参数.
@property(nonatomic, strong) NSDictionary *launchOptions;
// 记录从哪个配置文件, 来获取 module 的信息
@property(nonatomic, strong) NSString *moduleConfigName;
// 记录从哪个配置文件, 来获取 service 的信息.
@property(nonatomic, strong) NSString *serviceConfigName;

//3D-Touch model
#if __IPHONE_OS_VERSION_MAX_ALLOWED > 80400
@property (nonatomic, strong) BHShortcutItem *touchShortcutItem;
#endif

//OpenURL model
@property (nonatomic, strong) BHOpenURLItem *openURLItem;

//Notifications Remote or Local
@property (nonatomic, strong) BHNotificationsItem *notificationsItem;

//user Activity Model
@property (nonatomic, strong) BHUserActivityItem *userActivityItem;

//watch Model
@property (nonatomic, strong) BHWatchItem *watchItem;

//custom param
@property (nonatomic, copy) NSDictionary *customParam;

+ (instancetype)shareInstance;

- (void)addServiceWithImplInstance:(id)implInstance serviceName:(NSString *)serviceName;

- (void)removeServiceWithServiceName:(NSString *)serviceName;

- (id)getServiceInstanceFromServiceName:(NSString *)serviceName;

@end
