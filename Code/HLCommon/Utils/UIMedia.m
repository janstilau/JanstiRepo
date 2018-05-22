//
//  UIMedia.m
//  MCFriends
//
//  Created by marujun on 14-6-13.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import "UIMedia.h"

NSString * const MediaLocalFlag = @"local>";

@implementation UIMedia

+ (NSString *)folderPathWithName:(NSString *)name
{
	//获取程序默认创建的文件路径
	NSString *documentPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //创建主文件夹
    NSString *folderPath = [documentPath stringByAppendingPathComponent:@"media"];
    if (![fileManager fileExistsAtPath:folderPath]) {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
	}
    
    //创建对应的文件夹
    folderPath = [folderPath stringByAppendingPathComponent:name];
	if (![fileManager fileExistsAtPath:folderPath]) {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return folderPath;
}

+ (NSString *)videoPathWithName:(NSString *)name
{
    return [[self folderPathWithName:[self keyWithType:MediaType_Video]] stringByAppendingFormat:@"/%@", name];
}
+ (NSString *)imagePathWithName:(NSString *)name
{
    return [[self folderPathWithName:[self keyWithType:MediaType_Image]] stringByAppendingFormat:@"/%@", name];
}
+ (NSString *)audioPathWithName:(NSString *)name
{
    return [[self folderPathWithName:[self keyWithType:MediaType_Audio]] stringByAppendingFormat:@"/%@", name];
}

//类型对应的键值
+ (NSString *)keyWithType:(MediaType)type
{
    NSString *key = @"image";
    if (type == MediaType_Audio) {
        key = @"audio";
    }else if (type == MediaType_Video) {
        key = @"video";
    }
    return key;
}

+ (NSString *)extensionWithType:(MediaType)type
{
    NSString *suffix = @".jpg";
    if (type == MediaType_Audio) {
        suffix = @".amr";
    }else if (type == MediaType_Video) {
        suffix = @".mp4";
    }
    return suffix;
}

/**
 *  通过文件唯一标识获取文件的路径
 *
 *  @param fid 文件唯一标识
 *
 *  @return 文件路径
 */
+ (NSString *)pathWithId:(NSString *)fid
{
    NSArray *components = [fid componentsSeparatedByString:@">"];
    if (components.count != 3) {
        return @"";
    }
    
    NSString *key = components[1];
    NSString *extension = @".jpg";
    if ([key isEqualToString:@"audio"]) {
        extension = @".amr";
    }else if ([key isEqualToString:@"video"]){
        extension = @".mp4";
    }
    return [NSString stringWithFormat:@"%@/Documents/media/%@/%@%@",NSHomeDirectory(),key,components[2],extension];
}

/**
 *  通过文件唯一标识获取文件的MD5值
 *
 *  @param fid 文件唯一标识
 *
 *  @return 文件的MD5值
 */
+ (NSString *)md5WithId:(NSString *)fid
{
    NSArray *components = [fid componentsSeparatedByString:@","];
    NSMutableArray *lastArray = [NSMutableArray array];
    for (NSString *item in components) {
        [lastArray addObject:[[item componentsSeparatedByString:@">"] lastObject]];
    }
    return [lastArray componentsJoinedByString:@","];
}

/**
 *  把文件保存到待上传文件夹
 *
 *  @param data 文件数据
 *  @param type 文件类型
 *
 *  @return 保存到本地之后的文件唯一标识
 */
+ (NSString *)writeFileWithData:(NSData *)data type:(MediaType)type
{
    NSString *folderPath = [self folderPathWithName:[self keyWithType:type]];
    
    //文件名
    NSString *fileMD5 = [[NSString stringWithFormat:@"%@_%@",[data md5],[[NSDate date] timestamp]] md5];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@%@",folderPath,fileMD5,[self extensionWithType:type]];
    
    //将文件保存到对应路径
    [data writeToFile:filePath atomically:YES];

    return [NSString stringWithFormat:@"%@%@>%@",MediaLocalFlag,[self keyWithType:type],fileMD5];
}

/**
 *  把待上传文件夹中的文件删除掉
 *
 *  @param fid 文件唯一标识
 */
+ (void)removeFileWithId:(NSString *)fid
{
    NSArray *components = [fid componentsSeparatedByString:@","];
    for (NSString *fid in components) {
        NSString *filePath = [self pathWithId:fid];
        
        //删除文件
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        
        if ([filePath hasSuffix:@".jpg"]) {
            //删除缩略图
            filePath = [filePath stringByReplacingOccurrencesOfString:@".jpg" withString:@"_150.jpg"];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
}

/**
 *  把待上传文件夹中的文件移动到缓存文件夹中
 *
 *  @param fid 文件唯一标识
 *  @param url 服务器端返回的文件路径
 */
+ (void)moveFile:(NSString *)fid toUrl:(NSString *)url
{
    NSString *filePath = [self pathWithId:fid];
    NSString *lastPath = [NSData diskCachePathWithURL:url];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:lastPath error:nil];
    }
    
    if ([filePath hasSuffix:@".jpg"]) {
        //小图
        filePath = [filePath stringByReplacingOccurrencesOfString:@".jpg" withString:@"_150.jpg"];
        lastPath = [NSData diskCachePathWithURL:[url fullSmallImageURL]];
        [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:lastPath error:nil];
    }
}

/**
 *  通过文件唯一标识获取NSData数据
 *
 *  @param fid 文件唯一标识
 *
 *  @return NSData对象
 */
+ (NSData *)dataWithId:(NSString *)fid
{
    return [NSData dataWithContentsOfFile:[self pathWithId:fid]];
}

/**
 *  自动生成小图，并把原图和小图一起保存到待上传文件夹中
 *
 *  @param image 需要保存的图片
 *
 *  @return 保存到本地之后的文件唯一标识
 */
+ (NSString *)storeImageToCache:(UIImage *)image
{
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
    
    //150小图
    CGSize size = [UIMedia smallSizeWithLength:150.0f originalSize:image.size];
    UIImage *smallImage = [image imageWithSize:size];
    NSData *smallImageData = UIImageJPEGRepresentation(smallImage, 0.5);
    
    //缓存大图
    NSString *fileId = [UIMedia writeFileWithData:imageData type:MediaType_Image];

    //缓存小图
    NSString *fileMD5 = [UIMedia md5WithId:fileId];
    NSString *extension = [self extensionWithType:MediaType_Image];
    NSString *folderPath = [self folderPathWithName:[self keyWithType:MediaType_Image]];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@_150%@",folderPath,fileMD5,extension];
    [smallImageData writeToFile:filePath atomically:YES];
    
    return fileId;
}

/**
 *  把视频文件和封面图片保存到待上传文件夹中
 *
 *  @param data  视频文件
 *  @param cover 封面图片
 *
 *  @return 保存到本地之后的文件唯一标识，以逗号分隔,第一个为视频id,第二个为截屏id
 */
+ (NSString *)storeVideoToCache:(NSData *)data cover:(UIImage *)cover
{
    NSString *videoId = [UIMedia writeFileWithData:data type:MediaType_Video];
    
    NSString *fileMD5 = [UIMedia md5WithId:videoId];
    NSString *extension = [self extensionWithType:MediaType_Image];
    NSString *folderPath = [self folderPathWithName:[self keyWithType:MediaType_Image]];
    //缓存大图
    NSString *filePath = [NSString stringWithFormat:@"%@/%@%@",folderPath,fileMD5,extension];
    [UIImageJPEGRepresentation(cover, 0.5) writeToFile:filePath atomically:YES];
    
    //缓存小图
    CGSize size = [UIMedia smallSizeWithLength:150.0f originalSize:cover.size];
    UIImage *smallImage = [cover imageWithSize:size];
    NSData *smallImageData = UIImageJPEGRepresentation(smallImage, 0.5);
    filePath = [NSString stringWithFormat:@"%@/%@_150%@",folderPath,fileMD5,extension];
    [smallImageData writeToFile:filePath atomically:YES];
    
    NSString *imageId = [NSString stringWithFormat:@"%@%@>%@",MediaLocalFlag,[self keyWithType:MediaType_Image],fileMD5];
    
    return [@[imageId,videoId] componentsJoinedByString:@","];
}

/**
 *  提取视频中的某一帧图片
 *
 *  @param videoURL 视频文件路径
 *  @param frame    第几帧
 *
 *  @return 视频中改帧所对应的图片
 */
+ (UIImage *)imageOfVideo:(NSURL *)videoURL frame:(float)frame
{
    NSDictionary *opts = @{AVURLAssetPreferPreciseDurationAndTimingKey:@(NO)};
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:videoURL options:opts];
    
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    generator.appliesPreferredTrackTransform = YES;
    
    return [self imageOfVideo:videoURL frame:frame generator:generator asset:urlAsset];
}

