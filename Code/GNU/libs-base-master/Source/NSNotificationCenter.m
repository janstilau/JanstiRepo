#import "common.h"
#define	EXPOSE_NSNotificationCenter_IVARS	1
#import "Foundation/NSNotification.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSOperation.h"
#import "Foundation/NSThread.h"
#import "GNUstepBase/GSLock.h"

static NSZone	*_zone = 0;

// 这里,  Qt 版本需要增加一个线程的概念. 因为 Qt 里面线程是一个很麻烦的概念.
@interface	GSNotification : NSNotification
{
@public
    NSString	*_name; // 名称
    id		_poster; // 发送者
    NSDictionary	*_info; // 数据
}
@end

@implementation GSNotification

static Class concrete = 0;

+ (NSNotification*) notificationWithName: (NSString*)name
                                  object: (id)object
                                userInfo: (NSDictionary*)info
{
    GSNotification	*n;
    
    n = (GSNotification*)NSAllocateObject(self, 0, NSDefaultMallocZone());
    n->_name = [name copyWithZone: [self zone]];
    n->_poster = TEST_RETAIN(object);
    n->_info = TEST_RETAIN(info);
    return AUTORELEASE(n);
}

@end


struct	NCTbl;		/* Notification Center Table structure	*/

/*
 * Each struct is placed in one LinkedList,
 * as keyed by the NAME/OBJECT parameters.
 * If 'next' is 0 then the observation is unused (ie it has been
 * removed from, or not yet added to  any list).  The end of a
 * list is marked by 'next' being set to 'ENDOBS'.
 */

typedef	struct	Observer {
    id		observer;	/* Object to receive message.	*/
    SEL		selector;	/* Method selector.		*/
    struct Observer	*next;		/* Next item in linked list.	*/
    int		retained;	/* Retain count for structure.	*/
    struct NCTbl	*link;		/* Pointer back to chunk table	*/
} Observation;

#define	ENDOBS	((Observation*)-1)

static inline NSUInteger doHash(BOOL shouldHash, NSString* key)
{
    if (key == nil)
    {
        return 0;
    }
    else if (NO == shouldHash)
    {
        return (NSUInteger)(uintptr_t)key;
    }
    else
    {
        return [key hash];
    }
}

static inline BOOL doEqual(BOOL shouldHash, NSString* key1, NSString* key2)
{
    if (key1 == key2)
    {
        return YES;
    }
    else if (NO == shouldHash)
    {
        return NO;
    }
    else
    {
        return [key1 isEqualToString: key2];
    }
}

/*
 * Setup for inline operation on arrays of Observers.
 */
static void listFree(Observation *list);

/* Observations have retain/release counts managed explicitly by fast
 * function calls.
 */
static void obsRetain(Observation *o);
static void obsFree(Observation *o);


#define GSI_ARRAY_TYPES	0
#define GSI_ARRAY_TYPE	Observation*
#define GSI_ARRAY_RELEASE(A, X)   obsFree(X.ext)
#define GSI_ARRAY_RETAIN(A, X)    obsRetain(X.ext)

#include "GNUstepBase/GSIArray.h"

#define GSI_MAP_RETAIN_KEY(M, X)
#define GSI_MAP_RELEASE_KEY(M, X) ({if (YES == M->extra) RELEASE(X.obj);})
#define GSI_MAP_HASH(M, X)        doHash(M->extra, X.obj)
#define GSI_MAP_EQUAL(M, X,Y)     doEqual(M->extra, X.obj, Y.obj)
#define GSI_MAP_RETAIN_VAL(M, X)
#define GSI_MAP_RELEASE_VAL(M, X)

#define GSI_MAP_KTYPES GSUNION_OBJ|GSUNION_NSINT
#define GSI_MAP_VTYPES GSUNION_PTR
#define GSI_MAP_VEXTRA Observation*
#define	GSI_MAP_EXTRA	BOOL

#include "GNUstepBase/GSIMap.h"

