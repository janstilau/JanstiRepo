#if __OBJC2__

#include "objc-private.h"
#include "objc-cache.h"

#if SUPPORT_PREOPT
static const objc_selopt_t *builtins = NULL;
#endif


static size_t SelrefCount = 0;

static NXMapTable *namedSelectors;

static SEL search_builtins(const char *key);


/***********************************************************************
 * sel_init
 * Initialize selector tables and register selectors used internally.
 **********************************************************************/
void sel_init(size_t selrefCount)
{
    // save this value for later
    SelrefCount = selrefCount;
    
    // Register selectors used by libobjc
    
#define s(x) SEL_##x = sel_registerNameNoLock(#x, NO)
#define t(x,y) SEL_##y = sel_registerNameNoLock(#x, NO)
    
    sel_lock();
    
    s(load);
    s(initialize);
    t(resolveInstanceMethod:, resolveInstanceMethod);
    t(resolveClassMethod:, resolveClassMethod);
    t(.cxx_construct, cxx_construct);
    t(.cxx_destruct, cxx_destruct);
    s(retain);
    s(release);
    s(autorelease);
    s(retainCount);
    s(alloc);
    t(allocWithZone:, allocWithZone);
    s(dealloc);
    s(copy);
    s(new);
    t(forwardInvocation:, forwardInvocation);
    t(_tryRetain, tryRetain);
    t(_isDeallocating, isDeallocating);
    s(retainWeakReference);
    s(allowsWeakReference);
    
    sel_unlock();
    
#undef s
#undef t
}


static SEL sel_alloc(const char *name, bool copy)
{
    selLock.assertWriting();
    return (SEL)(copy ? strdupIfMutable(name) : name);
}

/*
 这里, 直接将 sel 转为了 char*, 证明 sel 里面第一个成员铁定是 char *.
 */
const char *sel_getName(SEL sel) 
{
    if (!sel) return "<null selector>";
    return (const char *)(const void*)sel;
}


BOOL sel_isMapped(SEL sel) 
{
    if (!sel) return NO;
    
    const char *name = (const char *)(void *)sel;
    
    if (sel == search_builtins(name)) return YES;
    
    rwlock_reader_t lock(selLock);
    if (namedSelectors) {
        return (sel == (SEL)NXMapGet(namedSelectors, name));
    }
    return false;
}


static SEL search_builtins(const char *name) 
{
    return nil;
}

// @selector 的实现.
static SEL __sel_registerName(const char *name,
                              int lock,
                              int copy)
{
    SEL result = 0;
    
    if (lock) selLock.assertUnlocked();
    else selLock.assertWriting();
    
    if (!name) return (SEL)0;
    
    result = search_builtins(name);
    if (result) return result;
    
    /*
     如果, 从 namedSelectors 里面, 可以获取到数据, 就是之前注册过了.
     */
    if (lock) selLock.read();
    if (namedSelectors) {
        result = (SEL)NXMapGet(namedSelectors, name);
    }
    if (lock) selLock.unlockRead();
    if (result) return result;
    
    /*
     如果没有找到, 就是要进行注册操作了.
     注意, 这里有着读写锁的操作.
     */
    if (lock) selLock.write();
    
    if (!namedSelectors) {
        namedSelectors = NXCreateMapTable(NXStrValueMapPrototype,
                                          (unsigned)SelrefCount);
    }
    if (lock) {
        // Rescan in case it was added while we dropped the lock
        result = (SEL)NXMapGet(namedSelectors, name);
    }
    if (!result) {
        result = sel_alloc(name, copy);
        // fixme choose a better container (hash not map for starters)
        NXMapInsert(namedSelectors, sel_getName(result), result);
    }
    
    if (lock) selLock.unlockWrite();
    return result;
}


SEL sel_registerName(const char *name) {
    return __sel_registerName(name, 1, 1);     // YES lock, YES copy
}

SEL sel_registerNameNoLock(const char *name, bool copy) {
    return __sel_registerName(name, 0, copy);  // NO lock, maybe copy
}

void sel_lock(void)
{
    selLock.write();
}

void sel_unlock(void)
{
    selLock.unlockWrite();
}


// 2001/1/24
// the majority of uses of this function (which used to return NULL if not found)
// did not check for NULL, so, in fact, never return NULL
//
SEL sel_getUid(const char *name) {
    return __sel_registerName(name, 2, 1);  // YES lock, YES copy
}


BOOL sel_isEqual(SEL lhs, SEL rhs)
{
    return bool(lhs == rhs);
}


#endif
