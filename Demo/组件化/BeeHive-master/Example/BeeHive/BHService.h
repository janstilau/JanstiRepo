//
//  BHService.h
//  Pods
//
//  Created by 一渡 on 7/16/15.
//
//
#import "BeeHive.h"

// 需要有一个头文件, 在这个头文件内部, 将所有的业务方所需要的 Protocol 进行统一管理.
// 从这个意义上来说, 这个库是按照 Protocol 进行的模块之间的解耦.
#import "HomeServiceProtocol.h"
#import "TradeServiceProtocol.h"
#import "UserTrackServiceProtocol.h"
#import "AppUISkeletonServiceProtocol.h"
#import "AppConfigServiceProtocol.h"
