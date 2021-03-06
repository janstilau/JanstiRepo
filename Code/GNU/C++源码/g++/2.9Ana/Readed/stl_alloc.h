#ifndef __SGI_STL_INTERNAL_ALLOC_H
#define __SGI_STL_INTERNAL_ALLOC_H

/*
 T 的作用, 仅仅是在 sizeof 中进行使用, 获取到 T 的大小, 然后和 Sizeof 相乘.
 真正的 Alloc, 也没有调用构造函数, 而是直接使用了 Alloc 的静态方法.
 */
template<class T, class Alloc>
class simple_alloc {
    
public:
    static T *allocate(size_t n)
    { return 0 == n? 0 : (T*) Alloc::allocate(n * sizeof (T)); }
    
    static T *allocate(void)
    { return (T*) Alloc::allocate(sizeof (T)); }
    
    static void deallocate(T *p, size_t n)
    { if (0 != n) Alloc::deallocate(p, n * sizeof (T)); }
    
    static void deallocate(T *p)
    { Alloc::deallocate(p, sizeof (T)); }
};

/*
 这里不太明白, 为什么用 enum 作为这些常量值的表示.
 */

enum {__ALIGN = 8};
enum {__MAX_BYTES = 128};
enum {__NFREELISTS = __MAX_BYTES/__ALIGN};

template <bool threads, int inst>
class __default_alloc_template {
    
private:
    
    static size_t ROUND_UP(size_t bytes) {
        return (((bytes) + __ALIGN-1) & ~(__ALIGN - 1));
    }
__PRIVATE:
    /*
     共用体, embedded pointer
     */
    union obj {
        union obj * free_list_link;
        char client_data[1];    /* The client sees this.        */
    };
private:
    /*
     free_list 就是那 16 个链表的控制中心, 每个节点上是一个链表. 每个链表, 控制着固定大小的块.
     */
    static obj * __VOLATILE free_list[__NFREELISTS];
    /*
     计算出, bytes 大小的空间, 应该在哪个链表上.
     */
    static  size_t FREELIST_INDEX(size_t bytes) {
        // 这种, (value+align-1)/align - 1 的方法, 经常用.
        return (((bytes) + __ALIGN-1)/__ALIGN - 1);
    }
    
    // Allocates a chunk for nobjs of size "size".  nobjs may be reduced
    // if it is inconvenient to allocate the requested number.
    static char *chunk_alloc(size_t size, int &nobjs);
    
    /*
     战备池的开始和结束
     */
    static char *start_free;
    static char *end_free;
    /*
     已经分配的内存的空间大小, 在 chunk_alloc 中, 如果需要申请新的内存, 会按照已分配的内存空间, 申请相同比例的额外空间, 用来减少后续 malloc 的次数.
     */
    static size_t heap_size;
    
# ifdef __STL_SGI_THREADS
    static volatile unsigned long __node_allocator_lock;
    static void __lock(volatile unsigned long *);
    static inline void __unlock(volatile unsigned long *);
# endif
    
# ifdef __STL_PTHREADS
    static pthread_mutex_t __node_allocator_lock;
# endif
    
# ifdef __STL_WIN32THREADS
    static CRITICAL_SECTION __node_allocator_lock;
    static bool __node_allocator_lock_initialized;
    
public:
    __default_alloc_template() {
        // This assumes the first constructor is called before threads
        // are started.
        if (!__node_allocator_lock_initialized) {
            InitializeCriticalSection(&__node_allocator_lock);
            __node_allocator_lock_initialized = true;
        }
    }
private:
# endif
    
    class lock {
    public:
        lock() { __NODE_ALLOCATOR_LOCK; }
        ~lock() { __NODE_ALLOCATOR_UNLOCK; }
    };
    friend class lock;
    
public:
    
    /*
     分配的具体过程.
     */
    static void * allocate(size_t n)
    {
        obj * __VOLATILE * my_free_list;
        obj * __RESTRICT result;
        /*
         如果, N > 128 了, 直接 malloc 进行分配了.
         */
        if (n > (size_t) __MAX_BYTES) {
            return(malloc_alloc::allocate(n));
        }
        /*
         首先寻找目标链表.
         */
        my_free_list = free_list + FREELIST_INDEX(n);
        result = *my_free_list;
        if (result == 0) {
            /*
             此时, 目标链表上没有空余空间了.
             */
            void *r = refill(ROUND_UP(n));
            return r;
        }
        /*
         此时, 目标链表有空余块, 那就拿出一个来.
         同时更新目标链表的起始位置.
         */
        *my_free_list = result -> free_list_link;
        return (result);
    };
    
    /* p may not be 0 */
    static void deallocate(void *p, size_t n)
    {
        obj *q = (obj *)p;
        obj * __VOLATILE * my_free_list;
        
        /*
         如果, 回收的大于了 128 , 直接 free 掉.
         */
        if (n > (size_t) __MAX_BYTES) {
            malloc_alloc::deallocate(p, n);
            return;
        }
        /*
         否则, 将回收的数据, 塞到对应的目标链表中.
         */
        // 先计算目标链表的位置.
        my_free_list = free_list + FREELIST_INDEX(n);
        // 把资源放到链表上, 这里应该有加减锁的操作.
        q -> free_list_link = *my_free_list;
        *my_free_list = q;
    }
    
