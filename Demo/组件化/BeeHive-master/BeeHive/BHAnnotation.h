/**
 * Created by BeeHive.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the GNU GENERAL PUBLIC LICENSE.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */


#import <Foundation/Foundation.h>
#import "BeeHive.h"

#ifndef BeehiveModSectName

#define BeehiveModSectName "BeehiveMods"

#endif

#ifndef BeehiveServiceSectName

#define BeehiveServiceSectName "BeehiveServices"

#endif


#define BeeHiveDATA(sectname) __attribute((used, section("__DATA,"#sectname" ")))


#define BeeHiveMod(name) \
class BeeHive; char * k##name##_mod BeeHiveDATA(BeehiveMods) = ""#name"";

#define BeeHiveService(servicename,impl) \
class BeeHive; char * k##servicename##_service BeeHiveDATA(BeehiveServices) = "{ \""#servicename"\" : \""#impl"\"}";

/*
 @BeeHiveMod(ShopModule)
 
 变为
 class BeeHive;
 char * kShopModule_mod BeeHiveDATA(BeehiveMods) = "ShopModule";
 
 变为
 class BeeHive;
 char * kShopModule_mod __attribute((used, section("__DATA,"BeehiveMods" "))) = "ShopModule";
 
 @BeeHiveMod(ShopModule) 会注册到 .O 文件中的一个名为 "BeehiveMods"特定的区域里面, value 是 Module 的类名
 
 @BeeHiveService(HomeServiceProtocol,BHViewController) 会注册到 .O 文件中的一个名为 "BeehiveServices"特定的区域里面特定的区域, value 是 key:value pair, key 为 Protocol 名, value 为实现的 protocol 的类名.
 
 然后在项目启动的时候
 去 .o 文件, 读取 BeehiveMods section 区域的各个符号, 就知道有哪些 module 需要注册了. 最终还是调用 [[BHModuleManager sharedManager] registerDynamicModule:cls] 进行注册.
 去 .o 文件, 读取 BeehiveServices section 区域的各个符号, 就知道有哪些 Protocl 和 Protocl 实现 需要注册了. 最终还是调用 [[BHServiceManager sharedManager] registerService:NSProtocolFromString(protocol) implClass:NSClassFromString(clsName)] 进行注册.
 */

@interface BHAnnotation : NSObject

@end