/*
 * An NC table is used to keep track of memory allocated to store
 * Observation structures. When an Observation is removed from the
 * notification center, it's memory is returned to the free list of
 * the chunk table, rather than being released to the general
 * memory allocation system.  This means that, once a large numbner
 * of observers have been registered, memory usage will never shrink
 * even if the observers are removed.  On the other hand, the process
 * of adding and removing observers is speeded up.
 *
 * As another minor aid to performance, we also maintain a cache of
 * the map tables used to keep mappings of notification objects to
 * lists of Observations.  This lets us avoid the overhead of creating
 * and destroying map tables when we are frequently adding and removing
 * notification observations.
 *
 * Performance is however, not the primary reason for using this
 * structure - it provides a neat way to ensure that observers pointed
 * to by the Observation structures are not seen as being in use by
 * the garbage collection mechanism.
 */
#define	CHUNKSIZE	128
#define	CACHESIZE	16
typedef struct NCTbl {
    Observation		*wildcard;	/* Get ALL messages.		*/
    GSIMapTable		nameless;	/* Get messages for any name.	*/
    GSIMapTable		named;		/* Getting named messages only.	*/
    unsigned		lockCount;	/* Count recursive operations.	*/
    NSRecursiveLock	*_lock;		/* Lock out other threads.	*/
    Observation		*freeList;
    Observation		**chunks;
    unsigned		numChunks;
    GSIMapTable		cache[CACHESIZE];
    unsigned short	chunkIndex;
    unsigned short	cacheIndex;
} NCTable;

#define	TABLE		((NCTable*)_table)
#define	WILDCARD	(TABLE->wildcard)
#define	NAMELESS	(TABLE->nameless)
#define	NAMED		(TABLE->named)
#define	LOCKCOUNT	(TABLE->lockCount)

static Observation *
createNewObservation(NCTable *table, SEL selector, id receiver)
{
    Observation	*result;
    
    if (table->freeList == 0)
    {
        Observation	*block;
        
        if (table->chunkIndex == CHUNKSIZE)
        {
            unsigned	size;
            
            table->numChunks++;
            
            size = table->numChunks * sizeof(Observation*);
            table->chunks = (Observation**)NSReallocateCollectable(
                                                               table->chunks, size, NSScannedOption);
            
            size = CHUNKSIZE * sizeof(Observation);
            table->chunks[table->numChunks - 1]
            = (Observation*)NSAllocateCollectable(size, 0);
            table->chunkIndex = 0;
        }
        block = table->chunks[table->numChunks - 1];
        table->freeList = &block[table->chunkIndex];
        table->chunkIndex++;
        table->freeList->link = 0;
    }
    
    result = table->freeList;
    table->freeList = (Observation*)result->link;
    result->link = (void*)table;
    result->retained = 0;
    result->next = 0;
    
    result->selector = selector;
    result->observer = receiver;
    
    return result;
}

static GSIMapTable	createNewMap(NCTable *t)
{
    if (t->cacheIndex > 0)
    {
        return t->cache[--t->cacheIndex];
    }
    else
    {
        GSIMapTable	m;
        
        m = NSAllocateCollectable(sizeof(GSIMapTable_t), NSScannedOption);
        GSIMapInitWithZoneAndCapacity(m, _zone, 2);
        return m;
    }
}

static void	mapFree(NCTable *t, GSIMapTable m)
{
    if (t->cacheIndex < CACHESIZE)
    {
        t->cache[t->cacheIndex++] = m;
    }
    else
    {
        GSIMapEmptyMap(m);
        NSZoneFree(NSDefaultMallocZone(), (void*)m);
    }
}