    static void * reallocate(void *p, size_t old_sz, size_t new_sz);
    
} ;

// 宏定义, alloc 的世纪类型是,  __default_alloc_template
typedef __default_alloc_template<__NODE_ALLOCATOR_THREADS, 0> alloc;
typedef __default_alloc_template<false, 0> single_client_alloc;



/* We allocate memory in large chunks in order to avoid fragmenting     */
/* the malloc heap too much.                                            */
/* We assume that size is properly aligned.                             */
/* We hold the allocation lock.                                         */
template <bool threads, int inst>
char*
__default_alloc_template<threads, inst>::chunk_alloc(size_t size, int& nobjs)
{
    char * result;
    size_t total_bytes = size * nobjs;
    size_t bytes_left = end_free - start_free;
    
    if (bytes_left >= total_bytes) {
        /*
         如果, 战备池里面, 还有那么多的20*n个空间, 直接从战备池里面拿这么多空间出去.
         */
        result = start_free;
        start_free += total_bytes; // 战备池更新区间.
        return(result);
    } else if (bytes_left >= size) {
        /*
         不过战备池里面, 够一个以上, 20 个以下的, 那么尽可能多分配, 然后调整传出参数, 战备池的开始指针.
         */
        nobjs = bytes_left/size;
        total_bytes = size * nobjs;
        result = start_free;
        start_free += total_bytes;
        return(result);
    } else {
        // bytes_to_get 为新的要开辟的内存空间大小.
        size_t bytes_to_get = 2 * total_bytes + ROUND_UP(heap_size >> 4);
        // Try to make use of the left-over piece.
        if (bytes_left > 0) {
            /*
             这里, 利用头插法, 将战备池剩余的空间, 安插到合适的目标链表中.
             此时战备池为空, 准备记录新生成的空间.
             */
            obj * __VOLATILE * my_free_list = free_list + FREELIST_INDEX(bytes_left);
            ((obj *)start_free) -> free_list_link = *my_free_list;
            *my_free_list = (obj *)start_free;
        }
        start_free = (char *)malloc(bytes_to_get);
        if (0 == start_free) {
            /*
             如果, 不能申请到新的空间了.
             那就遍历后面的目标链表, 看有没有空余的块, 先满足当前的申请需求.
             */
            int i;
            obj * __VOLATILE * my_free_list, *p;
            // Try to make do with what we have.  That can't
            // hurt.  We do not try smaller requests, since that tends
            // to result in disaster on multi-process machines.
            for (i = size; i <= __MAX_BYTES; i += __ALIGN) {
                my_free_list = free_list + FREELIST_INDEX(i);
                p = *my_free_list;
                if (0 != p) {
                    // 目标链表的指向变为下一个块, 把当前块当做战备池.
                    // 递归调用, 由于战备池发生了变化, 这里递归调用, 不会有死递归的危险.
                    *my_free_list = p -> free_list_link;
                    start_free = (char *)p;
                    end_free = start_free + i;
                    return(chunk_alloc(size, nobjs));
                    // Any leftover piece will eventually make it to the
                    // right free list.
                }
            }
            end_free = 0;	// In case of exception.
            start_free = (char *)malloc_alloc::allocate(bytes_to_get);
            // This should either throw an
            // exception or remedy the situation.  Thus we assume it
            // succeeded.
        }
        /*
         分配成功了, 递归调用, 此时战备池有足够的空间了.
         由于战备池发生了变化, 这里递归调用, 不会有死递归的危险.
         */
        heap_size += bytes_to_get;
        end_free = start_free + bytes_to_get;
        return(chunk_alloc(size, nobjs));
    }
}

/*
 当目标链表上没有剩余空间的时候, 会走到该方法.
 */
template <bool threads, int inst>
void* __default_alloc_template<threads, inst>::refill(size_t n)
{
    int nobjs = 20;
    /*
     通过 chunk_alloc 得到目标链表上, 可以操作的新的块.
     */
    char * chunk = chunk_alloc(n, nobjs);
    obj * __VOLATILE * my_free_list;
    obj * result;
    obj * current_obj, * next_obj;
    int i;
    // nobjs 只有一个, 代表着没有空间了, 是从后面借的空间块.
    if (1 == nobjs) return(chunk);
    
    my_free_list = free_list + FREELIST_INDEX(n);
    
    // 新生成的链表目前还没有穿起来, 这里将链表穿起来. 第一个元素被返回, 当做容器所需要的位置了.
    result = (obj *)chunk;
    *my_free_list = next_obj = (obj *)(chunk + n);
    for (i = 1; ; i++) {
        current_obj = next_obj;
        next_obj = (obj *)((char *)next_obj + n);
        if (nobjs - 1 == i) {
            current_obj -> free_list_link = 0;
            break;
        } else {
            current_obj -> free_list_link = next_obj;
        }
    }
    return(result);
}

