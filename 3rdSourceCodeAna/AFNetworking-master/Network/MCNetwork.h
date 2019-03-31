//
//  MCNetwork.h
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "MCNetSupporting.h"
#import "Reachability.h"

#define NetWork            [MCNetwork defaultManager]
#define NetWorkJWTEnabled  ([[MCNetwork defaultManager] encryptEnable])

@interface HTTPResponse : NSObject

@property (nonatomic, strong) NSDictionary *dataDict;      //!< 返回的data数据, 即 response.payload[@"data"];
@property (nonatomic, assign) BOOL         isCache;        //!< 是否是缓存链接
@property (nonatomic, strong) NSURL        *requestURL;    //!< 请求URL
@property (nonatomic, strong) NSDictionary *requestParams; //!< 请求参数
@property (nonatomic, strong) id           payload;        //!< 响应体（已解密）
@property (nonatomic, strong) NSString     *msg;
@property (nonatomic, strong) NSError      *error;
@property (nonatomic, strong) NSDate       *date;
@property (nonatomic, assign) NSInteger errorCode;

@end

// ------

typedef void (^HTTPTaskRequestHandler)(NSMutableURLRequest *request);
typedef void (^HTTPTaskProgressHandler)(int64_t completedUnitCount, int64_t totalUnitCount);
typedef void (^HTTPTaskCompleteHandler)(BOOL successed, HTTPResponse *response);

@interface MCNetwork : NSObject

@property(nonatomic, strong, readonly) AFHTTPSessionManager *sessionManager;
@property (nonatomic, assign, readonly) BOOL encryptEnable;

+ (instancetype)defaultManager;

- (NetworkStatus)networkStatus;

- (void)addNetStatusChangeCallback:(void(^)(NetworkStatus status))callback;

- (NSURLSessionDataTask *)getRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (NSURLSessionDataTask *)putRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (NSURLSessionDataTask *)deleteRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (NSURLSessionDataTask *)getCacheToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (void)localCacheToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete;

- (void)downloadWithUrl:(NSString *)url
               progress:(void(^)(CGFloat progress))progress
             completion:(void (^)(NSURL *savedPath, NSError *error))completion ;

@end

// ------

@interface UGJSONResponseSerializer : AFJSONResponseSerializer

@end

// const string

UIKIT_EXTERN NSString *const MCNetworkMessageNotReachable; // 网络未连接
UIKIT_EXTERN NSString *const MCNetworkMessageTimedOut;     // 超时
