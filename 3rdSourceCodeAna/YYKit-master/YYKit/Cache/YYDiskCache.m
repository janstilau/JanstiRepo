//
//  YYDiskCache.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/2/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYDiskCache.h"
#import "YYKVStorage.h"
#import "NSString+YYAdd.h"
#import "UIDevice+YYAdd.h"
#import <objc/runtime.h>
#import <time.h>

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

static const int extended_data_key;

/// Free disk space in bytes.
static int64_t _YYDiskSpaceFree() {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) return -1;
    int64_t space =  [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
    if (space < 0) space = -1;
    return space;
}


/// weak reference for all instances
static NSMapTable *_globalInstances;
static dispatch_semaphore_t _globalInstancesLock;

static void _YYDiskCacheInitGlobal() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _globalInstancesLock = dispatch_semaphore_create(1);
        _globalInstances = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    });
}

static YYDiskCache *_YYDiskCacheGetGlobal(NSString *path) {
    if (path.length == 0) return nil;
    _YYDiskCacheInitGlobal();
    dispatch_semaphore_wait(_globalInstancesLock, DISPATCH_TIME_FOREVER);
    id cache = [_globalInstances objectForKey:path];
    dispatch_semaphore_signal(_globalInstancesLock);
    return cache;
}

static void _YYDiskCacheSetGlobal(YYDiskCache *cache) {
    if (cache.path.length == 0) return;
    _YYDiskCacheInitGlobal();
    dispatch_semaphore_wait(_globalInstancesLock, DISPATCH_TIME_FOREVER);
    [_globalInstances setObject:cache forKey:cache.path];
    dispatch_semaphore_signal(_globalInstancesLock);
}

// 其实不是太明白, 为什么这里要用 C 语言进行缓存的处理. 因为

/*
 这个类, 主要是调用 YYKVStorage 的功能, 在各个 YYKVStorage 的功能之上, 增加了一些异步调用的方法.
 直接调用
 */

@implementation YYDiskCache {
    YYKVStorage *_kv; // 真正的存储对象.
    dispatch_semaphore_t _lock;
    dispatch_queue_t _asyncQueue;
}

// 一个简易的定时器, 不断的进行调用. 主要还是调用 _trimInBackground 方法, _trimRecursively 和 dispatch_after 作为定时的功能实现.
- (void)_trimRecursively {
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_autoTrimInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self) return;
        [self _trimInBackground];
        [self _trimRecursively];
    });
}

- (void)_trimInBackground {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        if (!self) return;
        Lock();
        [self _trimToCost:self.costLimit];
        [self _trimToCount:self.countLimit];
        [self _trimToAge:self.ageLimit];
        [self _trimToFreeDiskSpace:self.freeDiskSpaceLimit];
        Unlock();
    });
}

// 所有的操作, 都代理给了 _kv 进行处理.
- (void)_trimToCost:(NSUInteger)costLimit {
    if (costLimit >= INT_MAX) return;
    [_kv removeItemsToFitSize:(int)costLimit];
    
}

- (void)_trimToCount:(NSUInteger)countLimit {
    if (countLimit >= INT_MAX) return;
    [_kv removeItemsToFitCount:(int)countLimit];
}

- (void)_trimToAge:(NSTimeInterval)ageLimit {
    if (ageLimit <= 0) {
        [_kv removeAllItems];
        return;
    }
    long timestamp = time(NULL);
    if (timestamp <= ageLimit) return;
    long age = timestamp - ageLimit;
    if (age >= INT_MAX) return;
    [_kv removeItemsEarlierThanTime:(int)age];
}

- (void)_trimToFreeDiskSpace:(NSUInteger)targetFreeDiskSpace {
    if (targetFreeDiskSpace == 0) return;
    int64_t totalBytes = [_kv getItemsSize];
    if (totalBytes <= 0) return;
    int64_t diskFreeBytes = _YYDiskSpaceFree();
    if (diskFreeBytes < 0) return;
    int64_t needTrimBytes = targetFreeDiskSpace - diskFreeBytes;
    if (needTrimBytes <= 0) return;
    int64_t costLimit = totalBytes - needTrimBytes;
    if (costLimit < 0) costLimit = 0;
    [self _trimToCost:(int)costLimit];
}

- (NSString *)_filenameForKey:(NSString *)key {
    NSString *filename = nil;
    if (_customFileNameBlock) filename = _customFileNameBlock(key);
    if (!filename) filename = key.md5String; // 根据 MD5 来进行一次简单的加密操作.
    return filename;
}

- (void)_appWillBeTerminated {
    Lock();
    _kv = nil;
    Unlock();
}

#pragma mark - public

