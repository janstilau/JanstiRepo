//
//  HLTool.h
//  HLMagic
//
//  Created by FredHoolai on 3/5/14.
//  Copyright (c) 2014 chen ying. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS (NSUInteger, USConfigFlag) {
    US_CONFIG_HIDE_ONEOFF_REPAYMENT      = 1 << 0,   //隐藏一键还款按钮
    US_CONFIG_HIDE_ACCOUNT_MESSAGE       = 1 << 1,   //隐藏账户页消息按钮
};

@interface NSString (ImageURL)

/** 生成完整的原图链接 */
- (NSString *)fullImageURL;

/** 生成极小的缩略图链接(短边50像素) */
- (NSString *)fullMiniImageURL;

/** 生成通用的缩略图链接(短边150像素) */
- (NSString *)fullSmallImageURL;

/** 通过给定短边长度生成完整的原比例的缩略图链接 */
- (NSString *)fullThumbImageURLWithMinPixel:(NSInteger)minPixel;

/** 通过给定尺寸生成缩略图链接 */
- (NSString *)fullThumbImageURLWithSize:(CGSize)size;

@end


@interface HLTool : NSObject

/** 全局功能配置 */
+ (NSInteger)globalConfig;

/** 保存照片到相册 */
+ (void)writeImageToHTAlbum:(UIImage *)image;

/** 通用的通过远程数据推送进行页面跳转，如：推送通知、banner、广告位 */
+ (void)remotePushViewWithPayload:(NSDictionary *)payload;

/** 是否允许拍照（iOS7以上可用） */
+ (BOOL)cameraGranted;

/** 是否允许访问通信录 */
+ (BOOL)contactsGranted;

/** 是否开启相册权限（iOS7以上可用） */
+ (BOOL)photoAlbumGranted;

/** 迁移老数据 */
+ (void)migrateOldVersionData;

/** 更新域名信息 */
+ (void)updateSystemDomain:(void (^)(void))complete;

/** 更新医院和分期的信息 */
+ (void)requestUpdateHosptitalData;

/** 检测内存状态，如果是内存占用过多则关闭应用 */
+ (void)detectionMemoryPressureLevel;

/** 返回客服电话 */
+ (NSArray *)servicePhoneNumbers;

/** 底部弹出客服电话 */
+ (void)popupServicePhonesSheet;


@end
