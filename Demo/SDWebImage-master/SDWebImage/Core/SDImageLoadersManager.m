/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageLoadersManager.h"
#import "SDWebImageDownloader.h"
#import "SDInternalMacros.h"

@interface SDImageLoadersManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t loadersLock;

@end

@implementation SDImageLoadersManager
{
    NSMutableArray<id<SDImageLoader>>* _imageLoaders;
}

+ (SDImageLoadersManager *)sharedManager {
    static dispatch_once_t onceToken;
    static SDImageLoadersManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[SDImageLoadersManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // initialize with default image loaders
        _imageLoaders = [NSMutableArray arrayWithObject:[SDWebImageDownloader sharedDownloader]];
        _loadersLock = dispatch_semaphore_create(1);
    }
    return self;
}

/*
 Get 函数的多线程访问的标准写法, 临时变量存储.
 */
- (NSArray<id<SDImageLoader>> *)loaders {
    SD_LOCK(self.loadersLock);
    NSArray<id<SDImageLoader>>* loaders = [_imageLoaders copy];
    SD_UNLOCK(self.loadersLock);
    return loaders;
}

- (void)setLoaders:(NSArray<id<SDImageLoader>> *)loaders {
    SD_LOCK(self.loadersLock);
    [_imageLoaders removeAllObjects];
    if (loaders.count) {
        [_imageLoaders addObjectsFromArray:loaders];
    }
    SD_UNLOCK(self.loadersLock);
}

#pragma mark - Loader Property

- (void)addLoader:(id<SDImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(SDImageLoader)]) {
        return;
    }
    SD_LOCK(self.loadersLock);
    [_imageLoaders addObject:loader];
    SD_UNLOCK(self.loadersLock);
}

- (void)removeLoader:(id<SDImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(SDImageLoader)]) {
        return;
    }
    SD_LOCK(self.loadersLock);
    [_imageLoaders removeObject:loader];
    SD_UNLOCK(self.loadersLock);
}

#pragma mark - SDImageLoader

/*
 这里, SDImageLoadersManager 也实现了 SDImageLoader 协议. 在 SDImageCacheManager 里面, 保存的 id<SDImageLoader> 其实是, SDImageLoader.
 SDImageLoadersManager, SDImageCachesManager 其实都是将任务分发到了各自的 loader 或者 cacher. 但是, 这两个 manager 里面都存储了多个对象, 可以根据策略的不同, 调度这些对象, 进行实际的任务执行.
 */

- (BOOL)canRequestImageForURL:(nullable NSURL *)url {
    NSArray<id<SDImageLoader>> *loaders = self.loaders;
    for (id<SDImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return YES;
        }
    }
    return NO;
}

- (id<SDWebImageOperation>)requestImageWithURL:(NSURL *)url
                                       options:(SDWebImageOptions)options
                                       context:(SDWebImageContext *)context
                                      progress:(SDImageLoaderProgressBlock)progressBlock
                                     completed:(SDImageLoaderCompletedBlock)completedBlock {
    if (!url) {
        return nil;
    }
    NSArray<id<SDImageLoader>> *loaders = self.loaders;
    for (id<SDImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader requestImageWithURL:url options:options context:context progress:progressBlock completed:completedBlock];
        }
    }
    return nil;
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    NSArray<id<SDImageLoader>> *loaders = self.loaders;
    for (id<SDImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    return NO;
}

@end