template <bool threads, int inst>
void*
__default_alloc_template<threads, inst>::reallocate(void *p,
                                                    size_t old_sz,
                                                    size_t new_sz)
{
    void * result;
    size_t copy_sz;
    
    if (old_sz > (size_t) __MAX_BYTES && new_sz > (size_t) __MAX_BYTES) {
        return(realloc(p, new_sz));
    }
    if (ROUND_UP(old_sz) == ROUND_UP(new_sz)) return(p);
    result = allocate(new_sz);
    copy_sz = new_sz > old_sz? old_sz : new_sz;
    memcpy(result, p, copy_sz);
    deallocate(p, old_sz);
    return(result);
}

#ifdef __STL_PTHREADS
template <bool threads, int inst>
pthread_mutex_t
__default_alloc_template<threads, inst>::__node_allocator_lock
= PTHREAD_MUTEX_INITIALIZER;
#endif

#ifdef __STL_WIN32THREADS
template <bool threads, int inst> CRITICAL_SECTION
__default_alloc_template<threads, inst>::__node_allocator_lock;

template <bool threads, int inst> bool
__default_alloc_template<threads, inst>::__node_allocator_lock_initialized
= false;
#endif

#ifdef __STL_SGI_THREADS
__STL_END_NAMESPACE
#include <mutex.h>
#include <time.h>
__STL_BEGIN_NAMESPACE
// Somewhat generic lock implementations.  We need only test-and-set
// and some way to sleep.  These should work with both SGI pthreads
// and sproc threads.  They may be useful on other systems.
template <bool threads, int inst>
volatile unsigned long
__default_alloc_template<threads, inst>::__node_allocator_lock = 0;

#if __mips < 3 || !(defined (_ABIN32) || defined(_ABI64)) || defined(__GNUC__)
#   define __test_and_set(l,v) test_and_set(l,v)
#endif

template <bool threads, int inst>
void 
__default_alloc_template<threads, inst>::__lock(volatile unsigned long *lock)
{
    const unsigned low_spin_max = 30;  // spin cycles if we suspect uniprocessor
    const unsigned high_spin_max = 1000; // spin cycles for multiprocessor
    static unsigned spin_max = low_spin_max;
    unsigned my_spin_max;
    static unsigned last_spins = 0;
    unsigned my_last_spins;
    static struct timespec ts = {0, 1000};
    unsigned junk;
#   define __ALLOC_PAUSE junk *= junk; junk *= junk; junk *= junk; junk *= junk
    int i;
    
    if (!__test_and_set((unsigned long *)lock, 1)) {
        return;
    }
    my_spin_max = spin_max;
    my_last_spins = last_spins;
    for (i = 0; i < my_spin_max; i++) {
        if (i < my_last_spins/2 || *lock) {
            __ALLOC_PAUSE;
            continue;
        }
        if (!__test_and_set((unsigned long *)lock, 1)) {
            // got it!
            // Spinning worked.  Thus we're probably not being scheduled
            // against the other process with which we were contending.
            // Thus it makes sense to spin longer the next time.
            last_spins = i;
            spin_max = high_spin_max;
            return;
        }
    }
    // We are probably being scheduled against the other process.  Sleep.
    spin_max = low_spin_max;
    for (;;) {
        if (!__test_and_set((unsigned long *)lock, 1)) {
            return;
        }
        nanosleep(&ts, 0);
    }
}

template <bool threads, int inst>
inline void
__default_alloc_template<threads, inst>::__unlock(volatile unsigned long *lock)
{
#   if defined(__GNUC__) && __mips >= 3
    asm("sync");
    *lock = 0;
#   elif __mips >= 3 && (defined (_ABIN32) || defined(_ABI64))
    __lock_release(lock);
#   else 
    *lock = 0;
    // This is not sufficient on many multiprocessors, since
    // writes to protected variables and the lock may be reordered.
#   endif
}
#endif

template <bool threads, int inst>
char *__default_alloc_template<threads, inst>::start_free = 0;

template <bool threads, int inst>
char *__default_alloc_template<threads, inst>::end_free = 0;

template <bool threads, int inst>
size_t __default_alloc_template<threads, inst>::heap_size = 0;

template <bool threads, int inst>
__default_alloc_template<threads, inst>::obj * __VOLATILE
__default_alloc_template<threads, inst> ::free_list[
# ifdef __SUNPRO_CC
                                                    __NFREELISTS
# else
                                                    __default_alloc_template<threads, inst>::__NFREELISTS
# endif
                                                    ] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
// The 16 zeros are necessary to make version 4.1 of the SunPro
// compiler happy.  Otherwise it appears to allocate too little
// space for the array.

# ifdef __STL_WIN32THREADS
// Create one to get critical section initialized.
// We do this onece per file, but only the first constructor
// does anything.
static alloc __node_allocator_dummy_instance;
# endif

#endif /* ! __USE_MALLOC */

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1174
#endif

__STL_END_NAMESPACE

#undef __PRIVATE

#endif /* __SGI_STL_INTERNAL_ALLOC_H */
