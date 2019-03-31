//
//  MCUploadManager.h
//  MCFriends
//
//  Created by Zhou Kang on 2017/6/1.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MCMediaType) {
    MCMediaTypePicture=0,
    MCMediaTypeAudio,
    MCMediaTypeVideo,
};

typedef NS_ENUM(NSUInteger, MCPictureType) {
    MCPictureTypeAvatar=0,
    MCPictureTypeBGWall,
    MCPictureTypePhotoWall,
    MCPictureTypePost,
    MCPictureTypeReplyPost,
    MCPictureTypePostAudio = 12,
    MCPictureTypeReplyAudio = 13
};

@interface MCUploadItem : NSObject

@property (nonatomic, assign) MCMediaType mediaType;
@property (nonatomic, strong) NSString *mimeType;

@property (nonatomic, strong) NSData   *fileData;            //等待上传的照片的二进制数据
@property (nonatomic, strong) NSString *filePath;            //等待上传的文件的路径
@property (nonatomic, copy) NSString   *cloundURLString;     //腾讯云文件链接
// 图片
@property (nonatomic, strong) UIImage  *image;               //等待上传的照片
@property (nonatomic, assign) CGFloat imageHeight;
@property (nonatomic, assign) CGFloat imageWidth;



@end

typedef void (^MCUploadProgressHandler)(CGFloat progress);
typedef void (^MCUploadCompleteHandler)(NSArray <MCUploadItem *> *results, NSError *error);

@interface MCUploadManager : NSObject

@property (nonatomic, strong, readonly) NSURLSessionTask *sessionTask;

/**
 腾讯云直传

 @param sourceArray 数据源, 元素可以是 UIImage *, NSData *, NSString *fileLocalPath,
 @param progressHandler 进度回调
 @param completeHandler 上传完成回调
 @return 实例
 */
+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler;
/**
 腾讯云直传

 @param sourceArray 数据源, 元素可以是 UIImage *, NSData *, NSString *fileLocalPath,
 @param mediaType 媒体类型
 @param picType 图片的类型, 后端生成签名和路径需要据此区分文件夹
 @param progressHandler 进度回调
 @param completeHandler 上传完成回调
 @return 实例
 */
+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                       mediaType:(MCMediaType)mediaType
                     pictureType:(MCPictureType)picType
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler;

@end
