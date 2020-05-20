//
//  WAVideoTool.m
//  WA
//
//  Created by 黄锐灏 on 17/4/24.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAVideoBox.h"
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "WAAVSEExportCommand.h"
#import "WAAVSEVideoMixCommand.h"
#import "WAAVSEImageMixCommand.h"
#import "WAAVSEReplaceSoundCommand.h"
#import "WAAVSEGearboxCommand.h"
#import "WAAVSERangeCommand.h"
#import "WAAVSERotateCommand.h"
#import "WAAVSEDubbedCommand.h"
#import "WAAVSEExtractSoundCommand.h"
#import <pthread.h>

@interface WAVideoBox (){
    CADisplayLink *_progressLink;
}

@property (nonatomic , strong) WAEditComposition *cacheComposition;
@property (nonatomic , weak) WAAVSEExportCommand *exportCommand;

@property (nonatomic , strong) NSMutableArray <WAEditComposition *>*workSpace;

@property (nonatomic , strong) NSMutableArray <WAEditComposition *>*composeSpace;

@property (nonatomic , strong) NSMutableArray <NSString *>*tmpVideoSpace; //临时视频文件

@property (nonatomic , assign) NSInteger directCompostionIndex;

@property (nonatomic , copy) NSString *filePath;

@property (nonatomic , copy) NSString *tmpPath; //当前临时合成的文件位置

@property (nonatomic , copy) void (^editorComplete)(NSError *error);

@property (nonatomic , copy) void (^progress)(float progress);

@property (nonatomic , copy) NSString *presetName;

@property (nonatomic , assign) NSInteger composeCount; // 一共需要几次compose操作，用于记录进度

@property (nonatomic , assign ,getter=isSuspend) BOOL suspend; //线程 挂起

@property (nonatomic , assign ,getter=isCancel) BOOL cancel; //用户取消操作

@end

dispatch_queue_t _videoBoxContextQueue;
static void *videoBoxContextQueueKey = &videoBoxContextQueueKey;

dispatch_queue_t _videoBoxProcessQueue;
static void *videoBoxProcessQueueKey = &videoBoxProcessQueueKey;

NSString *_tmpDirectory;


void runSynchronouslyOnVideoBoxProcessingQueue(void (^block)(void))
{
    if (dispatch_get_specific(videoBoxProcessQueueKey)){
        block();
    }else{
        dispatch_sync(_videoBoxProcessQueue, block);
    }
}

void runAsynchronouslyOnVideoBoxProcessingQueue(void (^block)(void))
{
    if (dispatch_get_specific(videoBoxProcessQueueKey)){
        block();
    }else{
        dispatch_async(_videoBoxProcessQueue, block);
    }
}

void runSynchronouslyOnVideoBoxContextQueue(void (^block)(void))
{
    if (dispatch_get_specific(videoBoxContextQueueKey)){
        block();
    }else{
        dispatch_sync(_videoBoxContextQueue, block);
    }
}

void runAsynchronouslyOnVideoBoxContextQueue(void (^block)(void))
{
    if (dispatch_get_specific(videoBoxContextQueueKey)){
        block();
    }else{
        dispatch_async(_videoBoxContextQueue, block);
    }
}

@implementation WAVideoBox

/*
 dispatch_queue_set_specific
 dispatch_get_specific
 dispatch_queue_get_specific
 这两个 API, 就是为了给 queue 绑定一个值. 线程也有类似的代码.
 在运行时, dispatch_get_specific 如果能够返回值, 那么就证明当前的代码, 是运行在对应的 queue 中.
 在这里, 作用通过这两个 API, 来进行任务的调度.
 */

