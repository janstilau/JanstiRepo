//
//  CacheObj.m
//  Foundation
//
//  Created by JustinLau on 2020/9/7.
//

#import "CacheObj.h"

static NSRecursiveLock    *kvoLock = nil;
static Class        baseClass;
static NSMapTable    *classTable = 0;
static NSMapTable    *infoTable = 0;
static NSMapTable       *dependentKeyTable;
static id               null;

static inline void
setup()
{
    if (nil == kvoLock)
    {
        [gnustep_global_lock lock];
        if (nil == kvoLock)
        {
            kvoLock = [NSRecursiveLock new];
            null = [[NSNull null] retain];
            classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                          NSNonOwnedPointerMapValueCallBacks, 128);
            infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 1024);
            dependentKeyTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                                 NSOwnedPointerMapValueCallBacks, 128);
            baseClass = NSClassFromString(@"GSKVOBase");
        }
        [gnustep_global_lock unlock];
    }
}

/*
 KVO 生成的子类的需要重写的方法的集合.
 */
@implementation    GSKVOBase

- (void) dealloc
{
    // Turn off KVO for self ... then call the real dealloc implementation.
    [self setObservationInfo: nil];
    object_setClass(self, [self class]);
    [self dealloc];
}

/*
 class, 返回父类的类.
 */
- (Class) class
{
    return class_getSuperclass(object_getClass(self));
}

- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    /*
     首先获取, 父类的 setValue for key 的真正实现.
     */
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}

- (Class) superclass
{
    return class_getSuperclass(class_getSuperclass(object_getClass(self)));
}

@end

/*
 * Get a key name from a selector (setKey: or _setKey:) by
 * taking the key part and making the first letter lowercase.
 */
static NSString *newKey(SEL _cmd)
{
    const char    *name = sel_getName(_cmd);
    unsigned    len;
    NSString    *key;
    unsigned    i;
    
    if (0 == _cmd || 0 == (name = sel_getName(_cmd)))
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Missing selector name"];
    }
    len = strlen(name);
    if (*name == '_')
    {
        name++;
        len--;
    }
    if (len < 5 || name[len-1] != ':' || strncmp(name, "set", 3) != 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Invalid selector name"];
    }
    name += 3;            // Step past 'set'
    len -= 4;            // allow for 'set' and trailing ':'
    for (i = 0; i < len; i++)
    {
        if (name[i] & 0x80)
        {
            break;
        }
    }
    if (i == len)
    {
        char    buf[len];
        
        /* Efficient key creation for ascii keys
         */
        for (i = 0; i < len; i++) buf[i] = name[i];
        if (isupper(buf[0]))
        {
            buf[0] = tolower(buf[0]);
        }
        key = [[NSString alloc] initWithBytes: buf
                                       length: len
                                     encoding: NSASCIIStringEncoding];
    }
    else
    {
        unichar        u;
        NSMutableString    *m;
        NSString        *tmp;
        
        /*
         * Key creation for unicode strings.
         */
        m = [[NSMutableString alloc] initWithBytes: name
                                            length: len
                                          encoding: NSUTF8StringEncoding];
        u = [m characterAtIndex: 0];
        u = uni_tolower(u);
        tmp = [[NSString alloc] initWithCharacters: &u length: 1];
        [m replaceCharactersInRange: NSMakeRange(0, 1) withString: tmp];
        [tmp release];
        key = m;
    }
    return key;
}


static GSKVOClazzReplacement *
replacementForClass(Class c)
{
    GSKVOClazzReplacement *replaceMent;
    
    setup();
    [kvoLock lock];
    r = (GSKVOReplacement*)NSMapGet(classTable, (void*)c);
    if (replaceMent == nil)
    {
        replaceMent = [[GSKVOClazzReplacement alloc] initWithClass: c];
        NSMapInsert(classTable, (void*)c, (void*)r);
    }
    [kvoLock unlock];
    return replaceMent;
}