static void endNCTable(NCTable *t)
{
    unsigned		i;
    GSIMapEnumerator_t	e0;
    GSIMapNode		n0;
    Observation		*l;
    
    TEST_RELEASE(t->_lock);
    
    /*
     * Free observations without notification names or numbers.
     */
    listFree(t->wildcard);
    
    /*
     * Free lists of observations without notification names.
     */
    e0 = GSIMapEnumeratorForMap(t->nameless);
    n0 = GSIMapEnumeratorNextNode(&e0);
    while (n0 != 0)
    {
        l = (Observation*)n0->value.ptr;
        n0 = GSIMapEnumeratorNextNode(&e0);
        listFree(l);
    }
    GSIMapEmptyMap(t->nameless);
    NSZoneFree(NSDefaultMallocZone(), (void*)t->nameless);
    
    /*
     * Free lists of observations keyed by name and observer.
     */
    e0 = GSIMapEnumeratorForMap(t->named);
    n0 = GSIMapEnumeratorNextNode(&e0);
    while (n0 != 0)
    {
        GSIMapTable		m = (GSIMapTable)n0->value.ptr;
        GSIMapEnumerator_t	e1 = GSIMapEnumeratorForMap(m);
        GSIMapNode		n1 = GSIMapEnumeratorNextNode(&e1);
        
        n0 = GSIMapEnumeratorNextNode(&e0);
        
        while (n1 != 0)
        {
            l = (Observation*)n1->value.ptr;
            n1 = GSIMapEnumeratorNextNode(&e1);
            listFree(l);
        }
        GSIMapEmptyMap(m);
        NSZoneFree(NSDefaultMallocZone(), (void*)m);
    }
    GSIMapEmptyMap(t->named);
    NSZoneFree(NSDefaultMallocZone(), (void*)t->named);
    
    for (i = 0; i < t->numChunks; i++)
    {
        NSZoneFree(NSDefaultMallocZone(), t->chunks[i]);
    }
    for (i = 0; i < t->cacheIndex; i++)
    {
        GSIMapEmptyMap(t->cache[i]);
        NSZoneFree(NSDefaultMallocZone(), (void*)t->cache[i]);
    }
    NSZoneFree(NSDefaultMallocZone(), t->chunks);
    NSZoneFree(NSDefaultMallocZone(), t);
}

static NCTable *newNCTable(void)
{
    NCTable	*t;
    
    t = (NCTable*)NSAllocateCollectable(sizeof(NCTable), NSScannedOption);
    t->chunkIndex = CHUNKSIZE;
    t->wildcard = ENDOBS;
    
    t->nameless = NSAllocateCollectable(sizeof(GSIMapTable_t), NSScannedOption);
    t->named = NSAllocateCollectable(sizeof(GSIMapTable_t), NSScannedOption);
    GSIMapInitWithZoneAndCapacity(t->nameless, _zone, 16);
    GSIMapInitWithZoneAndCapacity(t->named, _zone, 128);
    t->named->extra = YES;        // This table retains keys
    
    t->_lock = [NSRecursiveLock new];
    return t;
}

static inline void lockNCTable(NCTable* t)
{
    [t->_lock lock];
    t->lockCount++;
}

static inline void unlockNCTable(NCTable* t)
{
    t->lockCount--;
    [t->_lock unlock];
}

static void obsFree(Observation *o)
{
    NSCAssert(o->retained >= 0, NSInternalInconsistencyException);
    if (o->retained-- == 0)
    {
        NCTable	*t = o->link;
        
        o->link = (NCTable*)t->freeList;
        t->freeList = o;
    }
}

static void obsRetain(Observation *o)
{
    o->retained++;
}

static void listFree(Observation *list)
{
    while (list != ENDOBS)
    {
        Observation	*o = list;
        
        list = o->next;
        o->next = 0;
        obsFree(o);
    }
}

/*
 *	NB. We need to explicitly set the 'next' field of any observation
 *	we remove to be zero so that, if it currently exists in an array
 *	of observations being posted, the posting code can notice that it
 *	has been removed from its linked list.
 *
 *	Also,
 */
static Observation *listPurge(Observation *list, id observer)
{
    Observation	*tmp;
    
    while (list != ENDOBS && list->observer == observer)
    {
        tmp = list->next;
        list->next = 0;
        obsFree(list);
        list = tmp;
    }
    if (list != ENDOBS)
    {
        tmp = list;
        while (tmp->next != ENDOBS)
        {
            if (tmp->next->observer == observer)
            {
                Observation	*next = tmp->next;
                
                tmp->next = next->next;
                next->next = 0;
                obsFree(next);
            }
            else
            {
                tmp = tmp->next;
            }
        }
    }
    return list;
}