+ (void)initialize{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tmpDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WAVideoBoxTmp"];
        _videoBoxContextQueue = dispatch_queue_create("VideoBoxContextQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_videoBoxContextQueue, videoBoxContextQueueKey, &videoBoxContextQueueKey, NULL);
        _videoBoxProcessQueue = dispatch_queue_create("VideoBoxProcessQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_videoBoxProcessQueue, videoBoxProcessQueueKey, &videoBoxProcessQueueKey, NULL);
        if (![[NSFileManager defaultManager] fileExistsAtPath:_tmpDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_tmpDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    });
}

#pragma mark life cycle
- (instancetype)init{
    self = [super init];
    
    self.videoQuality = 0;
    self.ratio = WAVideoExportRatio960x540;
    // WAAVSEExportCommandCompletionNotification 这个只会在 ExportCommand 里面会抛出.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AVEditorCompleteNotification:) name:WAAVSEExportCommandCompletionNotification object:nil];
    [self setupSpaces];
    return self;
}

- (void)setupSpaces {
    _composeSpace = [NSMutableArray array];
    _workSpace = [NSMutableArray array];
    _tmpVideoSpace = [NSMutableArray array];
}

- (void)dealloc{
    if (self.isSuspend) {
        dispatch_resume(_videoBoxContextQueue);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark pubilc method
#pragma mark 资源

- (BOOL)appendVideoByPath:(NSString *)videoPath{
    if (videoPath.length == 0 ) {
        return NO;
    }
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    return [self appendVideoByAsset:asset];
}

// 获取到资源之后, 第一步是建立一个 WACommandComposition, 将资源的音轨, 视频轨导出到 AVMutableCompositionTrack 上, 集合到一个 AVMutableComposition 中.
- (BOOL)appendVideoByAsset:(AVAsset *)videoAsset{
    if (!videoAsset || !videoAsset.playable) {
        return NO;
    }
    // 该函数是一切操作的起点, 所以在这个函数的开头, 做 Cancel 的处理.
    // 将所有的操作, 放到一个队列里面, 减少多线程同步的代码复杂度.
    runSynchronouslyOnVideoBoxProcessingQueue(^{
        self.cancel = NO;
    });
    
    runAsynchronouslyOnVideoBoxContextQueue(^{
        // 清空工作区
        [self commitCompostionToComposespace];
        if (!self.cacheComposition) {
            self.cacheComposition = [WAEditComposition new];
            self.cacheComposition.presetName = self.presetName;
            self.cacheComposition.videoQuality = self.videoQuality;
            WAAVSECommand *command = [[WAAVSECommand alloc] initWithComposition:self.cacheComposition];
            [command performWithAsset:videoAsset];
        }else{
            // 如果, 接连插入了两个视频数据, 就要做组合操作了.
            WAAVSEVideoMixCommand *mixcommand = [[WAAVSEVideoMixCommand alloc] initWithComposition:self.cacheComposition];
            // 这里, 第一个值是 self.cacheComposition.totalEditComposition, 也就是这个函数调用后, 结果还会在 self.cacheComposition.totalEditComposition 上.
            [mixcommand performWithAsset:self.cacheComposition.totalEditComposition mixAsset:videoAsset];
        }
        
    });
    return YES;
}

- (void)commit{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self.workSpace insertObjects:self.composeSpace atIndexes:[[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, self.composeSpace.count)]];
        
        [self.composeSpace removeAllObjects];
        [self commitCompostionToWorkspace];
    });
    
}

#pragma mark Actions

// 以下的所有对于视频进行操作的动作, 都会调用 commitCompostionToWorkspace 这个方法. 也就是把准备好的资源, 提交给工作区.
// 其实只会提交一次, 因为 self.cacheComposition 只有在 AppendAsset 的时候, 才会有值.
- (void)commitCompostionToWorkspace{
    if (self.cacheComposition) {
        [self.workSpace addObject:self.cacheComposition];
        self.cacheComposition = nil;
    }
}

// 简单的, 将浮点型转化成为 CMTimeRange 的类型.
- (BOOL)rangeVideoByBeganPoint:(CGFloat)beganPoint endPoint:(CGFloat)endPoint{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
            double duration  = CMTimeGetSeconds(composition.duration);
            CMTime timeFrom = CMTimeMake(beganPoint / duration  * composition.duration.value, composition.duration.timescale);
            CMTime timeTo = CMTimeMake((endPoint  - beganPoint)/ duration * composition.duration.value, composition.duration.timescale);
            // 因为, Async 其实就是提交任务的概念. 所以, 这里嵌套提交是没有问题的.
            [self rangeVideoByTimeRange:CMTimeRangeMake(timeFrom, timeTo)];
        }
    });
    return YES;
}
// 将裁剪的工作, 封装到了 WAAVSERangeCommand 中, 里面主要是针对 track 的剪切操作. 类比视频编辑软件.
- (BOOL)rangeVideoByTimeRange:(CMTimeRange)range{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSERangeCommand *rangeCommand = [[WAAVSERangeCommand alloc] initWithComposition:composition];
            [rangeCommand performWithAsset:composition.totalEditComposition timeRange:range];
        }
    });
    return YES;
}