#if defined(USE_LIBFFI)
static void
cifframe_callback(ffi_cif *cif, void *retp, void **args, void *user)
{
    id            obj;
    SEL           sel;
    NSString    *key;
    Class        c;
    void        (*imp)(id,SEL,void*);
    
    obj = *(id *)args[0];
    sel = *(SEL *)args[1];
    c = [obj class];
    
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: sel];
    key = newKey(sel);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [obj willChangeValueForKey: key];
        ffi_call(cif, (void*)imp, retp, args);
        // post setting code here
        [obj didChangeValueForKey: key];
    }
    else
    {
        ffi_call(cif, (void*)imp, retp, args);
    }
    RELEASE(key);
}
#endif

@implementation    GSKVOClazzReplacement
- (void) dealloc
{
    DESTROY(keys);
    [super dealloc];
}

/*
 在这个方法里面, 进行了子类的创建工作.
 */
- (id) initWithClass: (Class)aClass
{
    NSValue        *replaceClazz;
    NSString        *superName;
    NSString        *name;
    
    original = aClass;
    
    /*
     * Create subclass of the original, and override some methods
     * with implementations from our abstract base class.
     */
    superName = NSStringFromClass(original);
    name = [@"GSKVO" stringByAppendingString: superName];
    replaceClazz = GSObjCMakeClass(name, superName, nil);
    
    GSObjCAddClasses([NSArray arrayWithObject: replaceClazz]);
    replaceClazz = NSClassFromString(name);
    
    /*
     这里, 把一些公共行为, 添加到新的类中.
     */
    GSObjCAddClassBehavior(replaceClazz, baseClass);
    
    /* Create the set of setter methods overridden.
     */
    keys = [NSMutableSet new];
    
    return self;
}

/*
 这里, 就是重写那些特殊的 key 的 set 方法.
 */
- (void) overrideSetterFor: (NSString*)aKey
{
    if ([keys member: aKey] == nil)
    {
        NSMethodSignature    *sig;
        SEL        sel;
        IMP        imp;
        const char    *type;
        NSString          *suffix;
        NSString          *a[2];
        unsigned          i;
        BOOL              found = NO;
        NSString        *tmp;
        unichar u;
        
        suffix = [aKey substringFromIndex: 1];
        u = uni_toupper([aKey characterAtIndex: 0]);
        tmp = [[NSString alloc] initWithCharacters: &u length: 1];
        a[0] = [NSString stringWithFormat: @"set%@%@:", tmp, suffix];
        a[1] = [NSString stringWithFormat: @"_set%@%@:", tmp, suffix];
        [tmp release];
        for (i = 0; i < 2; i++)
        {
            /*
             * Replace original setter with our own version which does KVO
             * notifications.
             */
            sel = NSSelectorFromString(a[i]);
            if (sel == 0)
            {
                continue;
            }
            sig = [original instanceMethodSignatureForSelector: sel];
            if (sig == 0)
            {
                continue;
            }
            
            /*
             * A setter must take three arguments (self, _cmd, value).
             * The return value (if any) is ignored.
             */
            if ([sig numberOfArguments] != 3)
            {
                continue;    // Not a valid setter method.
            }
            
            /*
             * Since the compiler passes different argument types
             * differently, we must use a different setter method
             * for each argument type.
             * FIXME ... support structures
             * Unsupported types are quietly ignored ... is that right?
             */
            type = [sig getArgumentTypeAtIndex: 2];
            switch (*type)
            {
                case _C_CHR:
                case _C_UCHR:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterChar:)];
                    break;
                case _C_SHT:
                case _C_USHT:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterShort:)];
                    break;
                case _C_INT:
                case _C_UINT:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterInt:)];
                    break;
                case _C_LNG:
                case _C_ULNG:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterLong:)];
                    break;
#ifdef  _C_LNG_LNG
                case _C_LNG_LNG:
                case _C_ULNG_LNG:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterLongLong:)];
                    break;
#endif
                case _C_FLT:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterFloat:)];
                    break;
                case _C_DBL:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterDouble:)];
                    break;
