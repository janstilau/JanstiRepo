//
//  SDImageCacheConfig.h
//  SDWebImage
//
//  Created by Bogdan on 09/09/16.
//  Copyright © 2016 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

/*
 很多很多的方法, 体统 options 这样的一个参数, 这个参数有什么作用呢. 控制流程, option 的意思就是选项. 但是, 只有这些值得定义是没有用的, 在相应的函数体里面, 还应该相应的操作.
 这些相应的操作的一般流程是, 执行到某个操作, 然后用 & 操作符读取一下传过来的 options 有没有对应的这个值, 如果有, 那么就执行某个特定的操作, 如果没有, 就怎么怎么样. 所以, 其实可以认为, 这个一个delegate. 只不过不是动态的调用 delegate 的方法, 而是在定义 options 的时候, 就决定了行为.
 */
@interface SDImageCacheConfig : NSObject

/**
 * Decompressing images that are downloaded and cached can improve performance but can consume lot of memory.
 * Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 *  disable iCloud backup [defaults to YES]
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * use memory cache [defaults to YES]
 */
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/**
 * The maximum length of time to keep an image in the cache, in seconds
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

@end