- (BOOL)rotateVideoByDegress:(NSInteger)degress{
    // 如果是 360 的倍数, 根本不需要转.
    if (!degress % 360) {
        return NO;
    }
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSERotateCommand *rotateCommand = [[WAAVSERotateCommand alloc] initWithComposition:composition];
            [rotateCommand performWithAsset:composition.totalEditComposition degress:degress];
        }
    });
    
    return YES;
    
}

- (BOOL)appendWaterMark:(UIImage *)waterImg relativeRect:(CGRect)relativeRect{
    if (!waterImg) {
        return NO;
    }
    
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEImageMixCommand *command = [[WAAVSEImageMixCommand alloc] initWithComposition:composition];
            command.imageBg = NO;
            command.image = waterImg;
            [command imageLayerRectWithVideoSize:^CGRect(CGSize videoSize) {
                CGFloat height = 0;
                if (relativeRect.size.height) {
                    height = videoSize.height * relativeRect.size.height;
                }else{
                    height = videoSize.width * relativeRect.size.width * waterImg.size.height / waterImg.size.width;
                }
                return CGRectMake(videoSize.width * relativeRect.origin.x,videoSize.height * relativeRect.origin.y,videoSize.width * relativeRect.size.width, height);
            }];
            [command performWithAsset:composition.totalEditComposition];
        }
 
    });
    
    return YES;
}

- (BOOL)appendImages:(NSURL *)imagesUrl relativeRect:(CGRect)relativeRect{
    if (!imagesUrl) { return NO; }
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        CGImageSourceRef gifSource = CGImageSourceCreateWithURL((CFURLRef)imagesUrl, NULL);
        CGFloat gifWidth;
        CGFloat gifHeight;
        // CFBridgingRelease Moves a non-Objective-C pointer to Objective-C and also transfers ownership to ARC.
        // CFBridgingRetain Casts an Objective-C pointer to a Core Foundation pointer and also transfers ownership to the caller.
        NSDictionary *dict = (NSDictionary*)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(gifSource, 0, NULL));
        gifWidth = [[dict valueForKey:(NSString*)kCGImagePropertyPixelWidth] floatValue];
        gifHeight = [[dict valueForKey:(NSString*)kCGImagePropertyPixelHeight] floatValue];
        if (gifSource) { CFRelease(gifSource); }
        
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEImageMixCommand *command = [[WAAVSEImageMixCommand alloc] initWithComposition:composition];
            command.imageBg = NO;
            command.fileUrl = imagesUrl;
            [command imageLayerRectWithVideoSize:^CGRect(CGSize videoSize) {
                CGFloat height = 0;
                if (relativeRect.size.height) {
                    height = videoSize.height * relativeRect.size.height;
                }else{
                    height = videoSize.width * relativeRect.size.width * gifHeight / gifWidth;
                }
                return CGRectMake(videoSize.width * relativeRect.origin.x,videoSize.height * relativeRect.origin.y,videoSize.width * relativeRect.size.width, height);
            }];
            [command performWithAsset:composition.totalEditComposition];
        }
    });
    return YES;
}

- (BOOL)gearBoxWithScale:(CGFloat)scale{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEGearboxCommand *gearBox =  [[WAAVSEGearboxCommand alloc] initWithComposition:composition];
            [gearBox performWithAsset:composition.totalEditComposition scale:scale];
        }
    });
    return YES;
}

- (BOOL)gearBoxTimeByScaleArray:(NSArray<WAAVSEGearboxCommandModel *> *)scaleArray{
    if (!scaleArray.count) {
        return NO;
    }

    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        for (WAEditComposition *composition in self.workSpace) {
           
            WAAVSEGearboxCommand *gearBox =  [[WAAVSEGearboxCommand alloc] initWithComposition:composition];
            [gearBox performWithAsset:composition.totalEditComposition models:scaleArray];
        }
    });
    
    return YES;
}

- (BOOL)replaceSoundBySoundPath:(NSString *)soundPath{
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:soundPath]) {
        return NO;
    }
    
    AVAsset *soundAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:soundPath] options:nil];
    if (!soundAsset.playable) {
        return NO;
    }
    
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEReplaceSoundCommand *replaceCommand = [[WAAVSEReplaceSoundCommand alloc] initWithComposition:composition];
            [replaceCommand performWithAsset:composition.totalEditComposition replaceAsset:soundAsset];
        }
    });
    
    
    return YES;
}