// 感觉作者, 在代码的存放位置这方面, 需要进行新的训练.
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYDiskCache init error" reason:@"YYDiskCache must be initialized with a path. Use 'initWithPath:' or 'initWithPath:inlineThreshold:' instead." userInfo:nil];
    return [self initWithPath:@"" inlineThreshold:0];
}

// 20K 的限制, 是作者根据自己的调试经验获得到的实验值.
- (instancetype)initWithPath:(NSString *)path {
    return [self initWithPath:path inlineThreshold:1024 * 20]; // 20KB
}

- (instancetype)initWithPath:(NSString *)path
             inlineThreshold:(NSUInteger)threshold {
    self = [super init];
    if (!self) return nil;
    
    YYDiskCache *globalCache = _YYDiskCacheGetGlobal(path);
    if (globalCache) return globalCache; // 这里, 对于不同的 path, 进行了缓存处理.
    
    YYKVStorageType type;
    if (threshold == 0) {
        type = YYKVStorageTypeFile;
    } else if (threshold == NSUIntegerMax) {
        type = YYKVStorageTypeSQLite;
    } else {
        type = YYKVStorageTypeMixed;
    }
    
    YYKVStorage *kv = [[YYKVStorage alloc] initWithPath:path type:type]; // 真正的存储的功能所在.
    if (!kv) return nil;
    
    _kv = kv;
    _path = path;
    _lock = dispatch_semaphore_create(1);
    _asyncQueue = dispatch_queue_create("com.ibireme.cache.disk", DISPATCH_QUEUE_CONCURRENT);
    _inlineThreshold = threshold;
    _countLimit = NSUIntegerMax;
    _costLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _freeDiskSpaceLimit = 0;
    _autoTrimInterval = 60;
    
    [self _trimRecursively]; // 启动定时器
    _YYDiskCacheSetGlobal(self);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appWillBeTerminated) name:UIApplicationWillTerminateNotification object:nil];
    return self;
}

// 将检测的功能, 代理给了 _kv
- (BOOL)containsObjectForKey:(NSString *)key {
    if (!key) return NO;
    // 在 _kv 中, 没有进行加锁的保护, 而是在这个类中进行的处理.
    Lock();
    BOOL contains = [_kv itemExistsForKey:key];
    Unlock();
    return contains;
}

// 异步的 containsObjectForKey 方法.
- (void)containsObjectForKey:(NSString *)key withBlock:(void(^)(NSString *key, BOOL contains))block {
    if (!block) return;
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{ // 在子线程, 进行 block 的回调处理.
        __strong typeof(_self) self = _self;
        BOOL contains = [self containsObjectForKey:key];
        block(key, contains);
    });
}

// 通过 _kv 进行值得读取, 在读取到了二进制数据之后, 做了解档的操作.
- (id<NSCoding>)objectForKey:(NSString *)key {
    if (!key) return nil;
    // 首先, 是通过 _kv 得到对应的 Item. 而这个 Item 是从数据库汇中通过 key 来获取到数据的.
    Lock();
    YYKVStorageItem *item = [_kv getItemForKey:key];
    Unlock();
    if (!item.value) return nil;
    // item.Value 里面存储的是二进制的数据, 这里要有一个归档接档的操作.
    id object = nil;
    if (_customUnarchiveBlock) {
        object = _customUnarchiveBlock(item.value);
    } else {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:item.value];
        }
        @catch (NSException *exception) {
            // nothing to do...
        }
    }
    // extendedData 也是被存储到了数据库中.
    // extendedData 的设计意图是, extendedData 的值, 不会在 OBJECT 的归档解档过程过程中, 而是通过关联对象, 进行关联.
    // 在正常的业务操作的时候, 通过关联对象进行读取. 在归档解档的时候, 也会把相应的关联数据放到数据库中.
    if (object && item.extendedData) {
        [YYDiskCache setExtendedData:item.extendedData toObject:object];
    }
    return object;
}

