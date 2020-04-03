//
//  WAAVSEComposition.h
//  YCH
//
//  Created by 黄锐灏 on 2017/9/26.
//  Copyright © 2017 黄锐灏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

// 这个类是一个数据类. 用来存放有关于视频合成的各个对象.

@interface WACommandComposition : NSObject

 /*
  总的视频合成数据类.
  */
@property (nonatomic , strong) AVMutableComposition *totalEditComposition;

/**
 视频操作指令
 AVMutableVideoComposition 就是一些编辑工作的集合.
 您可以为输出视频指定所需的渲染大小和缩放以及帧持续时间
 通过视频作品的指示（由AVMutableVideoCompositionInstruction类表示），您可以修改视频的背景颜色并应用图层说明
 层指令（由AVMutableVideoCompositionLayerInstruction类表示）可用于将转换，变换斜坡，不透明度和不透明度斜坡应用于组合中的视频轨道。
 视频构图类还使您能够使用该animationTool属性将核心动画框架的效果引入到您的视频中
 */
@property (nonatomic , strong) AVMutableVideoComposition *videoEditComposition;

/**
 音频操作指令
 */
@property (nonatomic , strong) AVMutableAudioMix *audioEditComposition;

/**
 视频操作参数数组
 */
@property (nonatomic , strong) NSMutableArray<AVMutableVideoCompositionInstruction *> *videoInstructions;

/**
 音频操作参数数组
 */
@property (nonatomic , strong) NSMutableArray<AVMutableAudioMixInputParameters *> *audioInstructions;


/**
 视频时长(变速/裁剪后)  PS:后续版本会为每条轨道单独设置duration
 */
@property (nonatomic , assign) CMTime duration;

/**
 视频分辩率
 */
@property (nonatomic , copy) NSString *presetName;

/**
 视频质量
 */
@property (nonatomic , assign) NSInteger videoQuality;

/**
 输出文件格式
 */
@property (nonatomic , copy) AVFileType fileType;

/**
 画布父容器
 */
@property (nonatomic , strong) CALayer *parentLayer;

/**
 原视频容器
 */
@property (nonatomic , strong) CALayer *videoLayer;


@property (nonatomic , assign) CGSize lastInstructionSize;


@end

NS_ASSUME_NONNULL_END
