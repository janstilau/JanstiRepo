//
//  TZPhotoPreviewView.h
//  TZImagePickerController
//
//  Created by JustinLau on 2020/3/30.
//  Copyright © 2020 谭真. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TZAssetModel.h"
#import "TZProgressView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TZPhotoPreviewView : UIView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *imageContainerView;
@property (nonatomic, strong) TZProgressView *progressView;

@property (nonatomic, assign) BOOL allowCrop;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, assign) BOOL scaleAspectFillCrop;
@property (nonatomic, strong) TZAssetModel *model;
@property (nonatomic, strong) id asset;
@property (nonatomic, copy) void (^singleTapGestureBlock)(void);
@property (nonatomic, copy) void (^imageProgressUpdateBlock)(double progress);

@property (nonatomic, assign) int32_t imageRequestID;

- (void)recoverSubviews;

@end
NS_ASSUME_NONNULL_END