+ (UIImage *)imageOfVideo:(NSURL *)videoURL frame:(float)frame generator:(AVAssetImageGenerator *)generator asset:(AVURLAsset *)asset
{
    if (![asset tracksWithMediaType:AVMediaTypeVideo].count) {
        return [UIImage defaultImage];
    }
    float fps = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] nominalFrameRate];

    CMTime time = CMTimeMake(frame*fps, fps);
    NSError *error = nil;
    CMTime actualTime;
    
    CGImageRef image = [generator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *img = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    return img?:[UIImage defaultImage];
}

/**
 *  给定长边的length和原图的尺寸返回缩略图的尺寸
 *
 *  @param length       长边的像素值
 *  @param originalSize 原图的尺寸
 *
 *  @return 缩略图的尺寸
 */
+ (CGSize)smallSizeWithLength:(CGFloat)length originalSize:(CGSize )originalSize
{
    CGSize size;
    if (originalSize.height > originalSize.width) {
        CGFloat multiple = originalSize.width/length;
        size = CGSizeMake(length, originalSize.height/multiple);
    }else
    {
        CGFloat multiple = originalSize.height/length;
        size = CGSizeMake(originalSize.width/multiple, length);
    }
    return size;
}

//清除临时缓存视频
+ (void)removeTempVideo
{
    NSString *mp4VideoFile = [UIMedia videoPathWithName:@"publish_temp.mp4"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:mp4VideoFile]) {
        [fileManager removeItemAtPath:mp4VideoFile error:nil];
    }
}

+ (void)saveVideoToAlbumWithPath:(NSString *)path
{
    // 保存视频
    UISaveVideoAtPathToSavedPhotosAlbum(path, self, nil, nil);
}

@end