#if __GNUC__ > 2 && defined(_C_BOOL)
                case _C_BOOL:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setterChar:)];
                    break;
#endif
                case _C_ID:
                case _C_CLASS:
                case _C_PTR:
                    imp = [[GSKVOSetter class]
                           instanceMethodForSelector: @selector(setter:)];
                    break;
                case _C_STRUCT_B:
                    if (GSSelectorTypesMatch(@encode(NSRange), type))
                    {
                        imp = [[GSKVOSetter class]
                               instanceMethodForSelector: @selector(setterRange:)];
                    }
                    else if (GSSelectorTypesMatch(@encode(NSPoint), type))
                    {
                        imp = [[GSKVOSetter class]
                               instanceMethodForSelector: @selector(setterPoint:)];
                    }
                    else if (GSSelectorTypesMatch(@encode(NSSize), type))
                    {
                        imp = [[GSKVOSetter class]
                               instanceMethodForSelector: @selector(setterSize:)];
                    }
                    else if (GSSelectorTypesMatch(@encode(NSRect), type))
                    {
                        imp = [[GSKVOSetter class]
                               instanceMethodForSelector: @selector(setterRect:)];
                    }
                    else
                    {
#if defined(USE_LIBFFI)
                        GSCodeBuffer    *b;
                        
                        b = cifframe_closure(sig, cifframe_callback);
                        [b retain];
                        imp = [b executable];
#else
                        imp = 0;
#endif
                    }
                    break;
                default:
                    imp = 0;
                    break;
            }
            
            if (imp != 0)
            {
                /*
                 这里, 根据仅仅向 替换类 里面, 添加新的 set 方法.
                 */
                if (class_addMethod(replaceClazz, sel, imp, [sig methodType]))
                {
                    found = YES;
                }
                else
                {
                    NSLog(@"Failed to add setter method for %s to %s",
                          sel_getName(sel), class_getName(original));
                }
            }
        }
        
        if (found == YES)
        {
            [keys addObject: aKey];
        }
        else
        {
            NSMapTable *depKeys = NSMapGet(dependentKeyTable, original);
            
            if (depKeys)
            {
                NSMapEnumerator enumerator = NSEnumerateMapTable(depKeys);
                NSString *mainKey;
                NSHashTable *dependents;
                
                while (NSNextMapEnumeratorPair(&enumerator, (void **)(&mainKey),
                                               (void**)&dependents))
                {
                    NSHashEnumerator dependentKeyEnum;
                    NSString *dependentKey;
                    
                    if (!dependents) continue;
                    dependentKeyEnum = NSEnumerateHashTable(dependents);
                    while ((dependentKey
                            = NSNextHashEnumeratorItem(&dependentKeyEnum)))
                    {
                        if ([dependentKey isEqual: aKey])
                        {
                            [self overrideSetterFor: mainKey];
                            // Mark the key as used
                            [keys addObject: aKey];
                            found = YES;
                        }
                    }
                    NSEndHashTableEnumeration(&dependentKeyEnum);
                }
                NSEndMapTableEnumeration(&enumerator);
            }
            
            if (!found)
            {
                NSDebugLLog(@"KVC", @"class %@ not KVC compliant for %@",
                            original, aKey);
                /*
                 [NSException raise: NSInvalidArgumentException
                 format: @"class not KVC complient for %@", aKey];
                 */
            }
        }
    }
}

- (Class) replacement
{
    return replaceClazz;
}

@end

/*
 这个类, 充分的利用了 OC 的动态性.
 这些方法, 仅仅是提供一个实现而已, 之所以有这么多方法, 仅仅是
 imp = (void (*)(id,SEL,unsigned char))[c instanceMethodForSelector: _cmd];
 这个里面, 第三个参数的类型不同, 其他的全部一样.
 在真正方法运行的时候, key = newKey(_cmd); 中提出出来的, 就是实际的 setName 中的 name, 因为这些方法里面的 IMP, 会和 setName 这个 SEL 进行绑定, 添加到 replacementClazz 中.
 */
