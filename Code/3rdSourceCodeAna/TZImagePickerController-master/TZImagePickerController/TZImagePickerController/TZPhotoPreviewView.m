//
//  TZPhotoPreviewView.m
//  TZImagePickerController
//
//  Created by JustinLau on 2020/3/30.
//  Copyright © 2020 谭真. All rights reserved.
//

#import "TZPhotoPreviewView.h"
#import "TZImageManager.h"
#import "TZImagePickerController.h"
#import "UIView+Layout.h"
#import "TZImageCropManager.h"

@interface TZPhotoPreviewView ()<UIScrollViewDelegate>
@property (assign, nonatomic) BOOL isRequestingGIF;
@end

@implementation TZPhotoPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupScrollView];
        [self setupImageView];
        [self setupGesture];
        [self setupProgressView];
    }
    return self;
}

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.bouncesZoom = YES;
    _scrollView.maximumZoomScale = 2.5;
    _scrollView.minimumZoomScale = 1.0;
    _scrollView.multipleTouchEnabled = YES;
    _scrollView.delegate = self;
    _scrollView.scrollsToTop = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.delaysContentTouches = NO;
    _scrollView.canCancelContentTouches = YES;
    _scrollView.alwaysBounceVertical = NO;
    if (@available(iOS 11, *)) {
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    _scrollView.layer.borderColor = [[UIColor greenColor] CGColor];
    _scrollView.layer.borderWidth = 2;
    [self addSubview:_scrollView];
}

- (void)setupImageView {
    _imageContainerView = [[UIView alloc] init];
    _imageContainerView.clipsToBounds = YES;
    _imageContainerView.contentMode = UIViewContentModeScaleAspectFill;
    [_scrollView addSubview:_imageContainerView];
    _imageContainerView.layer.borderColor = [[UIColor purpleColor] CGColor];
    _imageContainerView.layer.borderWidth = 2;
    
    _imageView = [[UIImageView alloc] init];
    _imageView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.500];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    [_imageContainerView addSubview:_imageView];
}

- (void)setupGesture {
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
    [self addGestureRecognizer:singleTap];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self addGestureRecognizer:doubleTap];
}

- (void)setupProgressView {
    _progressView = [[TZProgressView alloc] init];
    _progressView.hidden = YES;
    [self addSubview:_progressView];
}

- (void)setModel:(TZAssetModel *)model {
    _model = model;
    self.isRequestingGIF = NO;
    [_scrollView setZoomScale:1.0 animated:NO];
    if (model.type == TZAssetModelMediaTypePhotoGif) {
        [self showGif:model];
    } else {
        self.asset = model.asset;
    }
}

- (void)showGif:(TZAssetModel *)model {
    [[TZImageManager manager] getPhotoWithAsset:model.asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        self.imageView.image = photo; // 首先拿到封面图, 将显示用封面图进行设置.
        [self resizeSubviews];
        if (self.isRequestingGIF) { return; }
        // 再显示gif动图
        self.isRequestingGIF = YES;
        [[TZImageManager manager] getOriginalPhotoDataWithAsset:model.asset progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            progress = progress > 0.02 ? progress : 0.02;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressView.progress = progress;
                if (progress >= 1) {
                    self.progressView.hidden = YES;
                } else {
                    self.progressView.hidden = NO;
                }
            });
    #ifdef DEBUG
            NSLog(@"[TZImagePickerController] getOriginalPhotoDataWithAsset:%f error:%@", progress, error);
    #endif
        } completion:^(NSData *data, NSDictionary *info, BOOL isDegraded) {
            if (!isDegraded) {
                self.isRequestingGIF = NO;
                self.progressView.hidden = YES;
                if ([TZImagePickerConfig sharedInstance].gifImagePlayBlock) {
                    [TZImagePickerConfig sharedInstance].gifImagePlayBlock(self, self.imageView, data, info);
                } else {
                    self.imageView.image = [UIImage sd_tz_animatedGIFWithData:data];
                }
                [self resizeSubviews];
            }
        }];
    } progressHandler:nil networkAccessAllowed:NO];
}

