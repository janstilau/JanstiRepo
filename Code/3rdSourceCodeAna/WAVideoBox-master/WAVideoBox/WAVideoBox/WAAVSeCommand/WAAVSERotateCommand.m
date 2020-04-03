//
//  WAAVSERotateCommand.m
//  WA
//
//  Created by 黄锐灏 on 2018/1/29.
//  Copyright © 2018年 黄锐灏. All rights reserved.
//

#import "WAAVSERotateCommand.h"

@implementation WAAVSERotateCommand

- (void)performWithAsset:(AVAsset *)asset degress:(NSUInteger)degress{
    [super performWithAsset:asset];
    [super performVideoCompopsition];
    if(self.editComposition.videoEditComposition.instructions.count > 1){
         NSAssert(NO, @"This method does not support multi-video processing for the time being.");
        //暂不支持不同分辩率的视频合并马上再旋转
        //ps:可以分开操作，先旋转一个再apeed再旋转即可,使用骚操作完成
    }
    
    degress -= degress % 360 % 90 ;
    
    for (AVMutableVideoCompositionInstruction *instruction in self.editComposition.videoEditComposition.instructions) {
        AVMutableVideoCompositionLayerInstruction *layerInstruction = (AVMutableVideoCompositionLayerInstruction *)(instruction.layerInstructions)[0];
        CGAffineTransform t1;
        CGAffineTransform t2;
        CGSize renderSize;
        // 角度调整
        degress -= degress % 360 % 90;
        if (degress == 90) {
            t1 = CGAffineTransformMakeTranslation(self.editComposition.videoEditComposition.renderSize.height, 0.0);
            renderSize = CGSizeMake(self.editComposition.videoEditComposition.renderSize.height, self.editComposition.videoEditComposition.renderSize.width);
        }else if (degress == 180){
            t1 = CGAffineTransformMakeTranslation(self.editComposition.videoEditComposition.renderSize.width, self.editComposition.videoEditComposition.renderSize.height);
            renderSize = CGSizeMake(self.editComposition.videoEditComposition.renderSize.width, self.editComposition.videoEditComposition.renderSize.height);
        }else if (degress == 270){
            t1 = CGAffineTransformMakeTranslation(0.0, self.editComposition.videoEditComposition.renderSize.width);
            renderSize = CGSizeMake(self.editComposition.videoEditComposition.renderSize.height, self.editComposition.videoEditComposition.renderSize.width);
        }else{
            t1 = CGAffineTransformMakeTranslation(0.0, 0.0);
            renderSize = CGSizeMake(self.editComposition.videoEditComposition.renderSize.width, self.editComposition.videoEditComposition.renderSize.height);
        }
        // Rotate transformation
        t2 = CGAffineTransformRotate(t1, (degress / 180.0) * M_PI );
        self.editComposition.totalEditComposition.naturalSize = self.editComposition.videoEditComposition.renderSize = renderSize;
        CGAffineTransform existingTransform;
        if (![layerInstruction getTransformRampForTime:[self.editComposition.totalEditComposition duration] startTransform:&existingTransform endTransform:NULL timeRange:NULL]) {
            [layerInstruction setTransform:t2 atTime:kCMTimeZero];
        } else {
            CGAffineTransform newTransform =  CGAffineTransformConcat(existingTransform, t2);
            [layerInstruction setTransform:newTransform atTime:kCMTimeZero];
        }
        instruction.layerInstructions = @[layerInstruction];
        
    }
    
    // 将容器大小旋转，若没有anmaitionTool的修改，则直接跳过此步
    if (self.editComposition.videoLayer || self.editComposition.parentLayer) {
        
        for (CALayer *sublayer in self.editComposition.parentLayer.sublayers) {
            if (sublayer == self.editComposition.videoLayer) {
                continue;
            }
            [self converRect:sublayer naturalRenderSize:self.editComposition.videoEditComposition.renderSize renderSize:self.editComposition.videoEditComposition.renderSize];
            sublayer.transform = CATransform3DRotate(sublayer.transform, -(degress / 180.0 * M_PI), 0, 0, 1);
        }
        
        if (degress == 90 || degress == 270) {
            self.editComposition.videoLayer.frame = CGRectMake(0, 0, self.editComposition.videoLayer.bounds.size.height, self.editComposition.videoLayer.bounds.size.width);
            self.editComposition.parentLayer.frame = CGRectMake(0, 0, self.editComposition.parentLayer.bounds.size.height, self.editComposition.parentLayer.bounds.size.width);
        }
        
    }
   
}



- (void)converRect:(CALayer *)layer naturalRenderSize:(CGSize)size renderSize:(CGSize)renderSize{
    
    if (!CGSizeEqualToSize(size, renderSize)) {
        // 还原绝对位置
        CGRect relativeRect = CGRectMake(layer.frame.origin.x / size.width, layer.frame.origin.y / size.height, layer.bounds.size.width / size.width, layer.bounds.size.height / size.height);
        
        layer.frame = CGRectMake(renderSize.width * relativeRect.origin.x,renderSize.height * relativeRect.origin.y,renderSize.width * relativeRect.size.width, renderSize.height * relativeRect.size.height);
        
    }
}

@end