// 异步的 objectForKey 操作.
- (void)objectForKey:(NSString *)key withBlock:(void(^)(NSString *key, id<NSCoding> object))block {
    if (!block) return;
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        id<NSCoding> object = [self objectForKey:key];
        block(key, object);
    });
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key {
    if (!key) return;
    if (!object) { // set 方法里面, 对于 nil 的判断, 是一个通用的写法.
        [self removeObjectForKey:key];
        return;
    }
    
    NSData *extendedData = [YYDiskCache getExtendedDataFromObject:object];
    NSData *value = nil;
    // 首先, 把要进行存储的对象, 进行归档.
    if (_customArchiveBlock) {
        value = _customArchiveBlock(object);
    } else {
        @try {
            value = [NSKeyedArchiver archivedDataWithRootObject:object];
        }
        @catch (NSException *exception) {
            // nothing to do...
        }
    }
    if (!value) return;
    NSString *filename = nil;
    // 如果归档的数据的值超过了阈值, 那么就进行文件存储.
    // 注意, 文件存储的过程, 是在 _kv 内部进行的. 如果有 filename 的存在, 就是二进制文件存储到文件之中.
    // 在这个类中, 不会涉及到相应的存储工作.
    if (_kv.type != YYKVStorageTypeSQLite) {
        if (value.length > _inlineThreshold) {
            filename = [self _filenameForKey:key];
        }
    }
    
    // 最终, 还是调用了 _kv 的方法, 进行了真正的存储.
    Lock();
    [_kv saveItemWithKey:key value:value filename:filename extendedData:extendedData];
    Unlock();
}

// setObject 的异步方法.
// 可见, 所谓的异步方法, 就是在子线程调用同步方法, 然后执行回调就可以. 而在同步版本的方法里面, 增加了锁的加持, 所以可以安全的调用, 而不用担心线程问题.
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key withBlock:(void(^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self setObject:object forKey:key]; // 在  setObject forKey 中有着加锁操作
        if (block) block();
    });
}

// 直接是 _kv 的方法调用.
- (void)removeObjectForKey:(NSString *)key {
    if (!key) return;
    Lock();
    [_kv removeItemForKey:key];
    Unlock();
}

// removeObjectForKey 的异步方法.
- (void)removeObjectForKey:(NSString *)key withBlock:(void(^)(NSString *key))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self removeObjectForKey:key];
        if (block) block(key);
    });
}

// _kv 的方法调用.
- (void)removeAllObjects {
    Lock();
    [_kv removeAllItems];
    Unlock();
}

// _kv 的removeAll 的异步方法.
- (void)removeAllObjectsWithBlock:(void(^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self removeAllObjects];
        if (block) block();
    });
}

- (void)removeAllObjectsWithProgressBlock:(void(^)(int removedCount, int totalCount))progress
                                 endBlock:(void(^)(BOOL error))end {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        if (!self) {
            if (end) end(YES);
            return;
        }
        Lock();
        [_kv removeAllItemsWithProgressBlock:progress endBlock:end];
        Unlock();
    });
}

// 代理给 _kv
- (NSInteger)totalCount {
    Lock();
    int count = [_kv getItemsCount];
    Unlock();
    return count;
}

// totalCount 的异步方法.
- (void)totalCountWithBlock:(void(^)(NSInteger totalCount))block {
    if (!block) return;
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        NSInteger totalCount = [self totalCount];
        block(totalCount);
    });
}

// 代理给 _kv
- (NSInteger)totalCost {
    Lock();
    int count = [_kv getItemsSize];
    Unlock();
    return count;
}

// totalCost 的异步方法
- (void)totalCostWithBlock:(void(^)(NSInteger totalCost))block {
    if (!block) return;
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        NSInteger totalCost = [self totalCost];
        block(totalCost);
    });
}

- (void)trimToCount:(NSUInteger)count {
    Lock();
    [self _trimToCount:count];
    Unlock();
}

- (void)trimToCount:(NSUInteger)count withBlock:(void(^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self trimToCount:count];
        if (block) block();
    });
}

- (void)trimToCost:(NSUInteger)cost {
    Lock();
    [self _trimToCost:cost];
    Unlock();
}

- (void)trimToCost:(NSUInteger)cost withBlock:(void(^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self trimToCost:cost];
        if (block) block();
    });
}

- (void)trimToAge:(NSTimeInterval)age {
    Lock();
    [self _trimToAge:age];
    Unlock();
}

- (void)trimToAge:(NSTimeInterval)age withBlock:(void(^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_asyncQueue, ^{
        __strong typeof(_self) self = _self;
        [self trimToAge:age];
        if (block) block();
    });
}

+ (NSData *)getExtendedDataFromObject:(id)object {
    if (!object) return nil;
    return (NSData *)objc_getAssociatedObject(object, &extended_data_key);
}

+ (void)setExtendedData:(NSData *)extendedData toObject:(id)object {
    if (!object) return;
    objc_setAssociatedObject(object, &extended_data_key, extendedData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@:%@)", self.class, self, _name, _path];
    else return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _path];
}

- (BOOL)errorLogsEnabled {
    Lock();
    BOOL enabled = _kv.errorLogsEnabled;
    Unlock();
    return enabled;
}

- (void)setErrorLogsEnabled:(BOOL)errorLogsEnabled {
    Lock();
    _kv.errorLogsEnabled = errorLogsEnabled;
    Unlock();
}

@end
