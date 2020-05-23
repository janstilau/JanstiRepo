//
//  AFURLSessionManagerTaskDelegate.h
//  AFNetworking iOS
//
//  Created by JustinLau on 2020/5/23.
//  Copyright © 2020 AFNetworking. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFURLSessionManager.h"


extern NSString * const AFNetworkingTaskDidResumeNotification;
extern NSString * const AFNetworkingTaskDidCompleteNotification ;
extern NSString * const AFNetworkingTaskDidSuspendNotification;
extern NSString * const AFURLSessionDidInvalidateNotification;
extern NSString * const AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification;
extern NSString * const AFURLSessionDownloadTaskDidFailToMoveFileNotification;
extern NSString * const AFNetworkingTaskDidCompleteSerializedResponseKey;
extern NSString * const AFNetworkingTaskDidCompleteResponseSerializerKey;
extern NSString * const AFNetworkingTaskDidCompleteResponseDataKey;
extern NSString * const AFNetworkingTaskDidCompleteErrorKey;
extern NSString * const AFNetworkingTaskDidCompleteAssetPathKey;
extern NSString * const AFNetworkingTaskDidCompleteSessionTaskMetrics;

extern NSString * const AFURLSessionManagerLockName;
extern const void * const AuthenticationChallengeErrorKey;


typedef void (^AFURLSessionDidBecomeInvalidBlock)(NSURLSession *session, NSError *error);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);

typedef NSURLRequest * (^AFURLSessionTaskWillPerformHTTPRedirectionBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);
typedef id (^AFURLSessionTaskAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential));
typedef void (^AFURLSessionDidFinishEventsForBackgroundURLSessionBlock)(NSURLSession *session);

typedef NSInputStream * (^AFURLSessionTaskNeedNewBodyStreamBlock)(NSURLSession *session, NSURLSessionTask *task);
typedef void (^AFURLSessionTaskDidSendBodyDataBlock)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^AFURLSessionTaskDidCompleteBlock)(NSURLSession *session, NSURLSessionTask *task, NSError *error);
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
typedef void (^AFURLSessionTaskDidFinishCollectingMetricsBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics * metrics) AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif

typedef NSURLSessionResponseDisposition (^AFURLSessionDataTaskDidReceiveResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response);
typedef void (^AFURLSessionDataTaskDidBecomeDownloadTaskBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLSessionDownloadTask *downloadTask);
typedef void (^AFURLSessionDataTaskDidReceiveDataBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);
typedef NSCachedURLResponse * (^AFURLSessionDataTaskWillCacheResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse);

typedef NSURL * (^AFURLSessionDownloadTaskDidFinishDownloadingBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location);
typedef void (^AFURLSessionDownloadTaskDidWriteDataBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^AFURLSessionDownloadTaskDidResumeBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress *);

typedef void (^AFURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

NS_ASSUME_NONNULL_BEGIN
/*
 将, 网络的交互, 封装到一个类中. 一个网络交互, 代表着一个 AFURLSessionManagerTaskDelegate 对象.
 AFURLSessionManager 作为网络交互的总的控制器, 将各个网络请求, 和 AFURLSessionManagerTaskDelegate 对象进行映射, 然后管理着网络请求的生命周期, 也就是 AFURLSessionManagerTaskDelegate 的生命周期.
 当接收到网络请求的代理回调的时候, 将回调的数据, 传递到各个 AFURLSessionManagerTaskDelegate 对象中.
 这里, Block 作为可以传递的数据, 非常方便进行业务流转的处理工作.
 */
@interface AFURLSessionManagerTaskDelegate : NSObject <NSURLSessionTaskDelegate,
    NSURLSessionDataDelegate,
    NSURLSessionDownloadDelegate>

- (instancetype)initWithTask:(NSURLSessionTask *)task;

@property (nonatomic, weak) AFURLSessionManager *manager;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSProgress *uploadProgress;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, copy) NSURL *downloadFileURL;
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
@property (nonatomic, strong) NSURLSessionTaskMetrics *sessionTaskMetrics AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif

@property (nonatomic, copy) AFURLSessionDownloadTaskDidFinishDownloadingBlock downloadTaskDidFinishDownloading;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock uploadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock downloadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskCompletionHandler completionHandler;

@end

NS_ASSUME_NONNULL_END
