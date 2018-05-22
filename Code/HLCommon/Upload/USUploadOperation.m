//
//  USUploadOperation.m
//  HTWallet
//
//  Created by marujun on 16/7/29.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import "USUploadOperation.h"


#define MaxRetryCount 3

@interface USUploadItem ()

@property (nonatomic, copy) NSString *ID;                       //ID
@property (nonatomic, strong) NSDictionary *clound_auth;        //腾讯云认证信息

@property (nonatomic, assign) NSInteger sign_retry_count;       //获取签名失败重试次数
@property (nonatomic, assign) NSInteger upload_retry_count;     //上传失败重试次数

@end

@implementation USUploadItem

@end


@interface USUploadOperation ()

@property (nonatomic, assign) BOOL isUploading;

@property (nonatomic, strong) NSArray<USUploadItem *> *allItems;

@property (nonatomic, strong) NSMutableArray<USUploadItem *> *uploadingItems;

@property (nonatomic, copy) USUploadCompleteHandler completeHandler;

@end

@implementation USUploadOperation

+ (instancetype)startWithImageOrFilePathArray:(NSArray<id> *)sourceArray completeHandler:(USUploadCompleteHandler)completeHandler;
{
    NSError *error = nil;
    
    NSMutableArray *tmpArray = [NSMutableArray array];
    for (id obj in sourceArray) {
        USUploadItem *item = [[USUploadItem alloc] init];
        if ([obj isKindOfClass:[NSData class]]) {
            item.file_data = obj;
        }
        else if ([obj isKindOfClass:[NSString class]]) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:obj]) {
                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"文件路径不存在"}];
                break;
            } else {
                item.file_path = obj;
            }
        }
        else if ([obj isKindOfClass:[UIImage class]]) {
            item.image = obj;
        }
        else {
            error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"提供的数据源不能为空"}];
            break;
        }
        [tmpArray addObject:item];
    }
    
    if (error) {
        if (completeHandler) completeHandler(nil, error);
        return nil;
    }
    
    USUploadOperation *operation = [[self alloc] init];
    operation.uploadingItems = tmpArray;
    operation.allItems = [NSArray arrayWithArray:tmpArray];
    operation.completeHandler = completeHandler;
    
    [operation start];
    
    return operation;
}

- (void)start
{
    if (_isUploading) return;
    
    if (!_uploadingItems.count) {
        
        if (_completeHandler)  _completeHandler(_allItems,nil);
        
        return;
    }
    
    USUploadItem *uplodingItem = [_uploadingItems firstObject];
    
    if (!uplodingItem.clound_auth) {
        [self requestPictureSign:[_uploadingItems firstObject]];
        
        return;
    }
    
    [self requestPictureUpload:uplodingItem];
}


/**
 *  获取腾讯云口令
 */
- (void)requestPictureSign:(USUploadItem *)item
{
    _isUploading = YES;
    
    _sessionTask = [NetManager getRequestToUrl:url_picture_sign params:@{} complete:^(BOOL successed, HttpResponse *response) {
        _isUploading = NO;
        _sessionTask = nil;
        
        if(successed){
            //处理获取结果
            item.clound_auth = response.payload;
            
            [self start];
        }
        else {
            item.sign_retry_count += 1;
            
            if (item.sign_retry_count >= MaxRetryCount) {
                if (_completeHandler)  _completeHandler(nil, [NSError errorWithDomain:NSURLErrorDomain
                                                                                       code:NSURLErrorResourceUnavailable
                                                                                   userInfo:@{NSLocalizedDescriptionKey:@"获取签名失败"}]);
            }
            else {
                //重新尝试
                [self requestPictureSign:item];
                
                WLOG(@"获取签名失败！即将进行第%zd次重试", item.sign_retry_count);
            }
        }
    }];
}

- (void)requestPictureUpload:(USUploadItem *)item
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer = [DMJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = nil;
    
    NSData *filedata = item.file_data;
    
    if (!filedata) {
        UIImage *item_image = item.image;
        if (!item_image) {
            item_image = [UIImage imageWithContentsOfFile:item.file_path];
        }
        
        NSData *filedata = UIImageJPEGRepresentation(item_image, 0.8);
        
        //腾讯云限制单次请求20M，超出的需要做分片上传
        float lengthLimit = 20.f*1024*1024;
        
        if (filedata.length > lengthLimit) {
            //图片压缩到20M以下
            for (float i=0.78; i>0.5; i-=0.02) {
                @autoreleasepool {
                    filedata = UIImageJPEGRepresentation(item_image, i);
                }
                
                if (filedata.length < lengthLimit) break;
            }
        }
        DLOG(@"压缩后图片大小： %@",[NSByteCountFormatter stringFromByteCount:filedata.length countStyle:NSByteCountFormatterCountStyleBinary]);
    }
    
    void (^formBlock)(id <AFMultipartFormData> formData) = ^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:filedata name:@"filecontent" fileName:@"upload.jpg" mimeType:@"image/jpeg"];
    };
    
    //直传到腾讯云
    NSMutableURLRequest *request = [serializer multipartFormRequestWithMethod:@"POST"
                                                                    URLString:item.clound_auth[@"cosPath"]
                                                                   parameters:@{@"op":@"upload"}
                                                    constructingBodyWithBlock:formBlock
                                                                        error:nil];
    [request setValue:item.clound_auth[@"sign"] forHTTPHeaderField:@"Authorization"];
    
    DLOG(@"post request url:  %@",request.URL.absoluteString);
    
    void (^progressHandler)(NSProgress *) = ^(NSProgress * _Nonnull uploadProgress) {
        // This is not called back on the main queue.
        // You are responsible for dispatching to the main queue for UI updates
        if (uploadProgress.totalUnitCount > 0) {  //异常现象：iOS7的uploadTask.countOfBytesExpectedToSend 为0
            float progress = uploadProgress.completedUnitCount*1.f / uploadProgress.totalUnitCount;
            DLOG(@"upload process: %.0f%% (%@/%@)",100*progress,@(uploadProgress.completedUnitCount),@(uploadProgress.totalUnitCount));
        }
    };
    
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        _isUploading = NO;
        _sessionTask = nil;
        
        if (!error) {
            DLOG(@"post responseObject:  %@",responseObject);
            
            item.clound_url = [responseObject[@"data"][@"resource_path"] substringFromIndex:1];
            
            [_uploadingItems removeObject:item];
            
            [self start];
        }
        else {
            ELOG(@"post request url:  %@", request.URL.absoluteString);
            ELOG(@"post responseObject:  %@", responseObject);
            ELOG(@"post error :  %@", error.localizedDescription);
            
            item.upload_retry_count += 1;
            
            //上传失败后重试的次数
            if (item.upload_retry_count >= MaxRetryCount) {
                
                if (_completeHandler)  _completeHandler(nil, [NSError errorWithDomain:NSURLErrorDomain
                                                                                       code:NSURLErrorResourceUnavailable
                                                                                   userInfo:@{NSLocalizedDescriptionKey:@"上传腾讯云失败"}]);
            }
            else {
                WLOG(@"腾讯云上传失败！即将进行第%zd次重试", item.upload_retry_count);
                
                item.clound_auth = nil;
                
                [self start];
            }
        }
    };
    
    _sessionTask = [manager uploadTaskWithStreamedRequest:request progress:progressHandler completionHandler:completionHandler];
    
    [_sessionTask resume];
}

- (void)dealloc
{
    DLOG(@"dealloc 释放类 %@",  NSStringFromClass([self class]));
}

@end
