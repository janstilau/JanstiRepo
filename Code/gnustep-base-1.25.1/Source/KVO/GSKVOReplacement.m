//
//  GSKVOReplacement.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOReplacement.h"

@implementation    GSKVOReplacement

- (void) dealloc
{
    DESTROY(keys);
    [super dealloc];
}
// 这里, 通过原始类, 进行了一次类的创造的工作. 因为, GSKVOReplacement 的获取的时候, 会有缓存机制, 所以这个创造工作其实也只会产生一次.
- (id) initWithClass: (Class)aClass
{
    NSValue        *template;
    NSString        *superName;
    NSString        *name;
    
    original = aClass;
    /*
     * Create subclass of the original, and override some methods
     * with implementations from our abstract base class.
     */
    superName = NSStringFromClass(original);
    name = [@"GSKVO" stringByAppendingString: superName];
    template = GSObjCMakeClass(name, superName, nil); // 创建了一个新的类.
    GSObjCAddClasses([NSArray arrayWithObject: template]);
    replacement = NSClassFromString(name);
    GSObjCAddClassBehavior(replacement, baseClass); // 这里, 将 baseClass, 也就是 GSKVOBase 里面的操作, 都添加到新类里面了.
    //GSKVOBase 里面的操作,是复写了 class 等操作的, 为的就是, 让使用者不能察觉这里有一个子类存在.
    
    /* Create the set of setter methods overridden.
     */
    keys = [NSMutableSet new];
    
    return self;
}
// 这是一个核心方法, 在这里, 进行了 set 的替换工作
// 举个例子. name
// 从这里我们也看到了, 如果直接操作成员变量, 是没有用的, 必须是通过方法调用才能进行 KVO 的工作.
- (void) overrideSetterFor: (NSString*)aKey // aKey == name
{
    // 一个类, 对应一个 ReplaceMent. 如果 keys 里面有了 aKey, 那么就是这个替换的工作就完成了.
    if ([keys member: aKey] != nil) { return; }
    
    IMP        imp;
    const char    *type;
    NSString          *suffix;
    NSString          *setSelName[2];
    BOOL              found = NO;
    NSString        *tmp;
    unichar u;
    
    suffix = [aKey substringFromIndex: 1]; // suffix == ame
    u = uni_toupper([aKey characterAtIndex: 0]); // u == N
    tmp = [[NSString alloc] initWithCharacters: &u length: 1];
    setSelName[0] = [NSString stringWithFormat: @"set%@%@:", tmp, suffix]; // a[0] == setName
    setSelName[1] = [NSString stringWithFormat: @"_set%@%@:", tmp, suffix]; // a[1] == _setName
    for (unsigned i = 0; i < 2; i++)
    {
        NSMethodSignature    *sig;
        SEL        sel;
        sel = NSSelectorFromString(setSelName[i]); //
        if (sel == 0)
        {
            continue;
        }
        sig = [original instanceMethodSignatureForSelector: sel];
        if (sig == 0)
        {
            continue;
        }
        
        // 但这里, 就拿到了 setValue 的 sel 和签名了.
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
        // 在这里, 拿到了 set 函数的参数值的类型
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
            case _C_LNG_LNG:
            case _C_ULNG_LNG:
                imp = [[GSKVOSetter class]
                       instanceMethodForSelector: @selector(setterLongLong:)];
                break;
            case _C_FLT:
                imp = [[GSKVOSetter class]
                       instanceMethodForSelector: @selector(setterFloat:)];
                break;
            case _C_DBL:
                imp = [[GSKVOSetter class]
                       instanceMethodForSelector: @selector(setterDouble:)];
                break;
            case _C_BOOL:
                imp = [[GSKVOSetter class]
                       instanceMethodForSelector: @selector(setterChar:)];
                break;
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
                    GSCodeBuffer    *b;
                    
                    b = cifframe_closure(sig, cifframe_callback);
                    [b retain];
                    imp = [b executable];
                    imp = 0;
                }
                break;
            default:
                imp = 0;
                break;
        }
        
        if (imp != 0)
        {
            if (class_addMethod(replacement /*新创建出来的类.*/, sel, imp, [sig methodType]))
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
}

- (Class) replacement
{
    return replacement;
}
@end
