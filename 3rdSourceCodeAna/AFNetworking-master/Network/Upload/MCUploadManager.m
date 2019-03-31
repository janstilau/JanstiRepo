//
//  MCUploadManager.m
//  MCFriends
//
//  Created by Zhou Kang on 2017/6/1.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import "MCUploadManager.h"

#define MaxRetryCount 3

@interface MCUploadItem ()

@property (nonatomic, copy) NSString *ID;                     //ID
@property (nonatomic, strong) NSDictionary *cloundAuthDict;   //腾讯云认证信息
@property (nonatomic, assign) NSInteger signRetryCount;       //获取签名失败重试次数
@property (nonatomic, assign) NSInteger uploadRetryCount;     //上传失败重试次数

@end

@implementation MCUploadItem

- (NSData *)fileData {
    if (_fileData) {
        return _fileData;
    }
    NSData *fileData = nil;
    switch (_mediaType) {
        case MCMediaTypePicture:
            fileData = [self imageData];
            break;
        case MCMediaTypeAudio:
            fileData = [self audioData];
            break;
        case MCMediaTypeVideo:
            break;
        default:
            break;
    }
    return fileData;
}

- (NSData *)imageData {
    NSData *filedata = nil;
    UIImage *item_image = self.image;
    filedata = UIImageJPEGRepresentation(item_image, 0.95);
    
    //腾讯云限制单次请求20M，超出的需要做分片上传
    float lengthLimit = 20.f*1024*1024;
    
    if (filedata.length > lengthLimit) {
        //图片压缩到20M以下
        for (float i=0.78; i>0.5; i-=0.02) {
            @autoreleasepool {
                filedata = UIImageJPEGRepresentation(item_image, i);
            }
            if (filedata.length < lengthLimit) {
                break;
            };
        }
    }
    DLOG(@"最终上传图片大小： %@",[NSByteCountFormatter stringFromByteCount:filedata.length countStyle:NSByteCountFormatterCountStyleBinary]);
    return filedata;
}

- (UIImage *)image {
    if (_image) {
        return _image;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:_filePath];
    if (image) {
        return image;
    }
    image = [UIImage imageWithData:_fileData];
    if (image) {
        return image;
    }
    return nil;
}

- (CGFloat)imageWidth {
    return self.image.size.width;
}

- (CGFloat)imageHeight {
    return self.image.size.height;
}

- (NSData *)audioData {
    NSData *filedata = [NSData dataWithContentsOfFile:_filePath];
    return filedata;
}

@end

@interface MCUploadManager ()

@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) NSArray <MCUploadItem *> *allItems;
@property (nonatomic, strong) NSMutableArray <MCUploadItem *> *uploadingItems;
@property (nonatomic, copy) MCUploadProgressHandler progressHandler;
@property (nonatomic, copy) MCUploadCompleteHandler completeHandler;
@property (nonatomic, assign) MCPictureType pictureType;

@end

@implementation MCUploadManager

+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler {
    return [self uploadWithSource:sourceArray
                        mediaType:MCMediaTypePicture
                      pictureType:MCPictureTypePost
                  progressHandler:progressHandler
                  completeHandler:completeHandler];
}

+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                       mediaType:(MCMediaType)mediaType
                     pictureType:(MCPictureType)picType
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler {
    NSError *error = nil;
    NSMutableArray *itemArrayM = [NSMutableArray array];
    for (id obj in sourceArray) {
        MCUploadItem *item = [[MCUploadItem alloc] init];
        item.mediaType = mediaType;
        item.mimeType = [self mimeTypeWithMediaType:mediaType];
        if ([obj isKindOfClass:[NSData class]]) {
            item.fileData = obj;
        }
        else if ([obj isKindOfClass:[NSString class]]) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:obj]) {
                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"文件路径不存在"}];
                break;
            } else {
                item.filePath = obj;
            }
        }
        else if ([obj isKindOfClass:[UIImage class]]) {
            item.image = obj;
        }
        else {
            error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"提供的数据源不能为空"}];
            break;
        }
        [itemArrayM addObject:item];
    }
    if (error) {
        if (completeHandler) {
            completeHandler(nil, error);
        }
        return nil;
    }
    
    MCUploadManager *operation = [[self alloc] init];
    operation.uploadingItems = itemArrayM;
    operation.allItems = [NSArray arrayWithArray:itemArrayM];
    operation.progressHandler = progressHandler;
    operation.completeHandler = completeHandler;
    operation.pictureType = picType;
    
    [operation start];
    
    return operation;
}

+ (NSString *)mimeTypeWithMediaType:(MCMediaType)mediaType {
    NSString *mimeType = @"image/jpeg";
    switch (mediaType) {
        case MCMediaTypePicture:
            mimeType = @"image/jpeg";
            break;
        case MCMediaTypeAudio:
            mimeType = @"application/octet-stream";
            break;
        case MCMediaTypeVideo:
            mimeType = @"video/mp4";
        default:
            break;
    }
    return mimeType;
}

- (void)dealloc {
    DLOG(@"dealloc 释放类 %@",  NSStringFromClass([self class]));
}

- (void)start {
    if (_isUploading) {
        return;
    };
    if (!_uploadingItems.count) {
        if (_completeHandler) {
            _completeHandler(_allItems, nil);
        }
        return;
    }
    MCUploadItem *uplodingItem = [_uploadingItems firstObject];
    if (!uplodingItem.cloundAuthDict) {
        [self requestPictureSign:[_uploadingItems firstObject]];
        return;
    }
    [self requestPictureUpload:uplodingItem];
}

