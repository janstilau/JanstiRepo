# KVC

## GNUStep 实现

- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    这个方法, 首先把 akey 转化成为 C 字符串, 然后调用它的SetValueForKey(self, anObject, key, size);方法, 
    其中, size 就是 key 转换后的字符串的大小
}

SetValueForKey(NSObject *self, id anObject, const char *key, unsigned size)
{
    这个方法, 首先会拼接出来 _setKey 字符串来
    然后, 首先会寻找 setKey 方法, sel = sel_getUid(name);
    如果 sel == 0, 也就是对象没有 setKey 方法, 就寻找 _setKey 方法,
    如果 sel == 0, 也就是对象没有 _setKey 方法
    它首先会问一下, [[self class] accessInstanceVariablesDirectly] 这个东西的返回值, 也就是当前类允许 kvc 的方法直接访问成员变量吗. 如果可以 
    它就把 _key 取出来, 然后调用 GSObjCFindVariable(self, name, &type, &size, &off)
    这个方法返回一个 Bool 值, 代表有没有这个成员变量. 如果没有, 还会拼接出  key, isKey, _isKey重新调用这个方法, 
    这个方法的 type, size, offset 都是输出参数. 如果有这个成员变量, 那么这个成员变量的信息, 都会存到这些输出参数里面.

    GSObjCFindVariable 的内部是调用了class_getInstanceVariable获取 Ivar 信息.
    如果获取到了 Ivar 信息, 就将 Ivar 的类型, size, offset 设置到传出参数里面.

    然后调用 GSObjCSetVal(self, key, anObject, sel, type, size, off);
    这个方法里面, sel 就是刚刚获取的 setKey 方法的 sel, type, size, off 就是刚刚获取的 Ivar 的信息, 所以, 这个方法是把所有的参数都传递了, 其中有些参数必然是无效的.

* This is used internally by the key-value coding methods, to set a
 * value in an object either via an accessor method (if sel is
 * supplied), or via direct access (if type, size, and offset are
 * supplied).<br />
 * Automatic conversion between NSNumber and C scalar types is performed.<br />
 * If type is null and can't be determined from the selector, the
 * [NSObject-handleTakeValue:forUnboundKey:] method is called to try
 * to set a value.
void
GSObjCSetVal(NSObject *self, const char *key, id val, SEL sel,
  const char *type, unsigned size, int offset) {
      在这个函数内部, 首先如果 sel 不为空, 那么就通过这个 sel 获取到函数签名, 然后通过这个函数签名, 获取到返回值类型, 赋值给 type. 如果经过这一步 type 还为空, 那么就调用[self setValue: val forUndefinedKey:] 因为通过直接成员变量赋值过来的, type 一定是有内容的.
      如果 value 为 nil, 就调用 setNilValueForKey, setnil 里面NSObject 的默认实现是抛出异常.
      然后就是一个大的 switch type, 根据不同的类型, {
          1. 如果 sel 不为空, 就取出对象的 imp, 然后转化成为相应的函数指针, 通过函数指针, 进行赋值操作. 
          2. 如果 sel 为空, 就通过 offset 的值, 找到对象的成员变量的指针, 直接通过成员变量的指针进行赋值操作/.
      }

  }
}


Get 方法的实现思路 和 set 方法差不多, 都是先找 selector, 然后找成员变量. 传递的参数个数和作用完全一样.
这里, if (sel == 0)  memcpy((char*)&v, ((char *)self + offset), sizeof(v)); 对于复杂的数据结构, 例如结构体, 取值是用了 memcpy 函数.


- (id) valueForKeyPath: (NSString*)aKey
{
  NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];

  if (r.length == 0)
    {
      return [self valueForKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      return [[self valueForKey: key] valueForKeyPath: path];
    }
}

而对于 keyPath 的实现, 是利用了递归, 先取出.前面的内容, 然后递归调用后面的字路径.


KVC 本身, 是不会造成 KVO的, 也就是 KVC 的 set 方法内部, 就是通过上述的 sel, 和 成员变量指针进行赋值的过程.
但是我们在 kvo 的时候, 确实是通过 KVC 就能出发监听方法.
这是在 KVO 的实现内部, 重写了 setValueForkey 方法.

AddObserverForkey 的方法里面, 会新创建一个类, 然后将添加监听的对象, 通过setClass 为这个新创建出来的对象进行类型更改. 而这个新创建出来的对象, 有一个 GSObjCAddClassBehavior(replacement, baseClass); 方法, 这个方法就是把右边的那个类的自定义方法, 全部添加到自己身上, 所以, 在 KVO 的时候, KVC 的那些方法才能触发监听. 这个时候的 KVC, 已经是下面的 KVC 了. 它里面, 已经有了 willChangeValueForKey 和 didChangeValueForKey 了.

@implementation	GSKVOBase
- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
  Class		c = [self class];
  void		(*imp)(id,SEL,id,id);

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