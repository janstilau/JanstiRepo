/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCacheOperation.h"
#import "objc/runtime.h"

static char loadOperationKey;

// key is strong, value is weak because operation instance is retained by SDWebImageManager's runningOperations property
// we should use lock to keep thread-safe because these method may not be acessed from main queue
typedef NSMapTable<NSString *, id<SDWebImageOperation>> SDOperationsDictionary;

@implementation UIView (WebCacheOperation)

/**
 All opertaion will be store in a dict related with this view.
 */
- (SDOperationsDictionary *)sd_operationDictionary {
    @synchronized(self) {
        SDOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
        if (operations) {
            return operations;
        }
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}

- (nullable id<SDWebImageOperation>)sd_imageLoadOperationForKey:(nullable NSString *)key  {
    id<SDWebImageOperation> operation;
    if (key) {
        SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
        @synchronized (self) {
            operation = [operationDictionary objectForKey:key];
        }
    }
    return operation;
}


- (void)sd_setImageLoadOperation:(nullable id<SDWebImageOperation>)operation forKey:(nullable NSString *)key {
    if (!key) { return; }
    [self sd_cancelImageLoadOperationWithKey:key];
    if (!operation) { return; }
    SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
    @synchronized (self) {
        [operationDictionary setObject:operation forKey:key];
    }
    
}

/**
 The previous operation is canceled, so there is no need to check current image url and uiview cached url  when image is downloaded.
 In MC Customed ImageSetter, all action are cached in a dict, when a download is done, every related action will be performed no matter whether the url is current uiview url or not. And in the end, the real setImage action, will check for that.
 */
- (void)sd_cancelImageLoadOperationWithKey:(nullable NSString *)key {
    if (!key) { return; }
    // Cancel in progress downloader from queue
    SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
    id<SDWebImageOperation> operation;
    /**
     @synchronized is acceptable, In this class, thread safe action is numberable.
     */
    @synchronized (self) {
        operation = [operationDictionary objectForKey:key];
    }
    if (!operation) { return; }
    if ([operation conformsToProtocol:@protocol(SDWebImageOperation)]) {
        [operation cancel];
    }
    @synchronized (self) {
        [operationDictionary removeObjectForKey:key];
    }
}

@end