- (void)setProgress:(CGFloat)process {
    _progress = process;
    
    NSInteger total = _allItems.count;
    NSInteger uploaded = _allItems.count - _uploadingItems.count;
    
    CGFloat newMultiplier = MAX(CGFLOAT_MIN, total?((uploaded+floor(_progress*100)/100.f)/total):1);
    
    if (_progressHandler) {
        _progressHandler(newMultiplier);
    }
}

/**
 *  获取腾讯云口令
 */
- (void)requestPictureSign:(MCUploadItem *)item {
    _isUploading = YES;
    //    NSString *path = @"http://192.168.2.31/member/user/cos-sign?__debug__=1&access_token=yjLGmL36ihZgdKMV6BS-11jj2fZwqy6I";
    //        NSString *path = @"http://192.168.2.31/member/user/cos-sign?access_token=yjLGmL36ihZgdKMV6BS-11jj2fZwqy6I&__debug__=1&uid=7&picture_type=0&type=0&extension=jpg";
    
    MCMediaType mediaType = item.mediaType;
    NSString *extension = [self extensionInItem:item];
    
    NSDictionary *params = @{ @"type": @(mediaType).stringValue,
                              @"picture_type": @(_pictureType).stringValue,
                              @"extension": extension };
    _sessionTask = [NetWork getRequestToUrl:url_upload_sign params:params complete:^(BOOL successed, HTTPResponse *response) {
        self.isUploading = NO;
        self->_sessionTask = nil;
        if(successed){
            //处理获取结果
            item.cloundAuthDict = response.dataDict;
            [self start];
        }
        else {
            item.signRetryCount += 1;
            if (item.signRetryCount >= MaxRetryCount) {
                if (self.completeHandler) {
                    self.completeHandler(nil, [NSError errorWithDomain:NSURLErrorDomain
                                                                  code:NSURLErrorResourceUnavailable
                                                              userInfo:@{NSLocalizedDescriptionKey:@"获取签名失败"}]);
                }
            }
            else {
                //重新尝试
                [self requestPictureSign:item];
                WLOG(@"获取签名失败！即将进行第%zd次重试", item.signRetryCount);
            }
        }
    }];
}

- (NSString *)extensionInItem:(MCUploadItem *)item {
    MCMediaType mediaType = item.mediaType;
    NSString *extension = @"jpeg";
    switch (mediaType) {
        case MCMediaTypePicture: {
            extension = [self contentTypeForImageData:item.fileData];
        } break;
        case MCMediaTypeAudio: {
            extension = @"mp3";
        } break;
        case MCMediaTypeVideo: {
            extension = @"mp4";
        } break;
    }
    return extension;
}

- (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
    }
    return @"";
}

- (void)requestPictureUpload:(MCUploadItem *)item {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer = [UGJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = nil;
    
    NSData *filedata = item.fileData;
    
    void (^formBlock)(id <AFMultipartFormData> formData) = ^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:filedata name:@"filecontent" fileName:@"filecontent" mimeType:item.mimeType];
    };
    
    //直传到腾讯云
    NSMutableURLRequest *request = [serializer multipartFormRequestWithMethod:@"POST"
                                                                    URLString:item.cloundAuthDict[@"path"]
                                                                   parameters:@{@"op":@"upload"}
                                                    constructingBodyWithBlock:formBlock
                                                                        error:nil];
    [request setValue:item.cloundAuthDict[@"signature"] forHTTPHeaderField:@"Authorization"];
    
    DLOG(@"post request url:  %@",request.URL.absoluteString);
    
    @weakify(self)
    void (^progressHandler)(NSProgress *) = ^(NSProgress * _Nonnull uploadProgress) {
        // This is not called back on the main queue.
        // You are responsible for dispatching to the main queue for UI updates
        if (uploadProgress.totalUnitCount > 0) {  //异常现象：iOS7的uploadTask.countOfBytesExpectedToSend 为0
            float progress = uploadProgress.completedUnitCount*1.f / uploadProgress.totalUnitCount;
            DLOG(@"upload process: %.0f%% (%@/%@)",100*progress,@(uploadProgress.completedUnitCount),@(uploadProgress.totalUnitCount));
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weak_self setProgress:(isinf(progress)?0:progress)];
            });
        }
    };
    
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        self.isUploading = NO;
        self->_sessionTask = nil;
        
        [weak_self setProgress:1];
        
        if (!error) {
            DLOG(@"post responseObject:  %@",responseObject);
            item.cloundURLString = responseObject[@"data"][@"access_url"];
            [self.uploadingItems removeObject:item];
            [self start];
        }
        else {
            ELOG(@"post request url:  %@", request.URL.absoluteString);
            ELOG(@"post responseObject:  %@", responseObject);
            ELOG(@"post error :  %@", error.localizedDescription);
            
            item.uploadRetryCount += 1;
            
            //上传失败后重试的次数
            if (item.uploadRetryCount >= MaxRetryCount) {
                if (self.completeHandler) {
                    NSDictionary *dict = (NSDictionary *)responseObject;
                    NSError *newError = error;
                    if ([dict isKindOfClass:[NSDictionary class]]) {
                        newError = [NSError errorWithDomain:@"com.moca" code:[dict[@"code"] integerValue] userInfo:dict];
                    }
                    
                    self.completeHandler(nil, newError);
                }
            }
            else {
                WLOG(@"腾讯云上传失败！即将进行第%zd次重试", item.uploadRetryCount);
                item.cloundAuthDict = nil;
                [self start];
            }
        }
    };
    _sessionTask = [manager uploadTaskWithStreamedRequest:request progress:progressHandler completionHandler:completionHandler];
    [_sessionTask resume];
}

@end