- (BOOL)dubbedSoundBySoundPath:(NSString *)soundPath{
    
    return [self dubbedSoundBySoundPath:soundPath volume:0.5 mixVolume:0.5 insertTime:0];
}

- (BOOL)dubbedSoundBySoundPath:(NSString *)soundPath volume:(CGFloat)volume mixVolume:(CGFloat)mixVolume insertTime:(CGFloat)insetDuration{
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:soundPath]) {
        return NO;
    }
    
    AVAsset *soundAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:soundPath] options:nil];
    if (!soundAsset.playable) {
        return NO;
    }
    
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEDubbedCommand *command = [[WAAVSEDubbedCommand alloc] initWithComposition:composition];
            command.insertTime = CMTimeMakeWithSeconds(insetDuration, composition.totalEditComposition.duration.timescale);
            command.audioVolume = volume;
            command.mixVolume = mixVolume;
            [command performWithAsset:composition.totalEditComposition mixAsset:soundAsset];
        }
    });
    
    return YES;
}

- (BOOL)extractVideoSound{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self commitCompostionToWorkspace];
        
        for (WAEditComposition *composition in self.workSpace) {
            WAAVSEExtractSoundCommand *command = [[WAAVSEExtractSoundCommand alloc] initWithComposition:composition];
            [command performWithAsset:composition.totalEditComposition];
        }
    });
    
    return YES;
}

#pragma mark video edit

- (void)syncFinishEditByFilePath:(NSString *)filePath complete:(void (^)(NSError *))complete{
    [self syncFinishEditByFilePath:filePath progress:nil complete:complete];
}

- (void)asyncFinishEditByFilePath:(NSString *)filePath complete:(void (^)(NSError *))complete{
    [self asyncFinishEditByFilePath:filePath progress:nil complete:complete];
}

- (void)syncFinishEditByFilePath:(NSString *)filePath progress:(void (^)(float))progress complete:(void (^)(NSError *))complete{
    
    if ([[NSThread currentThread] isMainThread]) {
        NSAssert(NO, @"You shouldn't make it in main thread!");
    }
    // runSynchronously 大部分都是在 proocessingQueue. 只有这里才是 ContextQueue, 而这正是调用了 sync 的方法.
    runSynchronouslyOnVideoBoxContextQueue(^{
        [self finishEditByFilePath:filePath progress:progress complete:complete];
    });
}

- (void)asyncFinishEditByFilePath:(NSString *)filePath progress:(void (^)(float))progress complete:(void (^)(NSError *))complete{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self finishEditByFilePath:filePath progress:progress complete:complete];
    });
}

- (void)cancelEdit{
    runSynchronouslyOnVideoBoxProcessingQueue(^{
        self.cancel = YES;
        if (self.exportCommand.exportSession.status == AVAssetExportSessionStatusExporting) {
            [self.exportCommand.exportSession cancelExport];
            NSLog(@"%s",__func__);
        }
    });
}

- (void)clean{
    runAsynchronouslyOnVideoBoxContextQueue(^{
        [self __internalClean];
    });
}

// 一个全方位的重置工作.
- (void)__internalClean{
    for (NSString *tmpPath in self.tmpVideoSpace) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        }
    }
    self.cacheComposition = nil;
    [self.tmpVideoSpace removeAllObjects];
    [self.workSpace removeAllObjects];
    [self.composeSpace removeAllObjects];
    self.composeCount = 0;
    self.progress = nil;
    self.editorComplete = nil;
    if (_progressLink) {
        [_progressLink invalidate];
         _progressLink = nil;
    }
    self.filePath = nil;
    self.tmpPath = nil;
    self.directCompostionIndex = 0;
    
}

#pragma mark private