/*
 * Utility function to remove all the observations from a particular
 * map table node that match the specified observer.  If the observer
 * is nil, then all observations are removed.
 * If the list of observations in the map node is emptied, the node is
 * removed from the map.
 */
static inline void
purgeMapNode(GSIMapTable map, GSIMapNode node, id observer)
{
    Observation	*list = node->value.ext;
    
    if (observer == 0)
    {
        listFree(list);
        GSIMapRemoveKey(map, node->key);
    }
    else
    {
        Observation	*start = list;
        
        list = listPurge(list, observer);
        if (list == ENDOBS)
        {
            /*
             * The list is empty so remove from map.
             */
            GSIMapRemoveKey(map, node->key);
        }
        else if (list != start)
        {
            /*
             * The list is not empty, but we have changed its
             * start, so we must place the new head in the map.
             */
            node->value.ext = list;
        }
    }
}

/* purgeCollected() returns a list of observations with any observations for
 * a collected observer removed.
 * purgeCollectedFromMapNode() does the same thing but also handles cleanup
 * of the map node containing the list if necessary.
 */
#define	purgeCollected(X)	(X)
#define purgeCollectedFromMapNode(X, Y) ((Observation*)Y->value.ext)


@interface GSNotificationBlockOperation : NSOperation
{
    NSNotification *_notification;
    GSNotificationBlock _block;
}

- (id) initWithNotification: (NSNotification *)notif 
                      block: (GSNotificationBlock)block;

@end

@implementation GSNotificationBlockOperation

- (id) initWithNotification: (NSNotification *)notif 
                      block: (GSNotificationBlock)block
{
    self = [super init];
    if (self == nil)
        return nil;
    
    ASSIGN(_notification, notif);
    _block = Block_copy(block);
    return self;
    
}

- (void) dealloc
{
    DESTROY(_notification);
    Block_release(_block);
    [super dealloc];
}

- (void) main
{
    CALL_BLOCK(_block, _notification);
}

@end

/*
 一个简单的包装, 使得 Block 这种可以直接添加到 NotificationCenter 里面
 */
@interface GSNotificationObserver : NSObject
{
    NSOperationQueue *_queue;
    GSNotificationBlock _block;
}

@end

@implementation GSNotificationObserver

- (id) initWithQueue: (NSOperationQueue *)queue 
               block: (GSNotificationBlock)block
{
    self = [super init];
    if (self == nil)
        return nil;
    
    ASSIGN(_queue, queue);
    _block = Block_copy(block);
    return self;
}

- (void) dealloc
{
    DESTROY(_queue);
    Block_release(_block);
    [super dealloc];
}

- (void) didReceiveNotification: (NSNotification *)notif
{
    if (_queue != nil)
    {
        GSNotificationBlockOperation *op = [[GSNotificationBlockOperation alloc]
                                            initWithNotification: notif block: _block];
        
        [_queue addOperation: op];
    }
    else
    {
        CALL_BLOCK(_block, notif);
    }
}

@end

/*
 这个类, 数据结构层面设计的太复杂.
 直接使用已有的数据结构进行缓存会好太多.
 */

@implementation NSNotificationCenter

static NSNotificationCenter *default_center = nil;

+ (void) initialize
{
    if (self == [NSNotificationCenter class])
    {
        default_center = [self alloc];
        [default_center init];
    }
}

+ (NSNotificationCenter*) defaultCenter
{
    return default_center;
}


/* Initializing. */

