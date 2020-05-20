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
@property (nonatomic, strong) void (^imgGeneratedCallBack)(NSArray<UIImage*>* imgs);

- (void)startExport;
- (UIImage *)generateCoverImage;
- (void)generateImages;

@end

NS_ASSUME_NONNULL_END