@implementation    GSKVOSetter
- (void) setter: (void*)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,void*);
    
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterChar: (unsigned char)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned char);
    
    imp = (void (*)(id,SEL,unsigned char))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterDouble: (double)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,double);
    
    imp = (void (*)(id,SEL,double))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterFloat: (float)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,float);
    
    imp = (void (*)(id,SEL,float))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterInt: (unsigned int)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned int);
    
    imp = (void (*)(id,SEL,unsigned int))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterLong: (unsigned long)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned long);
    
    imp = (void (*)(id,SEL,unsigned long))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned long long);
    
    imp = (void (*)(id,SEL,unsigned long long))
    [c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}
#endif

- (void) setterShort: (unsigned short)val
{
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned short);
    
    imp = (void (*)(id,SEL,unsigned short))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterRange: (NSRange)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSRange);
    
    imp = (void (*)(id,SEL,NSRange))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterPoint: (NSPoint)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSPoint);
    
    imp = (void (*)(id,SEL,NSPoint))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterSize: (NSSize)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSSize);
    
    imp = (void (*)(id,SEL,NSSize))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterRect: (NSRect)val
{
    NSString  *key;
    Class     c = [self class];
    void      (*imp)(id,SEL,NSRect);
    
    imp = (void (*)(id,SEL,NSRect))[c instanceMethodForSelector: _cmd];
    
    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    }
    else
    {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}
@end


@implementation    GSKVOObservation
@end

@implementation    GSKVOPathInfo
- (void) dealloc
{
    [change release];
    [observations release];
    [super dealloc];
}

- (id) init
{
    change = [NSMutableDictionary new];
    observations = [NSMutableArray new];
    return self;
}

- (void) notifyForKey: (NSString *)aKey ofInstance: (id)instance prior: (BOOL)f
{
    unsigned      count;
    id            oldValue;
    id            newValue;
    
    if (f == YES)
    {
        if ((allOptions & NSKeyValueObservingOptionPrior) == 0)
        {
            return;   // Nothing to do.
        }
        [change setObject: [NSNumber numberWithBool: YES]
                   forKey: NSKeyValueChangeNotificationIsPriorKey];
    }
    else
    {
        [change removeObjectForKey: NSKeyValueChangeNotificationIsPriorKey];
    }
    
    oldValue = [[change objectForKey: NSKeyValueChangeOldKey] retain];
    if (oldValue == nil)
    {
        oldValue = null;
    }
    newValue = [[change objectForKey: NSKeyValueChangeNewKey] retain];
    if (newValue == nil)
    {
        newValue = null;
    }
    
    /* Retain self so that we won't be deallocated during the
     * notification process.
     */
    [self retain];
    count = [observations count];
    while (count-- > 0)
    {
        GSKVOObservation  *o = [observations objectAtIndex: count];
        
        if (f == YES)
        {
            if ((o->options & NSKeyValueObservingOptionPrior) == 0)
            {
                continue;
            }
        }
        else
        {
            if (o->options & NSKeyValueObservingOptionNew)
            {
                [change setObject: newValue
                           forKey: NSKeyValueChangeNewKey];
            }
        }
        
        if (o->options & NSKeyValueObservingOptionOld)
        {
            [change setObject: oldValue
                       forKey: NSKeyValueChangeOldKey];
        }
        
        [o->observer observeValueForKeyPath: aKey
                                   ofObject: instance
                                     change: change
                                    context: o->context];
    }
    
    [change setObject: oldValue forKey: NSKeyValueChangeOldKey];
    [oldValue release];
    [change setObject: newValue forKey: NSKeyValueChangeNewKey];
    [newValue release];
    [self release];
}
@end

@implementation    GSKVOInfo

- (NSObject*) instance
{
    return instance;
}

/* Locks receiver and returns path info on success, otherwise leaves
 * receiver unlocked and returns nil.
 * The returned path info is retained and autoreleased in case something
 * removes it from the receiver while it's being used by the caller.
 */
