//
//  TZVideoPlayerController.h
//  TZImagePickerController
//
//  Created by 谭真 on 16/1/5.
//  Copyright © 2016年 谭真. All rights reserved.
//

#import <UIKit/UIKit.h>

// 一个简单的对于 AVPlayer 的封装工作.

@class TZAssetModel;
@interface TZVideoPlayerController : UIViewController

@property (nonatomic, strong) TZAssetModel *model;

@end
