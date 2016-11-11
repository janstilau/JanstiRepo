//
//  UIMedia.h
//  MCFriends
//
//  Created by marujun on 14-6-13.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

typedef enum {
    MediaType_Image = 0,      //普通图片
    MediaType_Audio = 1,      //普通音频
    MediaType_Video = 2,      //普通视频
    MediaType_Map   = 3,      //位置信息
} MediaType;

extern NSString * const MediaLocalFlag;

@interface UIMedia : NSObject

+ (NSString *)folderPathWithName:(NSString *)name;

//获取多媒体文件路径
+ (NSString *)videoPathWithName:(NSString *)name;
+ (NSString *)imagePathWithName:(NSString *)name;
+ (NSString *)audioPathWithName:(NSString *)name;

/** 通过文件唯一标识获取NSData数据 */
+ (NSData *)dataWithId:(NSString *)fid;

/** 通过文件唯一标识获取文件的路径 */
+ (NSString *)pathWithId:(NSString *)fid;

/** 通过文件唯一标识获取文件的MD5值 */
+ (NSString *)md5WithId:(NSString *)fid;

/** 把文件保存到待上传文件夹 */
+ (NSString *)writeFileWithData:(NSData *)data type:(MediaType)type;

/** 把待上传文件夹中的文件删除掉 */
+ (void)removeFileWithId:(NSString *)fid;

/** 把待上传文件夹中的文件移动到缓存文件夹中 */
+ (void)moveFile:(NSString *)fid toUrl:(NSString *)url;

/** 自动生成小图，并把原图和小图一起保存到待上传文件夹中 */
+ (NSString *)storeImageToCache:(UIImage *)image;

/** 把视频文件和封面图片保存到待上传文件夹中 */
+ (NSString *)storeVideoToCache:(NSData *)data cover:(UIImage *)cover;

/** 给定长边的length和原图的尺寸返回缩略图的尺寸 */
+ (CGSize)smallSizeWithLength:(CGFloat)length originalSize:(CGSize )originalSize;

+ (UIImage *)imageOfVideo:(NSURL *)videoURL frame:(float)frame;
+ (UIImage *)imageOfVideo:(NSURL *)videoURL frame:(float)frame generator:(AVAssetImageGenerator *)generator asset:(AVURLAsset *)asset;

//清除临时缓存视频
+ (void)removeTempVideo;

//存视频
+ (void)saveVideoToAlbumWithPath:(NSString *)path;

@end
