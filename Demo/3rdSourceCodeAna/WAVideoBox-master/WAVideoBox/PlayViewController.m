//
//  PlayViewController.m
//  WAVideoBox
//
//  Created by 黄锐灏 on 2019/1/6.
//  Copyright © 2019 黄锐灏. All rights reserved.
//

#import "PlayViewController.h"
#import <AVKit/AVKit.h>

@interface PlayViewController ()

@property(nonatomic,strong) AVPlayerViewController *playerController;
@property (nonatomic, strong) AVPlayerLayer *topLayer;
@property (nonatomic, strong) AVPlayer *topPlayer;
@property (nonatomic, strong) AVPlayerLayer *bottomLayer;
@property (nonatomic, strong) AVPlayer *bottomPlayer;
@property (nonatomic , strong) NSString *filePath;

@end

@implementation PlayViewController

// 这个类很简单, 就是播放视频而已.

- (void)viewDidLoad {
    [super viewDidLoad];
    _playerController = [[AVPlayerViewController alloc] init];
    NSURL * url = [NSURL fileURLWithPath:self.filePath];
    _playerController.player = [AVPlayer playerWithURL:url];
    _playerController.view.frame = self.view.bounds;
    _playerController.showsPlaybackControls = YES;
    [self.view addSubview:_playerController.view];
    
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVPlayerItem *topItem = [AVPlayerItem playerItemWithAsset:asset];
    AVPlayerItem *bottomItem = [AVPlayerItem playerItemWithAsset:asset];
    _topPlayer = [AVPlayer playerWithPlayerItem:topItem];
    _bottomPlayer = [AVPlayer playerWithPlayerItem:bottomItem];
    _topLayer = [AVPlayerLayer playerLayerWithPlayer:_topPlayer];
    _bottomLayer = [AVPlayerLayer playerLayerWithPlayer:_bottomPlayer];
    [self.view.layer addSublayer:_topLayer];
    CGRect topFrame = self.view.bounds;
    topFrame.size.height /= 2;
    _topLayer.frame = topFrame;
    
    [self.view.layer addSublayer:_bottomLayer];
    CGRect bottomFrame = self.view.bounds;
    bottomFrame.size.height /= 2;
    bottomFrame.origin.y = bottomFrame.size.height;
    _bottomLayer.frame = bottomFrame;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
//    [[_playerController player] play];
    [_topPlayer play];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [_bottomPlayer play];
    });
}

- (void)loadWithFilePath:(NSString *)filePath{
    self.filePath = filePath;
}


@end