- (GSKVOPathInfo*) lockReturningPathInfoForKey: (NSString*)key
{
    GSKVOPathInfo *pathInfo;
    
    [iLock lock];
    pathInfo = AUTORELEASE(RETAIN((GSKVOPathInfo*)NSMapGet(paths, (void*)key)));
    if (pathInfo == nil)
    {
        [iLock unlock];
    }
    return pathInfo;
}

- (void) unlock
{
    [iLock unlock];
}

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    /*
     如果, anObserver 根本就没有实现 observeValueForKeyPath 这个方法, 那么就没有必要去运行后续逻辑了.
     */
    if ([anObserver respondsToSelector:
         @selector(observeValueForKeyPath:ofObject:change:context:)] == NO) {
        return;
    }
    
    GSKVOPathInfo         *pathInfo;
    GSKVOObservation      *observation;
    unsigned              count;
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo == nil)
    {
        pathInfo = [GSKVOPathInfo new];
        // use immutable object for map key
        aPath = [aPath copy];
        NSMapInsert(paths, (void*)aPath, (void*)pathInfo);
        [pathInfo release];
        [aPath release];
    }
    
    observation = nil;
    pathInfo->allOptions = 0;
    count = [pathInfo->observations count];
    while (count-- > 0)
    {
        GSKVOObservation      *o;
        
        o = [pathInfo->observations objectAtIndex: count];
        if (o->observer == anObserver)
        {
            o->context = aContext;
            o->options = options;
            observation = o;
        }
        pathInfo->allOptions |= o->options;
    }
    if (observation == nil)
    {
        observation = [GSKVOObservation new];
        GSAssignZeroingWeakPointer((void**)&observation->observer,
                                   (void*)anObserver);
        observation->context = aContext;
        observation->options = options;
        [pathInfo->observations addObject: observation];
        [observation release];
        pathInfo->allOptions |= options;
    }
    
    if (options & NSKeyValueObservingOptionInitial)
    {
        /* If the NSKeyValueObservingOptionInitial option is set,
         * we must send an immediate notification containing the
         * existing value in the NSKeyValueChangeNewKey
         */
        [pathInfo->change setObject: [NSNumber numberWithInt: 1]
                             forKey:  NSKeyValueChangeKindKey];
        if (options & NSKeyValueObservingOptionNew)
        {
            id    value;
            
            value = [instance valueForKeyPath: aPath];
            if (value == nil)
            {
                value = null;
            }
            [pathInfo->change setObject: value
                                 forKey: NSKeyValueChangeNewKey];
        }
        [anObserver observeValueForKeyPath: aPath
                                  ofObject: instance
                                    change: pathInfo->change
                                   context: aContext];
    }
    [iLock unlock];
}

- (void) dealloc
{
    if (paths != 0) NSFreeMapTable(paths);
    RELEASE(iLock);
    [super dealloc];
}

- (id) initWithInstance: (NSObject*)i
{
    instance = i;
    paths = NSCreateMapTable(NSObjectMapKeyCallBacks,
                             NSObjectMapValueCallBacks, 8);
    iLock = [NSRecursiveLock new];
    return self;
}

- (BOOL) isUnobserved
{
    BOOL    result = NO;
    
    [iLock lock];
    if (NSCountMapTable(paths) == 0)
    {
        result = YES;
    }
    [iLock unlock];
    return result;
}

/*
 * removes the observer
 */
- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
    GSKVOPathInfo    *pathInfo;
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil)
    {
        unsigned  count = [pathInfo->observations count];
        
        pathInfo->allOptions = 0;
        while (count-- > 0)
        {
            GSKVOObservation      *o;
            
            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver || o->observer == nil)
            {
                [pathInfo->observations removeObjectAtIndex: count];
                if ([pathInfo->observations count] == 0)
                {
                    NSMapRemove(paths, (void*)aPath);
                }
            }
            else
            {
                pathInfo->allOptions |= o->options;
            }
        }
    }
    [iLock unlock];
}

- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath
{
    GSKVOPathInfo    *pathInfo;
    void          *context = 0;
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil)
    {
        unsigned  count = [pathInfo->observations count];
        
        while (count-- > 0)
        {
            GSKVOObservation      *o;
            
            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver)
            {
                context = o->context;
                break;
            }
        }
    }
    [iLock unlock];
    return context;
}
@end

@implementation NSKeyValueObservationForwarder

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context
{
    NSString * remainingKeyPath;
    NSRange dot;
    
    target = aTarget;
    keyPathToForward = [keyPath copy];
    contextToForward = context;
    
    dot = [keyPath rangeOfString: @"."];
    if (dot.location == NSNotFound)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"NSKeyValueObservationForwarder was not given a key path"];
    }
    keyForUpdate = [[keyPath substringToIndex: dot.location] copy];
    remainingKeyPath = [keyPath substringFromIndex: dot.location + 1];
    observedObjectForUpdate = object;
    [object addObserver: self
             forKeyPath: keyForUpdate
                options: NSKeyValueObservingOptionNew
     | NSKeyValueObservingOptionOld
                context: target];
    dot = [remainingKeyPath rangeOfString: @"."];
    if (dot.location != NSNotFound)
    {
        child = [[NSKeyValueObservationForwarder alloc]
                 initWithKeyPath: remainingKeyPath
                 ofObject: [object valueForKey: keyForUpdate]
                 withTarget: self
                 context: NULL];
        observedObjectForForwarding = nil;
    }
    else
    {
        keyForForwarding = [remainingKeyPath copy];
        observedObjectForForwarding = [object valueForKey: keyForUpdate];
        [observedObjectForForwarding addObserver: self
                                      forKeyPath: keyForForwarding
                                         options: NSKeyValueObservingOptionNew
         | NSKeyValueObservingOptionOld
                                         context: target];
        child = nil;
    }
    
    return self;
}

- (void) finalize
{
    if (child)
    {
        [child finalize];
    }
    if (observedObjectForUpdate)
    {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
    }
    if (observedObjectForForwarding)
    {
        [observedObjectForForwarding removeObserver: self forKeyPath:
         keyForForwarding];
    }
    DESTROY(self);
}

- (void) dealloc
{
    [keyForUpdate release];
    [keyForForwarding release];
    [keyPathToForward release];
    
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if (anObject == observedObjectForUpdate)
    {
        [self keyPathChanged: nil];
    }
    else
    {
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
    }
}

- (void) keyPathChanged: (id)objectToObserve
{
    if (objectToObserve != nil)
    {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
        observedObjectForUpdate = objectToObserve;
        [objectToObserve addObserver: self
                          forKeyPath: keyForUpdate
                             options: NSKeyValueObservingOptionNew
         | NSKeyValueObservingOptionOld
                             context: target];
    }
    if (child != nil)
    {
        [child keyPathChanged:
         [observedObjectForUpdate valueForKey: keyForUpdate]];
    }
    else
    {
        NSMutableDictionary *change;
        
        change = [NSMutableDictionary dictionaryWithObject:
                  [NSNumber numberWithInt: 1]
                                                    forKey:  NSKeyValueChangeKindKey];
        
        if (observedObjectForForwarding != nil)
        {
            id oldValue;
            
            oldValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
            [observedObjectForForwarding removeObserver: self forKeyPath:
             keyForForwarding];
            if (oldValue)
            {
                [change setObject: oldValue
                           forKey: NSKeyValueChangeOldKey];
            }
        }
        observedObjectForForwarding = [observedObjectForUpdate
                                       valueForKey:keyForUpdate];
        if (observedObjectForForwarding != nil)
        {
            id newValue;
            
            [observedObjectForForwarding addObserver: self
                                          forKeyPath: keyForForwarding
                                             options: NSKeyValueObservingOptionNew
             | NSKeyValueObservingOptionOld
                                             context: target];
            //prepare change notification
            newValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
            if (newValue)
            {
                [change setObject: newValue forKey: NSKeyValueChangeNewKey];
            }
        }
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
    }
}

@end