- (id) init
{
    if ((self = [super init]) != nil)
    {
        _table = newNCTable();
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}


- (void) addObserver: (id)observer
            selector: (SEL)selector
                name: (NSString*)name
              object: (id)object
{
    Observation	*list;
    Observation	*observation;
    GSIMapTable	nameConterpartMap;
    GSIMapNode	namedNotiObjectsMap;
    
    /*
     首先, 应该做防卫式判断. 全部删了.
     */
    
    lockNCTable(TABLE);
    
    observation = createNewObservation(TABLE, selector, observer);
    
    if (name)
    {
        /*
         首先, 根据名称, 找到对应通知名的存储结构.
         */
        namedNotiObjectsMap = GSIMapNodeForKey(NAMED, (GSIMapKey)(id)name);
        if (namedNotiObjectsMap == 0)
        {
            nameConterpartMap = createNewMap(TABLE);
            /*
             * As this is the first observation for the given name, we take a
             * copy of the name so it cannot be mutated while in the map.
             */
            name = [name copyWithZone: NSDefaultMallocZone()];
            GSIMapAddPair(NAMED, (GSIMapKey)(id)name, (GSIMapVal)(void*)nameConterpartMap);
            GS_CONSUMED(name)
        }
        else
        {
            nameConterpartMap = (GSIMapTable)namedNotiObjectsMap->value.ptr;
        }
        
        /*
         * Add the observation to the list for the correct object.
         */
        namedNotiObjectsMap = GSIMapNodeForSimpleKey(nameConterpartMap, (GSIMapKey)object);
        if (namedNotiObjectsMap == 0)
        {
            observation->next = ENDOBS;
            GSIMapAddPair(nameConterpartMap, (GSIMapKey)object, (GSIMapVal)observation);
        }
        else
        {
            list = (Observation*)namedNotiObjectsMap->value.ptr;
            observation->next = list->next;
            list->next = observation;
        }
    }
    else if (object)
    {
        namedNotiObjectsMap = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)object);
        if (namedNotiObjectsMap == 0)
        {
            observation->next = ENDOBS;
            GSIMapAddPair(NAMELESS, (GSIMapKey)object, (GSIMapVal)observation);
        }
        else
        {
            list = (Observation*)namedNotiObjectsMap->value.ptr;
            observation->next = list->next;
            list->next = observation;
        }
    }
    else
    {
        observation->next = WILDCARD;
        WILDCARD = observation;
    }
    
    unlockNCTable(TABLE);
}

/*
 * <p>Returns a new observer added to the notification center, in order to
 * observe the given notification name posted by an object or any object (if
 * the object argument is nil).</p>
 *
 * <p>For the name and object arguments, the constraints and behavior described
 * in -addObserver:name:selector:object: remain valid.</p>
 *
 * <p>For each notification received by the center, the observer will execute
 * the notification block. If the queue is not nil, the notification block is
 * wrapped in a NSOperation and scheduled in the queue, otherwise the block is
 * executed immediately in the posting thread.</p>
 */
- (id) addObserverForName: (NSString *)name 
                   object: (id)object
                    queue: (NSOperationQueue *)queue
               usingBlock: (GSNotificationBlock)block
{
    GSNotificationObserver *observer =
    [[GSNotificationObserver alloc] initWithQueue: queue block: block];
    
    /*
     Notification 的这种 target action 的方式, 已经是确定的了.
     为了让 BLOCK 也可以符合这种方式, 创建一个中间层进行适配.
     */
    [self addObserver: observer
             selector: @selector(didReceiveNotification:)
                 name: name
               object: object];
    
    return observer;
}

/**
 * Deregisters observer for notifications matching name and/or object.  If
 * either or both is nil, they act like wildcards.  The observer may still
 * remain registered for other notifications; use -removeObserver: to remove
 * it from all.  If observer is nil, the effect is to remove all registrees
 * for the specified notifications, unless both observer and name are nil, in
 * which case nothing is done.
 */
- (void) removeObserver: (id)observer
                   name: (NSString*)name
                 object: (id)object
{
    if (name == nil && object == nil && observer == nil)
        return;
    
    /*
     *	NB. The removal algorithm depends on an implementation characteristic
     *	of our map tables - while enumerating a table, it is safe to remove
     *	the entry returned by the enumerator.
     */
    
    lockNCTable(TABLE);
    
    if (name == nil && object == nil)
    {
        WILDCARD = listPurge(WILDCARD, observer);
    }
    
