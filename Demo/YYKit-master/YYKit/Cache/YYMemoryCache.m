
#import "YYMemoryCache.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <pthread.h>

#if __has_include("YYDispatchQueuePool.h")
#import "YYDispatchQueuePool.h"
#endif

#ifdef YYDispatchQueuePool_h
static inline dispatch_queue_t YYMemoryCacheGetReleaseQueue() {
    return YYDispatchQueueGetForQOS(NSQualityOfServiceUtility);
}
#else
static inline dispatch_queue_t YYMemoryCacheGetReleaseQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
}
#endif

/*
 这个类就很好的体现了, 链表和哈希表配合使用的场景.
 链表来维持顺序, 而哈希表则用来维护快速查找的功能.
 哈希表中, 存储的是下面的这个节点, 这个节点有着前驱和后继, 所有在通过哈希表取得一个节点之后, 可以快速的操作链表.
 所以, 这个节点是一个控制数据, 其中的 key, value 是业务数据, 两个指针, cost, time 都是控制数据.
 真正进行数据结构的修改, 完全建立在链表的操作之上, 哈希表的存储和删除操作, 内嵌到链表的操作过程之中.
 之所以这样做, 是因为这个数据结构, 暴露出去的更多的应该是顺序功能.
 */

/**
 A node in linked map.
 Typically, you should not use this class directly.
 */
@interface _YYLinkedMapNode : NSObject {
    @package
    __unsafe_unretained _YYLinkedMapNode *_prev; // retained by dic
    __unsafe_unretained _YYLinkedMapNode *_next; // retained by dic
    id _key; // key
    id _value; // value
    NSUInteger _cost; // 记录自己的 cost
    NSTimeInterval _time; // 记录自己的 time
}
@end

@implementation _YYLinkedMapNode
@end

/**
 LinkedMap 能够很好的体现出, 这个数据结构到底是干什么的.
 
 链表用于维护顺序, 哈希表用于 O1 的时间复杂度的实现.
 插入删除操作是建立在链表的基础上, 在维护链表的顺序的同时, 进行哈希表数据结构的维护.
 查值操作是建立在哈希表的基础上,  首先根据哈希表找到节点, 然后根据节点的 pre, next 指针操作链表.
 */
@interface _YYLinkedMap : NSObject {
    @package
    CFMutableDictionaryRef _dic; // 哈希表, 用于维护 O1 的时间复杂度.
    NSUInteger _totalCost; // 类内部维护的值, 在相关方法更新数据. // 在每次更新数据的时候, 维护着这个值, 不然就要遍历所有的节点进行相加了.
    NSUInteger _totalCount; // 类内部维护的值, 在相关方法更新数据. // 在每次更新数据的时候, 维护着这个值, 不然就要遍历所有的节点进行相加了.
    _YYLinkedMapNode *_head; // MRU, do not change it directly
    _YYLinkedMapNode *_tail; // LRU, do not change it directly
    BOOL _releaseOnMainThread;
    BOOL _releaseAsynchronously;
}

/// Insert a node at head and update the total cost.
/// Node and node.key should not be nil.
- (void)insertNodeAtHead:(_YYLinkedMapNode *)node;

/// Bring a inner node to header.
/// Node should already inside the dic.
- (void)bringNodeToHead:(_YYLinkedMapNode *)node;

/// Remove a inner node and update the total cost.
/// Node should already inside the dic.
- (void)removeNode:(_YYLinkedMapNode *)node;

/// Remove tail node if exist.
- (_YYLinkedMapNode *)removeTailNode;

/// Remove all node in background queue.
- (void)removeAll;

@end


@implementation _YYLinkedMap

- (instancetype)init {
    self = [super init];
    // 之所以用这样的一个类, 而不是 NSMutableDict, 是为了key在进行存储的时候, 不进行 copy 操作. 在作者看来, Cache 的操作引入 copy, 耗费性能.
    _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    _releaseOnMainThread = NO;
    _releaseAsynchronously = YES;
    return self;
}

- (void)dealloc {
    // CF 的内存管理.
    CFRelease(_dic);
}

// 函数名已经很明显的显示了自己的意义. 在这个函数里面, 没有进行了安全性的校验. 或者可以这样说, 安全性的校验, 是在这个函数的调用之前, 应该由调用者进行安全性的校验.
- (void)insertNodeAtHead:(_YYLinkedMapNode *)node {
    // 哈希表操作, 为了确保 O1 的查询效率.
    CFDictionarySetValue(_dic, (__bridge const void *)(node->_key), (__bridge const void *)(node));
    // 累加值
    _totalCost += node->_cost;
    _totalCount++;
    // 链表操作.
    if (_head) { // 前插
        node->_next = _head;
        _head->_prev = node;
        _head = node;
    } else { // 头结点设置.
        _head = _tail = node;
    }
}

