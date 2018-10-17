# OC分类

## 分类对象

struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods; // 对象方法
	const struct _method_list_t *class_methods; // 类方法
	const struct _protocol_list_t *protocols; // 协议信息
	const struct _prop_list_t *properties; // 属性信息
};

static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[2];
} _OBJC_$_CATEGORY_INSTANCE_METHODS_MJPerson_$_Eat __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	2,
	{{(struct objc_selector *)"eat", "v16@0:8", (void *)_I_MJPerson_Eat_eat},
	{(struct objc_selector *)"eat1", "v16@0:8", (void *)_I_MJPerson_Eat_eat1}}
};

static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[2];
} _OBJC_$_CATEGORY_CLASS_METHODS_MJPerson_$_Eat __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	2,
	{{(struct objc_selector *)"eat2", "v16@0:8", (void *)_C_MJPerson_Eat_eat2},
	{(struct objc_selector *)"eat3", "v16@0:8", (void *)_C_MJPerson_Eat_eat3}}
};

static struct _category_t _OBJC_$_CATEGORY_MJPerson_$_Eat __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"MJPerson",
	0, // &OBJC_CLASS_$_MJPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_MJPerson_$_Eat,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_CLASS_METHODS_MJPerson_$_Eat,
	(const struct _protocol_list_t *)&_OBJC_CATEGORY_PROTOCOLS_$_MJPerson_$_Eat,
	(const struct _prop_list_t *)&_OBJC_$_PROP_LIST_MJPerson_$_Eat,
};


一个分类, 在 rewrite 成为 cpp 文件之后, 得到的是这样的一个数据. 在运行时, 会将这个结构体中的数据, 添加到类对象里面.
从上我们可以看到, 我们平时写的 OC 分类, 其实是会用一个结构体进行存储, 然后存放到一个 struct _category_t 中.


static void 
attachCategories(Class cls, category_list *cats, bool flush_caches)
{
    if (!cats) return;
    if (PrintReplacedMethods) printReplacements(cls, cats);

    bool isMeta = cls->isMetaClass();

    // fixme rearrange to remove these intermediate allocations
    method_list_t **mlists = (method_list_t **)
        malloc(cats->count * sizeof(*mlists));
    property_list_t **proplists = (property_list_t **)
        malloc(cats->count * sizeof(*proplists));
    protocol_list_t **protolists = (protocol_list_t **)
        malloc(cats->count * sizeof(*protolists));

    // Count backwards through cats to get newest categories first
    int mcount = 0;
    int propcount = 0;
    int protocount = 0;
    int i = cats->count;
    bool fromBundle = NO;
    while (i--) {
        auto& entry = cats->list[i];

        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        if (mlist) {
            mlists[mcount++] = mlist;
            fromBundle |= entry.hi->isBundle();
        }

        property_list_t *proplist = 
            entry.cat->propertiesForMeta(isMeta, entry.hi);
        if (proplist) {
            proplists[propcount++] = proplist;
        }

        protocol_list_t *protolist = entry.cat->protocols;
        if (protolist) {
            protolists[protocount++] = protolist;
        }
    }

    auto rw = cls->data();

    prepareMethodLists(cls, mlists, mcount, NO, fromBundle);
    rw->methods.attachLists(mlists, mcount);
    free(mlists);
    if (flush_caches  &&  mcount > 0) flushCaches(cls);

    rw->properties.attachLists(proplists, propcount);
    free(proplists);

    rw->protocols.attachLists(protolists, protocount);
    free(protolists);
}
上面的这个方法, 就是将分类里面的所有信息, 注册到类方法中. attachLists 是具体的实现方法.

