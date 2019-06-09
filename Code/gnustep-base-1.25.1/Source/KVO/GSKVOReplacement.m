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
    DESTROY(_observeredKeys);
    [super dealloc];
}

- (id) initWithClass: (Class)aClass
{
    _original = aClass;
    [self setupReplaceMent];
    _observeredKeys = [NSMutableSet new];
    
    return self;
}

/*
 * Create subclass of the _original, and override some methods
 * with implementations from our abstract base class.
 */
- (void)setupReplaceMent {
    NSString *superName = NSStringFromClass(_original);
    NSString *name = [@"GSKVO" stringByAppendingString: superName];
    NSValue *template = GSObjCMakeClass(name, superName, nil); 
    GSObjCAddClasses([NSArray arrayWithObject: template]);
    _replacement = NSClassFromString(name);
    Class baseClass = NSClassFromString(@"GSKVOBase");
    /**
     *  这里, 就是讲 baseClass 里面的实现, 加到新创建出来的类中,
        这些添加的方法包括, class 方法, superClass 方法, setValueForKey 方法.
     */
    GSObjCAddClassBehavior(_replacement, baseClass);
    
}

// 这是一个核心方法, 在这里, 进行了 set 的替换工作
// 举个例子. name
// 从这里我们也看到了, 如果直接操作成员变量, 是没有用的, 必须是通过方法调用才能进行 KVO 的工作.
- (void) overrideSetterFor: (NSString*)aKey // aKey == name
{
    // 一个类, 对应一个 _replacement. 如果 _observeredKeys 里面有了 aKey, 那么就是这个替换的工作就完成了.
    if ([_observeredKeys member: aKey] != nil) { return; }
    
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
        sig = [_original instanceMethodSignatureForSelector: sel];
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
            if (class_addMethod(_replacement /*新创建出来的类.*/, sel, imp, [sig methodType]))
            {
                found = YES;
            }
            else
            {
                NSLog(@"Failed to add setter method for %s to %s",
                      sel_getName(sel), class_getName(_original));
            }
        }
    }
    
    if (found == YES)
    {
        [_observeredKeys addObject: aKey];
    }
}

- (Class) replacement
{
    return _replacement;
}
@end
