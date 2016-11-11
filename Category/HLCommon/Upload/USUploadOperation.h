//
//  USUploadOperation.h
//  HTWallet
//
//  Created by marujun on 16/7/29.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface USUploadItem : DBObject

@property (nonatomic, strong) UIImage  *image;                  //等待上传的照片
@property (nonatomic, strong) NSData  *file_data;               //等待上传的照片的二进制数据
@property (nonatomic, strong) NSString *file_path;              //等待上传的文件的路径

@property (nonatomic, copy) NSString   *clound_url;             //腾讯云文件链接

@end

typedef void (^USUploadCompleteHandler)(NSArray<USUploadItem *> *results, NSError *error);

@interface USUploadOperation : NSObject

@property (nonatomic, strong, readonly) NSURLSessionTask *sessionTask;

+ (instancetype)startWithImageOrFilePathArray:(NSArray<id> *)sourceArray completeHandler:(USUploadCompleteHandler)completeHandler;

@end