// 更新节点位置, 在这个节点被命中的时候调用.
- (void)bringNodeToHead:(_YYLinkedMapNode *)node {
    if (_head == node) return; // 头节点, 无需操作
    
    if (_tail == node) { //尾节点, 更新尾节点的数据
        _tail = node->_prev;
        _tail->_next = nil;
    } else { //其他节点, 更新数据
        node->_next->_prev = node->_prev;
        node->_prev->_next = node->_next;
    }
    node->_next = _head; // node 变为头结点.
    node->_prev = nil;
    _head->_prev = node;
    _head = node;
}

// 方法里面没有进行安全验证, 安全责任交给调用者.
- (void)removeNode:(_YYLinkedMapNode *)node {
    // 哈希表操作
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(node->_key));
    // 累加值的操作.
    _totalCost -= node->_cost;
    _totalCount--;
    // 链表操作.
    if (node->_next) node->_next->_prev = node->_prev;
    if (node->_prev) node->_prev->_next = node->_next;
    if (_head == node) _head = node->_next;
    if (_tail == node) _tail = node->_prev;
}

// 在进行 trim 的时候调用这个方法.
// 可以使用上面的 removeNode 方法, 但是这里直接写节点的操作要高效的多.
// 根据 LRU 的方法, 在进行删除操作的时候, 是从尾部开始.
// 这里也是为什么要进行存储 tail 了, 有了 tail, 直接根据 tail 指针进行操作, 不然就只能从头遍历.
- (_YYLinkedMapNode *)removeTailNode {
    if (!_tail) return nil;
    _YYLinkedMapNode *tail = _tail;
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(_tail->_key));
    _totalCost -= _tail->_cost;
    _totalCount--;
    if (_head == _tail) {
        _head = _tail = nil;
    } else {
        _tail = _tail->_prev;
        _tail->_next = nil;
    }
    return tail;
}

// 在这里做自己的多线程处理, 调用者可以放心的调用.
- (void)removeAll {
    _totalCost = 0;
    _totalCount = 0;
    // 链表的操作清楚很简单. 简简单单的将头指针, 尾指针进行删除就可以了.
    _head = nil;
    _tail = nil;
    if (CFDictionaryGetCount(_dic) == 0) { return; }
        
    // 对于这种多线程操作, 通过 holder 保存当前值, 是很通用的做法.
    CFMutableDictionaryRef holder = _dic;
    // 首先将 _dic 重置到一个新的量.
    _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (_releaseAsynchronously) { // 如果是异步就 dispatch_async,
        dispatch_queue_t queue = _releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            CFRelease(holder); // hold and release in specified queue
        });
    } else if (_releaseOnMainThread && !pthread_main_np()) { // 如果是同步, 也要受 _releaseOnMainThread 的影响, 所以在不是主线程的时候, 也要 dispatch_async
        dispatch_async(dispatch_get_main_queue(), ^{
            CFRelease(holder); // hold and release in specified queue
        });
    } else { // 同步释放.
        CFRelease(holder);
    }
}

@end



@implementation YYMemoryCache {
    pthread_mutex_t _lock; // 这里做了线程的保护相关工作.
    _YYLinkedMap *lruLinkMap; // 真正的存储对象.
    dispatch_queue_t _trimQueue;
}

#pragma mark - public

- (instancetype)init {
    self = super.init;
    pthread_mutex_init(&_lock, NULL);
    lruLinkMap = [_YYLinkedMap new];
    _trimQueue = dispatch_queue_create("com.ibireme.cache.memory", DISPATCH_QUEUE_SERIAL);
    
    _countLimit = NSUIntegerMax;
    _costLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _autoTrimInterval = 5.0;
    _shouldRemoveAllObjectsOnMemoryWarning = YES;
    _shouldRemoveAllObjectsWhenEnteringBackground = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidReceiveMemoryWarningNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self _trimRecursively]; // 这里, 调用这个方法, 仅仅是为了启动这个定时器.
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [lruLinkMap removeAll];
    pthread_mutex_destroy(&_lock);
}

// 每5秒, 调用一个 _trimInBackground, 而 _trimInBackground 是向队列里面提交一个任务. 任务必然还是一项一项执行的. 因为 _trimQueue 是一个串行队列, 不会出现多个 trim 同时执行的情况.
- (void)_trimRecursively {
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_autoTrimInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self) return;
        [self _trimInBackground];
        [self _trimRecursively]; // 自己调用自己, 完成定时操作. 因为是 DISPATCH_QUEUE_SERIAL queue, 所以是顺序执行.
    });
}

- (void)_trimInBackground {
    dispatch_async(_trimQueue, ^{
        // 这个调用有先后顺序, 有可能上面的操作让下面的操作条件完成了, 所以在每个函数开始都要做判断.
        [self _trimToCost:self->_costLimit];
        [self _trimToCount:self->_countLimit];
        [self _trimToAge:self->_ageLimit];
    });
}

