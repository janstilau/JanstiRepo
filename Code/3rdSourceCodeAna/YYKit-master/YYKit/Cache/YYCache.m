#import "YYCache.h"
#import "YYMemoryCache.h"
#import "YYDiskCache.h"

@implementation YYCache

- (instancetype) init {
    NSLog(@"Use \"initWithName\" or \"initWithPath\" to create YYCache instance.");
    // 这里直接报错要好一些.
    return [self initWithPath:@""];
}

// 因为, diskCache 是建立在文件的基础上. 所以, name 的作用主要是用来在特定的目录下生成一个路径, 然后根据这个路径, 创建真正进行存储的 diskCache 对象.
- (instancetype)initWithName:(NSString *)name {
    if (name.length == 0) return nil;
    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:name];
    return [self initWithPath:path];
}

// 作者所说的, 可能会导致数据紊乱, 应该指的是DiskCache.
- (instancetype)initWithPath:(NSString *)path {
    if (path.length == 0) return nil;
    
    YYDiskCache *diskCache = [[YYDiskCache alloc] initWithPath:path];
    if (!diskCache) return nil;
    
    NSString *name = [path lastPathComponent];
    YYMemoryCache *memoryCache = [YYMemoryCache new];
    memoryCache.name = name;
    
    self = [super init];
    // YYCache 中, 真正做存储管理的, 还是 YYMemoryCache 和 diskCache.
    _name = name;
    _diskCache = diskCache;
    _memoryCache = memoryCache;
    return self;
}

// 所有的类工厂方法, 仅仅就是在方法内部进行实例的生成而已.
+ (instancetype)cacheWithName:(NSString *)name {
	return [[self alloc] initWithName:name];
}

+ (instancetype)cacheWithPath:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

// 代理到真正的 cache 独享中.
- (BOOL)containsObjectForKey:(NSString *)key {
    return [_memoryCache containsObjectForKey:key] || [_diskCache containsObjectForKey:key];
}

// 作者的各种方法, 都提供了同步异步两种方式进行了处理. 异步的方案都不是很复杂.
- (void)containsObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key, BOOL contains))block {
    if (!block) return;
    
    // 首先是内存缓存判断, 因为内存缓存非常快, 所以直接是在调用线程使用了时候, 在GCD中是用.
    if ([_memoryCache containsObjectForKey:key]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(key, YES);
        });
    } else  {
        // 如果内存缓存没有命中, 直接调用 disk 缓存的方法,  disk 缓存中, 直接定义了异步的方法.
        [_diskCache containsObjectForKey:key withBlock:block];
    }
}

- (id<NSCoding>)objectForKey:(NSString *)key {
    // 首先, 判断内存缓存能否命中.
    id<NSCoding> object = [_memoryCache objectForKey:key];
    if (!object) {
        // 然后判断, disk 缓存是否命中, 并且更新内存缓存.
        object = [_diskCache objectForKey:key];
        if (object) {
            [_memoryCache setObject:object forKey:key];
        }
    }
    return object;
}

- (void)objectForKey:(NSString *)key withBlock:(void (^)(NSString *key, id<NSCoding> object))block {
    if (!block) return;
    id<NSCoding> object = [_memoryCache objectForKey:key];
    if (object) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(key, object);
        });
    } else {
        // 直接利用了 disk 缓存的方法, 并将传递过来的回调, 组织到参数 block 中.
        [_diskCache objectForKey:key withBlock:^(NSString *key, id<NSCoding> object) {
            if (object && ![_memoryCache objectForKey:key]) {
                [_memoryCache setObject:object forKey:key];
            }
            block(key, object);
        }];
    }
}

// 双向保存
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key {
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key];
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key withBlock:(void (^)(void))block {
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key withBlock:block];
}

// 双向删除.
- (void)removeObjectForKey:(NSString *)key {
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key))block {
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key withBlock:block];
}

- (void)removeAllObjects {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjects];
}

- (void)removeAllObjectsWithBlock:(void(^)(void))block {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithBlock:block];
}


- (void)removeAllObjectsWithProgressBlock:(void(^)(int removedCount, int totalCount))progress
                                 endBlock:(void(^)(BOOL error))end {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithProgressBlock:progress endBlock:end];
}

// 以上的所有操作, 都是内存瞬间完成, 而 disk 的则调用相应方法, 逐步删除
- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}

@end
