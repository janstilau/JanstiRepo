//
//  MCVideoExporter.h
//  TZImagePickerController
//
//  Created by JustinLau on 2020/4/1.
//  Copyright © 2020 谭真. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCVideoExporter : NSObject

@property (nonatomic, strong) AVAsset *asset;

- (void)startExport;


@end

NS_ASSUME_NONNULL_END