- (void)setAsset:(PHAsset *)asset {
    if (_asset && self.imageRequestID) {
        // 取消之前的取图逻辑.
        [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
    }
    
    _asset = asset;
    self.imageRequestID = [[TZImageManager manager] getPhotoWithAsset:asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        if (![asset isEqual:self->_asset]) return; // 和图片下载一样, 这里要在回调的时候, 检验需要显示的和现在的是不是一个.
        self.imageView.image = photo;
        [self resizeSubviews];
        if (self.imageView.tz_height && self.allowCrop) {
            CGFloat scale = MAX(self.cropRect.size.width / self.imageView.tz_width, self.cropRect.size.height / self.imageView.tz_height);
            if (self.scaleAspectFillCrop && scale > 1) { // 如果设置图片缩放裁剪并且图片需要缩放
                CGFloat multiple = self.scrollView.maximumZoomScale / self.scrollView.minimumZoomScale;
                self.scrollView.minimumZoomScale = scale;
                self.scrollView.maximumZoomScale = scale * MAX(multiple, 2);
                [self.scrollView setZoomScale:scale animated:YES];
            }
        }
        
        self->_progressView.hidden = YES;
        if (self.imageProgressUpdateBlock) {
            self.imageProgressUpdateBlock(1);
        }
        if (!isDegraded) {
            self.imageRequestID = 0;
        }
    } progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
        if (![asset isEqual:self->_asset]) return;
        self->_progressView.hidden = NO;
        [self bringSubviewToFront:self->_progressView];
        progress = progress > 0.02 ? progress : 0.02;
        self->_progressView.progress = progress;
        if (self.imageProgressUpdateBlock && progress < 1) {
            self.imageProgressUpdateBlock(progress);
        }
        
        if (progress >= 1) {
            self->_progressView.hidden = YES;
            self.imageRequestID = 0;
        }
    } networkAccessAllowed:YES];
    
    [self configMaximumZoomScale];
}

- (void)recoverSubviews {
    [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:NO];
    [self resizeSubviews];
}

- (void)resizeSubviews {
    _imageContainerView.tz_origin = CGPointZero;
    _imageContainerView.tz_width = self.scrollView.tz_width;
    
    UIImage *image = _imageView.image;
    if (image.size.height / image.size.width > self.tz_height / self.scrollView.tz_width) {
        // 如果, 这是一个竖长图, 那就和 scrollView 一样长.
        _imageContainerView.tz_height = floor(image.size.height / (image.size.width / self.scrollView.tz_width));
    } else {
        // 否则, 就高度居中显示.
        CGFloat height = image.size.height / image.size.width * self.scrollView.tz_width;
        if (height < 1 || isnan(height)) height = self.tz_height;
        height = floor(height);
        _imageContainerView.tz_height = height;
        _imageContainerView.tz_centerY = self.tz_height / 2;
    }
    if (_imageContainerView.tz_height > self.tz_height && _imageContainerView.tz_height - self.tz_height <= 1) {
        _imageContainerView.tz_height = self.tz_height;
    }
    CGFloat contentSizeH = MAX(_imageContainerView.tz_height, self.tz_height);
    _scrollView.contentSize = CGSizeMake(self.scrollView.tz_width, contentSizeH);
    [_scrollView scrollRectToVisible:self.bounds animated:NO];
    _scrollView.alwaysBounceVertical = _imageContainerView.tz_height <= self.tz_height ? NO : YES;
    _imageView.frame = _imageContainerView.bounds;
    
    [self refreshScrollViewContentSize];
}

- (void)configMaximumZoomScale {
    _scrollView.maximumZoomScale = _allowCrop ? 4.0 : 2.5;
    
    if ([self.asset isKindOfClass:[PHAsset class]]) {
        PHAsset *phAsset = (PHAsset *)self.asset;
        CGFloat aspectRatio = phAsset.pixelWidth / (CGFloat)phAsset.pixelHeight;
        // 优化超宽图片的显示
        if (aspectRatio > 1.5) {
            self.scrollView.maximumZoomScale *= aspectRatio / 1.5;
        }
    }
}