// 这里, 之所以 costLimit 被传入过来了, 是因为 Public 方法里面, 调用了这个方法.
- (void)_trimToCost:(NSUInteger)costLimit {
    BOOL finish = NO;
    // 临界区设置的非常小, 保证线程的执行.
    pthread_mutex_lock(&_lock);
    if (costLimit == 0) {
        [lruLinkMap removeAll];
        finish = YES;
    } else if (lruLinkMap->_totalCost <= costLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return; // 剪枝处理.
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) { // 通过这种方式, 逐步的删除元素.
        if (pthread_mutex_trylock(&_lock) == 0) { // tryLock, 为了不影响其他业务, 这样在其他的业务中, lock 的优先级会高.
            if (lruLinkMap->_totalCost > costLimit) {
                _YYLinkedMapNode *node = [lruLinkMap removeTailNode]; // 在这个操作的内部, 会进行 _totalCost 数值的更新. 从而影响到了 while 的判断.
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) { // 上面的操作, 会将数据在 LRU 中进行删除, 但是没有真正的进行释放. 而释放的操作, 在这里.
        dispatch_queue_t queue = lruLinkMap->_releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // 这里的调用, 仅仅是为了能够在 queue 中进行对象的释放工作.
        });
    }
}

// 这里, 和 上面的函数基本做法一致.
- (void)_trimToCount:(NSUInteger)countLimit {
    BOOL finish = NO;
    pthread_mutex_lock(&_lock);
    if (countLimit == 0) {
        [lruLinkMap removeAll];
        finish = YES;
    } else if (lruLinkMap->_totalCount <= countLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock) == 0) {
            if (lruLinkMap->_totalCount > countLimit) {
                _YYLinkedMapNode *node = [lruLinkMap removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = lruLinkMap->_releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

// 和上面的函数基本一直, 不过是从 tail 判断的依据是最后节点的 time 值.
- (void)_trimToAge:(NSTimeInterval)ageLimit {
    BOOL finish = NO;
    NSTimeInterval now = CACurrentMediaTime();
    pthread_mutex_lock(&_lock);
    if (ageLimit <= 0) {
        [lruLinkMap removeAll];
        finish = YES;
    } else if (!lruLinkMap->_tail || (now - lruLinkMap->_tail->_time) <= ageLimit) {
        // 因为 LRU 的链表, 所以, 如果尾结点的 time 符合了限制条件, 那么就能够认为是已经达到了条件.
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock) == 0) {
            // 相应的, 这里的判断条件, 也就变成了尾结点的 time 进行的判断.
            if (lruLinkMap->_tail && (now - lruLinkMap->_tail->_time) > ageLimit) {
                _YYLinkedMapNode *node = [lruLinkMap removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = lruLinkMap->_releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

// shouldRemoveAllObjectsOnMemoryWarning, didReceiveMemoryWarningBlock 的配置, 在这里发挥了作用
- (void)_appDidReceiveMemoryWarningNotification {
    if (self.didReceiveMemoryWarningBlock) {
        self.didReceiveMemoryWarningBlock(self);
    }
    if (self.shouldRemoveAllObjectsOnMemoryWarning) {
        [self removeAllObjects];
    }
}
// shouldRemoveAllObjectsWhenEnteringBackground, didEnterBackgroundBlock 的配置, 在这里发挥了作用
- (void)_appDidEnterBackgroundNotification {
    if (self.didEnterBackgroundBlock) {
        self.didEnterBackgroundBlock(self);
    }
    if (self.shouldRemoveAllObjectsWhenEnteringBackground) {
        [self removeAllObjects];
    }
}

// 多线程环境下, 加锁. 所有对于类的内部状态的改变和存储, 都要进行加锁.
// 多线程环境下, get 操作不要直接返回值, 而是需要一个 holder 的概念.
// 这里, 如果是一个复杂的值的返回, 就很容易出问题, 比如一个很大的struce 的拷贝工作. 因为线程的切换, 前后数据不统一. 所以, 多线程环境下返回值, 一定也要加锁.
- (NSUInteger)totalCount {
    pthread_mutex_lock(&_lock);
    NSUInteger count = lruLinkMap->_totalCount;
    pthread_mutex_unlock(&_lock);
    return count;
}

- (NSUInteger)totalCost {
    pthread_mutex_lock(&_lock);
    NSUInteger totalCost = lruLinkMap->_totalCost;
    pthread_mutex_unlock(&_lock);
    return totalCost;
}

- (BOOL)releaseOnMainThread {
    pthread_mutex_lock(&_lock);
    BOOL releaseOnMainThread = lruLinkMap->_releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
    return releaseOnMainThread;
}

- (void)setReleaseOnMainThread:(BOOL)releaseOnMainThread {
    pthread_mutex_lock(&_lock);
    lruLinkMap->_releaseOnMainThread = releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
}

- (BOOL)releaseAsynchronously {
    pthread_mutex_lock(&_lock);
    BOOL releaseAsynchronously = lruLinkMap->_releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
    return releaseAsynchronously;
}

- (void)setReleaseAsynchronously:(BOOL)releaseAsynchronously {
    pthread_mutex_lock(&_lock);
    lruLinkMap->_releaseAsynchronously = releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
}

// 通过 LRU 的 dic 做判断
- (BOOL)containsObjectForKey:(id)key {
    if (!key) return NO;
    pthread_mutex_lock(&_lock);
    BOOL contains = CFDictionaryContainsKey(lruLinkMap->_dic, (__bridge const void *)(key));
    pthread_mutex_unlock(&_lock);
    return contains;
}


- (id)objectForKey:(id)key {
    if (!key) return nil;
    pthread_mutex_lock(&_lock);
    _YYLinkedMapNode *node = CFDictionaryGetValue(lruLinkMap->_dic, (__bridge const void *)(key));
    if (node) {
        node->_time = CACurrentMediaTime(); // 更新访问时间, 更改LRU的位置.
        [lruLinkMap bringNodeToHead:node];
    }
    pthread_mutex_unlock(&_lock);
    return node ? node->_value : nil;
}

- (void)setObject:(id)object forKey:(id)key {
    [self setObject:object forKey:key withCost:0]; // 如果没有指定 cost, 那么就是 cost 为 0.
}

// 设置操作, 加锁,
- (void)setObject:(id)object forKey:(id)key withCost:(NSUInteger)cost {
    if (!key) return;
    if (!object) { // 如果是 nil, 就进行删除操作, 这已经是现在比较标准的设计的思路了.
        [self removeObjectForKey:key];
        return;
    }
    pthread_mutex_lock(&_lock);
    _YYLinkedMapNode *node = CFDictionaryGetValue(lruLinkMap->_dic, (__bridge const void *)(key));
    NSTimeInterval now = CACurrentMediaTime();
    if (node) {
        // 更新已有 node 的数据. 其实就是 dict 中值得替换. 把 node 提到表头.
        lruLinkMap->_totalCost -= node->_cost;
        lruLinkMap->_totalCost += cost;
        node->_cost = cost;
        node->_time = now;
        node->_value = object;
        [lruLinkMap bringNodeToHead:node];
    } else {
        // 新插入 node 的数据
        node = [_YYLinkedMapNode new];
        node->_cost = cost;
        node->_time = now;
        node->_key = key;
        node->_value = object;
        [lruLinkMap insertNodeAtHead:node];
    }
    if (lruLinkMap->_totalCost > _costLimit) { // 如果超出界限了, 就进行缩减操作. 可以看到, 这是一个异步操作.
        dispatch_async(_trimQueue, ^{
            [self trimToCost:_costLimit];
        });
    }
    if (lruLinkMap->_totalCount > _countLimit) { // 如果个数超出了. 那么久就减去最后一个 node.
        _YYLinkedMapNode *node = [lruLinkMap removeTailNode];
        if (lruLinkMap->_releaseAsynchronously) {
            dispatch_queue_t queue = lruLinkMap->_releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class]; //hold and release in queue 这里通过这种方式, 延缓了释放.
            });
        } else if (lruLinkMap->_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class]; //hold and release in queue
            });
        }
    }
    pthread_mutex_unlock(&_lock);
}

- (void)removeObjectForKey:(id)key {
    if (!key) return;
    pthread_mutex_lock(&_lock);
    _YYLinkedMapNode *node = CFDictionaryGetValue(lruLinkMap->_dic, (__bridge const void *)(key));
    if (node) {
        [lruLinkMap removeNode:node];
        if (lruLinkMap->_releaseAsynchronously) {
            dispatch_queue_t queue = lruLinkMap->_releaseOnMainThread ? dispatch_get_main_queue() : YYMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class]; //hold and release in queue
            });
        } else if (lruLinkMap->_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class]; //hold and release in queue
            });
        }
    }
    pthread_mutex_unlock(&_lock);
}

- (void)removeAllObjects {
    pthread_mutex_lock(&_lock);
    [lruLinkMap removeAll];
    pthread_mutex_unlock(&_lock);
}

- (void)trimToCount:(NSUInteger)count {
    if (count == 0) {
        [self removeAllObjects];
        return;
    }
    [self _trimToCount:count];
}

- (void)trimToCost:(NSUInteger)cost {
    [self _trimToCost:cost];
}

- (void)trimToAge:(NSTimeInterval)age {
    [self _trimToAge:age];
}

- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}

@end