- (void)commitCompostionToComposespace{
    if (!self.workSpace.count) { return; }
    // workspace的最后一个compostion可寻求合并
    WAEditComposition *currentComposition = [self.workSpace lastObject];
    for (int i = 0; i < self.workSpace.count - 1; i++) {
        [self.composeSpace addObject:self.workSpace[i]];
    }
    [self.workSpace removeAllObjects];
    if (!currentComposition.videoEditComposition &&
        !currentComposition.audioEditComposition &&
        self.composeSpace.count == self.directCompostionIndex) { // 可以直接合并
        if (self.composeSpace.count > 0) {
            WAEditComposition *compositon = [self.composeSpace lastObject];
            WAAVSEVideoMixCommand *mixCommand = [[WAAVSEVideoMixCommand alloc] initWithComposition:compositon];
            [mixCommand performWithAsset:compositon.totalEditComposition mixAsset:(AVAsset *)currentComposition.totalEditComposition];
        }else{
            self.directCompostionIndex = self.composeSpace.count;
            [self.composeSpace addObject:currentComposition];
        }
    }else{
         [self.composeSpace addObject:currentComposition];
    }

}

// 最后输出工作.
- (void)processVideoByComposition:(WAEditComposition *)composition{
    
    NSString *filePath = self.filePath;
    if(self.composeSpace.count != 1 || self.tmpVideoSpace.count){
        self.tmpPath = filePath = [self tmpVideoFilePath]; // 如果, 要输出的不止一个, 就是要全部输出后最后合并.
    }
    
    // 这里需要逐帧扫描
    if (self.videoQuality &&
        self.composeCount == 1 &&
        self.tmpVideoSpace.count == 0 &&
        !composition.videoEditComposition) {
        WAAVSECommand *command = [[WAAVSECommand alloc] initWithComposition:composition];
        [command performWithAsset:composition.totalEditComposition];
        [command performVideoCompopsition];
    }
    
    WAAVSEExportCommand *exportCommand = [[WAAVSEExportCommand alloc] initWithComposition:composition];
    exportCommand.videoQuality = self.videoQuality;
    self.exportCommand = exportCommand;
    [exportCommand performSaveByPath:filePath];

    if (self.progress && !_progressLink) {
        _progressLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        if (@available(iOS 10.0, *)) {
            _progressLink.preferredFramesPerSecond = 10;
        }else{
            _progressLink.frameInterval = 6;
        }
        [_progressLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)successToProcessCurrentCompostion{
    [self.composeSpace removeObjectAtIndex:0];
    [self.tmpVideoSpace addObject:self.tmpPath];
    
    if (self.composeSpace.count > 0) {
        [self processVideoByComposition:self.composeSpace.firstObject];
    }else{
        // 所有视频输出完成, 要做最后的合并操作.
        self.tmpPath = nil;
        WAAVSEVideoMixCommand *mixComand = [WAAVSEVideoMixCommand new];
        NSMutableArray *assetAry = [NSMutableArray array];
        for (NSString *filePath in self.tmpVideoSpace) {
            [assetAry addObject:[AVAsset assetWithURL:[NSURL fileURLWithPath:filePath]]];
        }
        [mixComand performWithAssets:assetAry];
        if (self.videoQuality) { // 需要逐帧对画面处理
            [mixComand performVideoCompopsition];
        }
        mixComand.editComposition.presetName = self.presetName;
        mixComand.editComposition.videoQuality = self.videoQuality;
        
        WAAVSEExportCommand *exportCommand = [[WAAVSEExportCommand alloc] initWithComposition:mixComand.editComposition];
        exportCommand.videoQuality = self.videoQuality;
        self.exportCommand = exportCommand;
        [exportCommand performSaveByPath:self.filePath];
       
    }
}


- (NSString *)tmpVideoFilePath{
    return [_tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.mp4",[NSDate timeIntervalSinceReferenceDate]]];
}

// 更新进度. 根据 composeCount 来进行计算.
- (void)displayLinkCallback:(CADisplayLink *)link{
    if (self.progress && self.exportCommand) {
        if (self.composeCount == 1) {
            self.progress(1.0 / self.composeCount * (self.composeCount - self.composeSpace.count) + 1.0 / self.composeCount * self.exportCommand.exportSession.progress);
        }else{
            self.progress(1.0 / self.composeCount * (self.composeCount - self.composeSpace.count - 1) + 1.0 / self.composeCount * self.exportCommand.exportSession.progress);
        }
       
    }
}

#pragma mark - End

- (void)AVEditorCompleteNotification:(NSNotification *)notification{
    runAsynchronouslyOnVideoBoxProcessingQueue(^{
        if ([[notification name] isEqualToString:WAAVSEExportCommandCompletionNotification] &&
            self.exportCommand == notification.object) {
            NSError *error = [notification.userInfo objectForKey:WAAVSEExportCommandError];
            if (self.cancel) {
                error = [NSError errorWithDomain:AVFoundationErrorDomain code:-10000 userInfo:@{NSLocalizedFailureReasonErrorKey:@"User cancel process!"}];
            }
            if (error) {
                [self failToProcessVideo:error];
            }else{
                if(!self.tmpPath){// 没有 self.tmpPath, 代表着就一个视频要合成.
                    [self successToProcessVideo];
                }else{
                    [self successToProcessCurrentCompostion];
                }
            }
        }
    });
}

- (void)failToProcessVideo:(NSError *)error{
    // 清理失败文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
    }
    
    if (self.editorComplete) {
        self.editorComplete(error);
    }
    
    [self __internalClean];
    
    if (self.suspend) {
        self.suspend = NO;
        /*
         Calling this function decrements the suspension count of a suspended dispatch queue or dispatch event source object. While the count is greater than zero, the object remains suspended. When the suspension count returns to zero, any blocks submitted to the dispatch queue or any events observed by the dispatch source while suspended are delivered.

         With one exception, each call to dispatch_resume must balance a call to dispatch_suspend. New dispatch event source objects returned by dispatch_source_create have a suspension count of 1 and must be resumed before any events are delivered. This approach allows your application to fully configure the dispatch event source object prior to delivery of the first event. In all other cases, it is undefined to call dispatch_resume more times than dispatch_suspend, which would result in a negative suspension count.
         */
        dispatch_resume(_videoBoxContextQueue);
    }
}

- (void)successToProcessVideo{
    if (self.editorComplete) {
        // 这里, 相当于一个 get 操作. 复制现有值.
        void (^editorComplete)(NSError *error) = self.editorComplete;
        dispatch_async(dispatch_get_main_queue(), ^{
            editorComplete(nil);
        });
    }
    [self __internalClean];
    if (self.suspend) {
        self.suspend = NO;
        dispatch_resume(_videoBoxContextQueue);
    }
}

// 能来到这一步, 就代表着, 之前的 Command 已经执行完了, 也就是说, 对于视频的编辑, 已经做完了. 该输出了.
- (void)finishEditByFilePath:(NSString *)filePath progress:(void (^)(float progress))progress complete:(void (^)(NSError *error))complete{
    [self commitCompostionToWorkspace]; // 这个调用, 就是为了导到 Composespace 中去
    [self commitCompostionToComposespace];
    
    if (!self.composeSpace.count) {
        complete([NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorNoDataCaptured userInfo:nil]);
        return;
    }
    
    self.filePath = filePath;
    self.editorComplete = complete;
    self.progress = progress;
    self.composeCount = self.composeSpace.count;
    
    if (self.composeCount != 1) { // 代表需要将compose里的视频生成后再合为一个
        self.composeCount ++;
    }
    
    runSynchronouslyOnVideoBoxProcessingQueue(^{
        self.suspend = YES; // 这就是一个标志位, 标志的需要进行 _videoBoxContextQueue 的重启操作.
        dispatch_suspend(_videoBoxContextQueue); // 不做视频的编辑工作了, 开始做输出操作. 这就是一个消费者生成者问题.
        if (self.cancel) {
            [self failToProcessVideo:[NSError errorWithDomain:AVFoundationErrorDomain code:-10000 userInfo:@{NSLocalizedFailureReasonErrorKey:@"User cancel process!"}]];
            return ;
        }else{
            [self processVideoByComposition:self.composeSpace.firstObject];
            return ;
        }
    });
}

#pragma mark getter and setter
- (void)setRatio:(WAVideoExportRatio)ratio{
    
    if (self.workSpace.count) {
        return;
    }
    
    _ratio = ratio;
    switch (self.ratio) {
        case WAVideoExportRatio640x480:
            self.presetName = AVAssetExportPreset640x480;
            break;
        case WAVideoExportRatio960x540:
            self.presetName = AVAssetExportPreset960x540;
            break;
        case WAVideoExportRatio1280x720:
            self.presetName = AVAssetExportPreset1280x720;
            break;
        case WAVideoExportRatioHighQuality:
            self.presetName = AVAssetExportPresetHighestQuality;
            break;
        case WAVideoExportRatioMediumQuality:
            self.presetName = AVAssetExportPresetMediumQuality;
            break;
        case WAVideoExportRatioLowQuality:
            self.presetName = AVAssetExportPresetLowQuality;
            break;
        default:
            break;
    }
}


@end