- (void)refreshScrollViewContentSize {
    if (!_allowCrop) { return; }
        // 1.7.2 如果允许裁剪,需要让图片的任意部分都能在裁剪框内，于是对_scrollView做了如下处理：
        // 1.让contentSize增大(裁剪框右下角的图片部分)
    CGFloat contentWidthAdd = self.scrollView.tz_width - CGRectGetMaxX(_cropRect);
    CGFloat contentHeightAdd = (MIN(_imageContainerView.tz_height, self.tz_height) - self.cropRect.size.height) / 2;
    CGFloat newSizeW = self.scrollView.contentSize.width + contentWidthAdd;
    CGFloat newSizeH = MAX(self.scrollView.contentSize.height, self.tz_height) + contentHeightAdd;
    _scrollView.contentSize = CGSizeMake(newSizeW, newSizeH);
    _scrollView.alwaysBounceVertical = YES;
    // 2.让scrollView新增滑动区域（裁剪框左上角的图片部分）
    if (contentHeightAdd > 0 || contentWidthAdd > 0) {
        _scrollView.contentInset = UIEdgeInsetsMake(contentHeightAdd, _cropRect.origin.x, 0, 0);
    } else {
        _scrollView.contentInset = UIEdgeInsetsZero;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _scrollView.frame = CGRectMake(10, 0, self.tz_width - 20, self.tz_height);
    static CGFloat progressWH = 40;
    CGFloat progressX = (self.tz_width - progressWH) / 2;
    CGFloat progressY = (self.tz_height - progressWH) / 2;
    _progressView.frame = CGRectMake(progressX, progressY, progressWH, progressWH);
    
    [self recoverSubviews];
}

#pragma mark - UIScrollViewDelegate

/*
 以下对于 ScrollView 的缩放的操作, 基本已经成为了常规范例.
 当 ScrollView 进行 Zoom 的时候, ContentSize 将和 ViewForZoom 的view的尺寸直接进行挂钩.
 所以在 scrollViewDidZoom 中, 不断的改变 ViewForZoom 的中心, 为 ScrollView 的中心.
 在双击的时候, 计算出最大倍数的时候, ViewForZoom 的显示区域.
 */

- (void)doubleTap:(UITapGestureRecognizer *)tap {
    if (_scrollView.zoomScale > _scrollView.minimumZoomScale) {
        _scrollView.contentInset = UIEdgeInsetsZero;
        [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:YES];
    } else {
        CGPoint touchPoint = [tap locationInView:self.imageView];
        CGFloat newZoomScale = _scrollView.maximumZoomScale;
        CGFloat xsize = self.frame.size.width / newZoomScale;
        CGFloat ysize = self.frame.size.height / newZoomScale;
        [_scrollView zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];
    }
}

- (void)singleTap:(UITapGestureRecognizer *)tap {
    if (self.singleTapGestureBlock) {
        self.singleTapGestureBlock();
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageContainerView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    scrollView.contentInset = UIEdgeInsetsZero;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self refreshImageContainerViewCenter];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [self refreshScrollViewContentSize];
}

#pragma mark - Private

- (void)refreshImageContainerViewCenter {
    NSLog(@"Frame %@", NSStringFromCGRect(_imageContainerView.frame));
    NSLog(@"Size : %@", NSStringFromCGSize(_scrollView.contentSize));
    NSLog(@"Inset : %@", NSStringFromUIEdgeInsets(_scrollView.contentInset));
    CGFloat offsetX = (_scrollView.tz_width > _scrollView.contentSize.width) ? ((_scrollView.tz_width - _scrollView.contentSize.width) * 0.5) : 0.0;
    CGFloat offsetY = (_scrollView.tz_height > _scrollView.contentSize.height) ? ((_scrollView.tz_height - _scrollView.contentSize.height) * 0.5) : 0.0;
    self.imageContainerView.center = CGPointMake(_scrollView.contentSize.width * 0.5 + offsetX, _scrollView.contentSize.height * 0.5 + offsetY);
}

@end
