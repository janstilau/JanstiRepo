//
//  TZPhotoPreviewCell.h
//  TZImagePickerController
//
//  Created by 谭真 on 15/12/24.
//  Copyright © 2015年 谭真. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TZAssetModel;
@interface TZAssetPreviewCell : UICollectionViewCell
@property (nonatomic, strong) TZAssetModel *model;
@property (nonatomic, strong) void (^singleTapGestureBlock)(void);
- (void)configSubviews;
- (void)photoPreviewCollectionViewDidScroll;
@end


@class TZAssetModel,TZProgressView,TZPhotoPreviewView;

@interface TZPhotoPreviewCell : TZAssetPreviewCell

@property (nonatomic, copy) void (^imageProgressUpdateBlock)(double progress);
@property (nonatomic, strong) TZPhotoPreviewView *previewView;
@property (nonatomic, assign) BOOL allowCrop;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, assign) BOOL scaleAspectFillCrop;

- (void)recoverSubviews;

@end


@class AVPlayer, AVPlayerLayer;
@interface TZVideoPreviewCell : TZAssetPreviewCell
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) UIButton *playButton;
@property (strong, nonatomic) UIImage *cover;
@property (nonatomic, strong) NSURL *videoURL;
- (void)pausePlayerAndShowNaviBar;
@end


@interface TZGifPreviewCell : TZAssetPreviewCell
@property (strong, nonatomic) TZPhotoPreviewView *previewView;
@end