    if (name == nil)
    {
        GSIMapEnumerator_t	e0;
        GSIMapNode		n0;
        
        /*
         * First try removing all named items set for this object.
         */
        e0 = GSIMapEnumeratorForMap(NAMED);
        n0 = GSIMapEnumeratorNextNode(&e0);
        while (n0 != 0)
        {
            GSIMapTable		m = (GSIMapTable)n0->value.ptr;
            NSString		*thisName = (NSString*)n0->key.obj;
            
            n0 = GSIMapEnumeratorNextNode(&e0);
            if (object == nil)
            {
                GSIMapEnumerator_t	e1 = GSIMapEnumeratorForMap(m);
                GSIMapNode		n1 = GSIMapEnumeratorNextNode(&e1);
                
                /*
                 * Nil object and nil name, so we step through all the maps
                 * keyed under the current name and remove all the objects
                 * that match the observer.
                 */
                while (n1 != 0)
                {
                    GSIMapNode	next = GSIMapEnumeratorNextNode(&e1);
                    
                    purgeMapNode(m, n1, observer);
                    n1 = next;
                }
            }
            else
            {
                GSIMapNode	n1;
                
                /*
                 * Nil name, but non-nil object - we locate the map for the
                 * specified object, and remove all the items that match
                 * the observer.
                 */
                n1 = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
                if (n1 != 0)
                {
                    purgeMapNode(m, n1, observer);
                }
            }
            /*
             * If we removed all the observations keyed under this name, we
             * must remove the map table too.
             */
            if (m->nodeCount == 0)
            {
                mapFree(TABLE, m);
                GSIMapRemoveKey(NAMED, (GSIMapKey)(id)thisName);
            }
        }
        
        /*
         * Now remove unnamed items
         */
        if (object == nil)
        {
            e0 = GSIMapEnumeratorForMap(NAMELESS);
            n0 = GSIMapEnumeratorNextNode(&e0);
            while (n0 != 0)
            {
                GSIMapNode	next = GSIMapEnumeratorNextNode(&e0);
                
                purgeMapNode(NAMELESS, n0, observer);
                n0 = next;
            }
        }
        else
        {
            n0 = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)object);
            if (n0 != 0)
            {
                purgeMapNode(NAMELESS, n0, observer);
            }
        }
    }
    else
    {
        GSIMapTable		m;
        GSIMapEnumerator_t	e0;
        GSIMapNode		n0;
        
        /*
         * Locate the map table for this name.
         */
        n0 = GSIMapNodeForKey(NAMED, (GSIMapKey)((id)name));
        if (n0 == 0)
        {
            unlockNCTable(TABLE);
            return;		/* Nothing to do.	*/
        }
        m = (GSIMapTable)n0->value.ptr;
        
        if (object == nil)
        {
            e0 = GSIMapEnumeratorForMap(m);
            n0 = GSIMapEnumeratorNextNode(&e0);
            
            while (n0 != 0)
            {
                GSIMapNode	next = GSIMapEnumeratorNextNode(&e0);
                
                purgeMapNode(m, n0, observer);
                n0 = next;
            }
        }
        else
        {
            n0 = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
            if (n0 != 0)
            {
                purgeMapNode(m, n0, observer);
            }
        }
        if (m->nodeCount == 0)
        {
            mapFree(TABLE, m);
            GSIMapRemoveKey(NAMED, (GSIMapKey)((id)name));
        }
    }
    unlockNCTable(TABLE);
}

/**
 * Deregisters observer from all notifications.  This should be called before
 * the observer is deallocated.
 */
- (void) removeObserver: (id)observer
{
    if (observer == nil)
        return;
    
    [self removeObserver: observer name: nil object: nil];
}


/**
 * Private method to perform the actual posting of a notification.
 * Release the notification before returning, or before we raise
 * any exception ... to avoid leaks.
 */