void attachLists(List* const * addedLists, uint32_t addedCount) {
        if (addedCount == 0) return;

        if (hasArray()) {
            // many lists -> many lists 
            uint32_t oldCount = array()->count;
            uint32_t newCount = oldCount + addedCount;
            setArray((array_t *)realloc(array(), array_t::byteSize(newCount)));
            array()->count = newCount;
            memmove(array()->lists + addedCount, array()->lists, 
                    oldCount * sizeof(array()->lists[0]));
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
        else if (!list  &&  addedCount == 1) {
            // 0 lists -> 1 list
            list = addedLists[0];
        } 
        else {
            // 1 list -> many lists
            List* oldList = list;
            uint32_t oldCount = oldList ? 1 : 0;
            uint32_t newCount = oldCount + addedCount;
            setArray((array_t *)malloc(array_t::byteSize(newCount)));
            array()->count = newCount;
            if (oldList) array()->lists[addedCount] = oldList;
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
    }

uint32_t oldCount = array()->count;
uint32_t newCount = oldCount + addedCount;
setArray((array_t *)realloc(array(), array_t::byteSize(newCount))); 重新分配空间, 扩容操作
array()->count = newCount;
memmove(array()->lists + addedCount, array()->lists,  将开头的数据, 移到后面
        oldCount * sizeof(array()->lists[0]));
memcpy(array()->lists, addedLists, 
        addedCount * sizeof(array()->lists[0])); 将新的数据, 放到前面
这一段就是分类方法在本类方法之前的关键所在.

## load, initialize

load 是 runtime 在加载类, 分类的时候调用.

void call_load_methods(void)
{
    static bool loading = NO;
    bool more_categories;

    loadMethodLock.assertLocked();

    // Re-entrant calls do nothing; the outermost call will finish the job.
    if (loading) return;
    loading = YES;

    void *pool = objc_autoreleasePoolPush();

    do {
        // 1. Repeatedly call class +loads until there aren't any more
        while (loadable_classes_used > 0) {
            call_class_loads();
        }

        // 2. Call category +loads ONCE
        more_categories = call_category_loads();

        // 3. Run more +loads if there are classes OR more untried categories
    } while (loadable_classes_used > 0  ||  more_categories);

    objc_autoreleasePoolPop(pool);

    loading = NO;
}

/***********************************************************************
* call_class_loads
* Call all pending class +load methods.
* If new classes become loadable, +load is NOT called for them.
*
* Called only by call_load_methods().
**********************************************************************/
static void call_class_loads(void)
{
    int i;
    
    // Detach current loadable list.
    struct loadable_class *classes = loadable_classes;
    int used = loadable_classes_used;
    loadable_classes = nil;
    loadable_classes_allocated = 0;
    loadable_classes_used = 0;
    
    // Call all +loads for the detached list.
    for (i = 0; i < used; i++) {
        Class cls = classes[i].cls;
        load_method_t load_method = (load_method_t)classes[i].method;
        if (!cls) continue; 

        if (PrintLoading) {
            _objc_inform("LOAD: +[%s load]\n", cls->nameForLogging());
        }
        (*load_method)(cls, SEL_load);
    }
    // 这里, 是直接用函数指针的方式, 调用的 load 方法. 如果我们自己调用 load 方法, 还是会进行消息的寻找过程.
    
    // Destroy the detached list.
    if (classes) free(classes);
}


void prepare_load_methods(const headerType *mhdr)
{
    size_t count, i;

    runtimeLock.assertWriting();

    classref_t *classlist = 
        _getObjc2NonlazyClassList(mhdr, &count); // 没有实现, 应该就是统计所有的需要加载得嘞
    for (i = 0; i < count; i++) {
        schedule_class_load(remapClass(classlist[i])); // 对加载的类进行排序
    }

    category_t **categorylist = _getObjc2NonlazyCategoryList(mhdr, &count); // 拿分类
    for (i = 0; i < count; i++) {
        category_t *cat = categorylist[i];
        Class cls = remapClass(cat->cls);
        if (!cls) continue;  // category for ignored weak-linked class
        realizeClass(cls);
        assert(cls->ISA()->isRealized());
        add_category_to_loadable_list(cat); // 直接放到后面
    }
}

static void schedule_class_load(Class cls)
{
    if (!cls) return;
    assert(cls->isRealized());  // _read_images should realize

    if (cls->data()->flags & RW_LOADED) return;

    // Ensure superclass-first ordering
    schedule_class_load(cls->superclass);// 在这里, 优先把父类拍到了前面
    add_class_to_loadable_list(cls);
    cls->setInfo(RW_LOADED); 
}

先调用类的 load, 因为上面 call_class_loads 先调用, 而在 prepare 的时候, 会对所有 load 的类进行排序, 先把父类的放在前面, 子类的放到后面. 原始的顺序, 是编译顺序, 只不过父类在这里提前了. 两个不相关的类, 加载顺序, 是按照编译顺序的. 
到了分类这里, 就是按照编译顺序调用的.

load 也是一个方法, 当我们现实的 objClass load 的时候, 还是用消息发送机制来调用.

load 只是一个普通的类方法, 但是runtime 在加载类的时候, 调用了这个方法, 所以, 它可以做一些初始化的工作.


### initialize

只会调用1个, 也就是有覆盖, 它是通过消息机制调用的. 而 load 是通过 Imp 调用的.
initialize 会在类第一次接受消息的时候调用, 所以如果一个类压根没有用到, initialize 也就不调用了.
先调用父类的, 然后调用子类的.

也就是说, 当一个类接收消息之后, 会调用寻找这个消息的方法实现, 在 lookUpImp 的过程中, 如果发现类没有被初始化, 会进行初始化操作, 在初始化的过程中, 如果发现父类没有进行初始化, 有进行父类的初始化操作. 然后进行自己的初始化操作,   callInitialize(cls), 这个方法里面就是调用 initialize 方法. 但是这个时候的调用, 是通过消息机制的. 所以就有可能, 子类没有定义 initialize 方法, 父类的就被使用了. 也有可能, 分类有 initialize 方法, 就调用分类的 initialize 方法. 

但是 initialize 方法的好处在于, 用的时候才会被调用, 而 load 是加载就调用. 大量代码写在 load 里面, 其实是增加了启动时间. 为了弥补 initialize 的不足, 我们一般在里面有个 disaptch_once 的包装.

// 类方法也是调用了 class_getInstanceMethod. 说明, 对于类方法来说, 也只是被元类当做实例方法来看了.
Method class_getClassMethod(Class cls, SEL sel)
{
    if (!cls  ||  !sel) return nil;

    return class_getInstanceMethod(cls->getMeta(), sel);
}

Method class_getInstanceMethod(Class cls, SEL sel)
{
    if (!cls  ||  !sel) return nil;

    lookUpImpOrNil(cls, sel, nil, 
                   NO/*initialize*/, NO/*cache*/, YES/*resolver*/);
    return _class_getMethod(cls, sel);
}

IMP lookUpImpOrNil(Class cls, SEL sel, id inst, 
                   bool initialize, bool cache, bool resolver)
{
    IMP imp = lookUpImpOrForward(cls, sel, inst, initialize, cache, resolver);
    if (imp == _objc_msgForward_impcache) return nil;
    else return imp;
}

IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;

    runtimeLock.assertUnlocked();

    // Optimistic cache lookup
    // 首先在缓存里面找实现.
    if (cache) {
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }

    runtimeLock.read();

// 如果类没有初始化, 那么会进行初始化操作
    if (initialize  &&  !cls->isInitialized()) {
        runtimeLock.unlockRead();
        _class_initialize (_class_getNonMetaClass(cls, inst));
        runtimeLock.read();
    }


.... 获取 imp 的代码
 done:
    runtimeLock.unlockRead();

    return imp;
}

// 初始化类
void _class_initialize(Class cls)
{
    assert(!cls->isMetaClass());

    Class supercls;
    bool reallyInitialize = NO;

// 这里, 调用了父类的初始化操作
    supercls = cls->superclass;
    if (supercls  &&  !supercls->isInitialized()) {
        _class_initialize(supercls);
    }
    callInitialize(cls);
    ... 自己的初始化操作
}

void callInitialize(Class cls)
{
    ((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize);
    asm("");
}

