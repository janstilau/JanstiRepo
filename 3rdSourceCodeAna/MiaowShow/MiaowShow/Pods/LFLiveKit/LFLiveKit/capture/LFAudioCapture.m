//
//  LFAudioCapture.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/1.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFAudioCapture.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NSString *const LFAudioComponentFailedToCreateNotification = @"LFAudioComponentFailedToCreateNotification";

@interface LFAudioCapture ()

@property (nonatomic, assign) AudioComponentInstance    componetInstance;
@property (nonatomic, assign) AudioComponent            component;
@property (nonatomic, strong) dispatch_queue_t       taskQueue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) LFLiveAudioConfiguration *configuration;

@end

@implementation LFAudioCapture

#pragma mark -- LiftCycle
// LFLiveAudioConfiguration 就是自定义的一个配置类, 具体的作用要到这里来提现.
/*
 AVAudioSession app 和 操作系统的中间类.
 default Session
 * Audio playback is supported, but audio recording is disallowed
 * setting the Ring/Silent switch to silent mode silences any audio being played by the app.
 * In iOS, when the device is locked, the app's audio is silenced
 * When the app plays audio, any other background audio is silenced.
 
 Category: defines how the app intends to use audio.  you set the category before activating the session
 AVAudioSessionCategoryAmbient 代表着这个 app 的声音不重要, 其他 app 的声音可以和你的 app 的声音进行混合, 如果静音或者锁屏就不能播放音乐. 默认选项
 AVAudioSessionCategorySoloAmbient 如果静音或者锁屏就不能播放音乐, 但是别的 app 如果是 nonmixable 的话, 不能和你进行混合.
 AVAudioSessionCategoryPlayback 代表播放音乐是你的 app 核心. 静音或者锁屏还可以播放音乐. 如果想要后台播放, UIBackgroundModes 需要加入 audio. 你的 app 是 nonmixable
 AVAudioSessionCategoryRecord 录音, 会让所有的音乐输出停止, 主要session 处于 active 的过程中,录音必须要用户设置权限.
 AVAudioSessionCategoryPlayAndRecord 一边录音一边播放音乐, 例如网络电话. 如果静音或者锁屏还可以播放音乐. 为的就是同时进行录音和播放音乐. 默认是 nonmixable, 注意, nonmixable 的可以用 AVAudioSessionCategoryOptionMixWithOthers 改变行为. 录音需要用户权限.
 AVAudioSessionCategoryMultiRoute 需要多音频有很多了解采用.
 
 Modes: specialize the behavior of an audio session category.
没有仔细看.
 - setCategory:mode:options:error: 苹果建议用这个方法, 将 category 和选项一并进行设置.
 
 Activate your audio session with its category and mode configuration.
 If another active audio session has higher priority than yours (for example, a phone call), and neither audio session allows mixing, attempting to activate your audio session fails. Deactivating an audio session that has running audio objects will stop the running audio objects, deactivate the session, and a AVAudioSessionErrorCodeIsBusy error will be returned.
 
 - (void)activateWithOptions:(AVAudioSessionActivationOptions)options completionHandler:(void (^)(BOOL activated, NSError *error))handler;
 Use this method to play long-form audio
 This method asynchronously activates the audio session. The system calls the completion handler as soon as the session has successfully activated or if the activation fails.
 
 recordPermission
 - requestRecordPermission:
 Starting with iOS 10.0, apps that access any of the device's microphones must declare their intent to do so. This is done by including the NSMicrophoneUsageDescription key and a corresponding purpose string in your app's Info.plist. When the system prompts the user to allow access, the purpose string is displayed as part of the alert.
 
otherAudioPlaying
 有没有别的 app 正在播放音乐.
 */
- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)configuration{
    if(self = [super init]){
        _configuration = configuration;
        self.isRunning = NO;
        // 这是一个串行 queue
        self.taskQueue = dispatch_queue_create("com.youku.Laifeng.audioCapture.Queue", NULL);
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        // kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation 这里感觉设错了, 应该是 No 的时候设置.
        [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleRouteChange:)
                                                     name: AVAudioSessionRouteChangeNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
        
        NSError *error = nil;
        
        // 可以混合.
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        
        // video Recored
        [session setMode:AVAudioSessionModeVideoRecording error:&error];
        
        if (![session setActive:YES error:&error]) {
            [self handleAudioComponentCreationFailure];
        }
        
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        
        self.component = AudioComponentFindNext(NULL, &acd);
        
        OSStatus status = noErr;
        status = AudioComponentInstanceNew(self.component, &_componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        
        // 下面一大部分没看懂.
        UInt32 flagOne = 1;
        
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
        
        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = _configuration.audioSampleRate;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        desc.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *)(self);
        cb.inputProc = handleInputBuffer;
        status = AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
        status = AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
        
        status = AudioUnitInitialize(self.componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        // 没看懂截止.
        
        // 设置采样率, 这里是用枚举代替的数字. 采样频率是指计算机每秒钟采集多少个信号样本
        [session setPreferredSampleRate:_configuration.audioSampleRate error:nil];
        [session setActive:YES error:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    dispatch_sync(self.taskQueue, ^{
        if(self.componetInstance){
            // stop 并且释放了.
            AudioOutputUnitStop(self.componetInstance);
            AudioComponentInstanceDispose(self.componetInstance);
            self.componetInstance = nil;
            self.component = nil;
        }
    });
}

#pragma mark -- Setter
- (void)setRunning:(BOOL)running{
    if(_running == running) return;
    _running = running;
    if(_running){
        dispatch_async(self.taskQueue, ^{
            self.isRunning = YES;
            NSLog(@"MicrophoneSource: startRunning");
            // 从这个注释看, self.componetInstance 里面都是话筒的输入.
            AudioOutputUnitStart(self.componetInstance);
        });
    }else{
        self.isRunning = NO;
    }
}

#pragma mark -- CustomMethod
- (void)handleAudioComponentCreationFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:LFAudioComponentFailedToCreateNotification object:nil];
    });
}

#pragma mark -- NSNotification
- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSession *session = [ AVAudioSession sharedInstance ];
    NSString* seccReason = @"";
    NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            seccReason = @"The route changed when the device woke up from sleep.";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            seccReason = @"The output route was overridden by the app.";
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            seccReason = @"The category of the session object changed.";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            seccReason = @"The previous audio output path is no longer available.";
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            seccReason = @"A preferred new audio output path is now available.";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            seccReason = @"The reason for the change is unknown.";
            break;
    }
    AVAudioSessionPortDescription *input = [[session.currentRoute.inputs count]?session.currentRoute.inputs:nil objectAtIndex:0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {
        
    }
}

// 在打断的开始和结尾, 进行了 stop 和 start
- (void)handleInterruption:(NSNotification *)notification {
    NSInteger reason = 0;
    NSString* reasonStr = @"";
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        //Posted when an audio interruption occurs.
        reason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            if (self.isRunning) {
                dispatch_sync(self.taskQueue, ^{
                    NSLog(@"MicrophoneSource: stopRunning");
                    AudioOutputUnitStop(self.componetInstance);
                });
            }
        }
        
        if (reason == AVAudioSessionInterruptionTypeEnded) {
            reasonStr = @"AVAudioSessionInterruptionTypeEnded";
            NSNumber* seccondReason = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] ;
            switch ([seccondReason integerValue]) {
                case AVAudioSessionInterruptionOptionShouldResume:
                    if (self.isRunning) {
                        dispatch_async(self.taskQueue, ^{
                            NSLog(@"MicrophoneSource: stopRunning");
                            AudioOutputUnitStart(self.componetInstance);
                        });
                    }
                    // Indicates that the audio session is active and immediately ready to be used. Your app can resume the audio operation that was interrupted.
                    break;
                default:
                    break;
            }
        }
        
    };
    NSLog(@"handleInterruption: %@ reason %@",[notification name], reasonStr);
}

#pragma mark -- CallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        LFAudioCapture *source = (__bridge LFAudioCapture *)inRefCon;
        if(!source) return -1;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
        
        OSStatus status = AudioUnitRender(source.componetInstance,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        
        if (!source.isRunning) {
            dispatch_sync(source.taskQueue, ^{
                NSLog(@"MicrophoneSource: stopRunning");
                AudioOutputUnitStop(source.componetInstance);
            });
            
            return status;
        }
        
        if (source.muted) {
            for (int i = 0; i < buffers.mNumberBuffers; i++) {
                AudioBuffer ab = buffers.mBuffers[i];
                memset(ab.mData, 0, ab.mDataByteSize);
            }
        }
        
        if(!status) {
            if(source.delegate && [source.delegate respondsToSelector:@selector(captureOutput:audioBuffer:)]){
                [source.delegate captureOutput:source audioBuffer:buffers];
            }
        }
        return status;
    }
}

@end