- (void) _postAndRelease: (NSNotification*)notification
{
    Observation	*o;
    unsigned	count;
    NSString	*name = [notification name];
    id		object;
    GSIMapNode	n;
    GSIMapTable	m;
    GSIArrayItem	i[64];
    GSIArray_t	b;
    GSIArray	a = &b;
    
    if (name == nil)
    {
        RELEASE(notification);
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to post a notification with no name."];
    }
    object = [notification object];
    
    /*
     * Lock the table of observations while we traverse it.
     *
     * The table of observations contains weak pointers which are zeroed when
     * the observers get garbage collected.  So to avoid consistency problems
     * we disable gc while we copy all the observations we are interested in.
     * We use scanned memory in the array in the case where there are more
     * than the 64 observers we allowed room for on the stack.
     */
    GSIArrayInitWithZoneAndStaticCapacity(a, _zone, 64, i);
    lockNCTable(TABLE);
    
    /*
     * Find all the observers that specified neither NAME nor OBJECT.
     */
    for (o = WILDCARD = purgeCollected(WILDCARD); o != ENDOBS; o = o->next)
    {
        GSIArrayAddItem(a, (GSIArrayItem)o);
    }
    
    /*
     * Find the observers that specified OBJECT, but didn't specify NAME.
     */
    if (object)
    {
        n = GSIMapNodeForSimpleKey(NAMELESS, (GSIMapKey)object);
        if (n != 0)
        {
            o = purgeCollectedFromMapNode(NAMELESS, n);
            while (o != ENDOBS)
            {
                GSIArrayAddItem(a, (GSIArrayItem)o);
                o = o->next;
            }
        }
    }
    
    /*
     * Find the observers of NAME, except those observers with a non-nil OBJECT
     * that doesn't match the notification's OBJECT).
     */
    if (name)
    {
        n = GSIMapNodeForKey(NAMED, (GSIMapKey)((id)name));
        if (n)
        {
            m = (GSIMapTable)n->value.ptr;
        }
        else
        {
            m = 0;
        }
        if (m != 0)
        {
            /*
             * First, observers with a matching object.
             */
            n = GSIMapNodeForSimpleKey(m, (GSIMapKey)object);
            if (n != 0)
            {
                o = purgeCollectedFromMapNode(m, n);
                while (o != ENDOBS)
                {
                    GSIArrayAddItem(a, (GSIArrayItem)o);
                    o = o->next;
                }
            }
            
            if (object != nil)
            {
                /*
                 * Now observers with a nil object.
                 */
                n = GSIMapNodeForSimpleKey(m, (GSIMapKey)nil);
                if (n != 0)
                {
                    o = purgeCollectedFromMapNode(m, n);
                    while (o != ENDOBS)
                    {
                        GSIArrayAddItem(a, (GSIArrayItem)o);
                        o = o->next;
                    }
                }
            }
        }
    }
    
    /* Finished with the table ... we can unlock it,
     */
    unlockNCTable(TABLE);
    
    /*
     * Now send all the notifications.
     */
    count = GSIArrayCount(a);
    while (count-- > 0)
    {
        o = GSIArrayItemAtIndex(a, count).ext;
        if (o->next != 0)
        {
            NS_DURING
            {
                [o->observer performSelector: o->selector
                                  withObject: notification];
            }
            NS_HANDLER
            {
                NSLog(@"Problem posting notification: %@", localException);
            }
            NS_ENDHANDLER
        }
    }
    lockNCTable(TABLE);
    GSIArrayEmpty(a);
    unlockNCTable(TABLE);
    
    RELEASE(notification);
}


/**
 * Posts notification to all the observers that match its NAME and OBJECT.<br />
 * The GNUstep implementation calls -postNotificationName:object:userInfo: to
 * perform the actual posting.
 */
- (void) postNotification: (NSNotification*)notification
{
    if (notification == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Tried to post a nil notification."];
    }
    [self _postAndRelease: RETAIN(notification)];
}

/**
 * Creates and posts a notification using the
 * -postNotificationName:object:userInfo: passing a nil user info argument.
 */
- (void) postNotificationName: (NSString*)name
                       object: (id)object
{
    [self postNotificationName: name object: object userInfo: nil];
}

/**
 * The preferred method for posting a notification.
 * <br />
 * For performance reasons, we don't wrap an exception handler round every
 * message sent to an observer.  This means that, if one observer raises
 * an exception, later observers in the lists will not get the notification.
 */
- (void) postNotificationName: (NSString*)name
                       object: (id)object
                     userInfo: (NSDictionary*)info
{
    GSNotification	*notification;
    
    notification = (id)NSAllocateObject(concrete, 0, NSDefaultMallocZone());
    notification->_name = [name copyWithZone: [self zone]];
    notification->_poster = [object retain];
    notification->_info = [info retain];
    [self _postAndRelease: notification];
}

@end

