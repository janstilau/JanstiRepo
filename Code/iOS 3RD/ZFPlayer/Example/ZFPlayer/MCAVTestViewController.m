//
//  MCAVTestViewController.m
//  ZFPlayer_Example
//
//  Created by JustinLau on 2020/3/26.
//  Copyright © 2020 紫枫. All rights reserved.
//

#import "MCAVTestViewController.h"
#import "UIView+Debug.h"
#import <AVKit/AVKit.h>

@interface MCAVTestViewController ()

@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) AVPictureInPictureController *pinpVC;

@end

@implementation MCAVTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    AVPlayerViewController *playerVC;
    playerVC = [[AVPlayerViewController alloc] init];
    // 本地文件
//    NSURL * playerURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test"  ofType:@"mp4"]];
    // 网络资源
    NSURL * playerURL = [NSURL URLWithString:@"https://www.apple.com/105/media/us/mac/family/2018/46c4b917_abfd_45a3_9b51_4e3054191797/films/grimes/mac-grimes-tpl-cc-us-2018_1280x720h.mp4"];
    playerVC.player = [AVPlayer playerWithURL:playerURL];
    playerVC.allowsPictureInPicturePlayback = YES;
    [playerVC.contentOverlayView addBorderLine];
    if (@available(iOS 11.0, *)) {
        playerVC.entersFullScreenWhenPlaybackBegins = YES;
        playerVC.exitsFullScreenWhenPlaybackEnds = YES;

    } else {
        // Fallback on earlier versions
    }
    
    [self.view addSubview:playerVC.view];
    playerVC.view.frame = self.view.bounds;
    [self addChildViewController:playerVC];
    
//    _pinpVC = [[AVPictureInPictureController alloc] initWithPlayerLayer:playerVC.player];
    AVPlayerLayer *layer = nil;
    UIButton *redBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
    redBtn.backgroundColor = [UIColor redColor];
    [self.view addSubview:redBtn];
    [redBtn addTarget:self action:@selector(redBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)redBtnDidClicked:(id)sender {
    [_pinpVC startPictureInPicture];
}


@end
