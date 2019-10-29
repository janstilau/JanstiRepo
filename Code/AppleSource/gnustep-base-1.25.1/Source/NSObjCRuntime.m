#import "common.h"

#if !defined (__GNU_LIBOBJC__)
#  include <objc/encoding.h>
#endif

#import "Foundation/NSException.h"

/**
 * Returns a string object containing the name for
 * aProtocol.  If aProtocol is 0, returns nil.
 // aProtocol 应该存储了自己的 name.
 */
NSString *
NSStringFromProtocol(Protocol *aProtocol)
{
  if (aProtocol != (Protocol*)0)
    return [NSString stringWithUTF8String: protocol_getName(aProtocol)];
  return nil;
}

/**
 * Returns the protocol whose name is supplied in the
 * aProtocolName argument, or 0 if a nil string is supplied.
 // 从源码中显示, 也是用一个 map 中寻找 protocol 对象.
 */
Protocol *   
NSProtocolFromString(NSString *aProtocolName)
{
  if (aProtocolName != nil)
    {
      int	len = [aProtocolName length];
      char	buf[len+1];

      [aProtocolName getCString: buf
		      maxLength: len + 1
		       encoding: NSASCIIStringEncoding];
      return GSProtocolFromName (buf);
    }
  return (Protocol*)0;
}

/**
 * Returns a string object containing the name for
 * aSelector.  If aSelector is 0, returns nil.
 */
NSString *
NSStringFromSelector(SEL aSelector)
{
  if (aSelector != (SEL)0)
    return [NSString stringWithUTF8String: sel_getName(aSelector)];
  return nil;
}

/*
 这么看, SEL 其实是一个数据结构, 并且开始一定是方法名.
 const char *sel_getName(SEL sel)
 {
 if (!sel) return "<null selector>";
 return (const char *)(const void*)sel;
 }
 */

/**
 * Returns (creating if necessary) the selector whose name is supplied in the
 * aSelectorName argument, or 0 if a nil string is supplied.
 这里, sel_registerName 个人觉得不太好, 这既是一个 get 方法, 又是一个修改了SEL缓存的方法. 所以, 这个方法有着副作用.
 */
SEL
NSSelectorFromString(NSString *aSelectorName)
{
  if (aSelectorName != nil)
    {
      int	len = [aSelectorName length];
      char	buf[len+1];

      [aSelectorName getCString: buf
		      maxLength: len + 1
		       encoding: NSASCIIStringEncoding];
      return sel_registerName (buf);
    }
  return (SEL)0;
}

/**
 * Returns the class whose name is supplied in the
 * aClassName argument, or Nil if a nil string is supplied.
 * If no such class has been loaded, the function returns Nil.
 也就是说, 在 load 的过程中, 进行了数据的收集和存储工作.
 */
Class
NSClassFromString(NSString *aClassName)
{
  if (aClassName != nil)
    {
      int	len = [aClassName length];
      char	buf[len+1]; // 建立缓存

      [aClassName getCString: buf
		   maxLength: len + 1
		    encoding: NSASCIIStringEncoding];
      // 从 NSString 中, 抽取出 ascii 的字符串来.
        // 然后调用底层的方法.
        // 这个方法会到 look_up_class 中, 也就是到了 objc 的源码. 从源码里可以看到, class 也是通过一个 map 进行的存储, name 作为 key 值.
        // 这里, 类还有一个 realize 的概念, 只有 releasize 的类, 才能真正的使用. 在这个过程里面, 会设置 class 的 rwt 和 rot 的信息. 其实, 这两个东西就是属性列表, 方法列表这些东西, 只不过在 objc-2 里面, 进行了新的组织方式.
        
      return objc_lookUpClass (buf);
    }
  return (Class)0;
}

/**
 * Returns an [NSString] object containing the class name for
 * aClass.  If aClass is 0, returns nil.
 */
NSString *
NSStringFromClass(Class aClass)
{
  if (aClass != (Class)0)
    return [NSString stringWithUTF8String: (char*)class_getName(aClass)];
  return nil;
}

/**
 * When provided with a C string containing encoded type information,
 * this method extracts size and alignment information for the specified
 * type into the buffers pointed to by sizep and alignp.<br />
 * If either sizep or alignp is a null pointer, the corresponding data is
 * not extracted.<br />
 * The function returns a pointer into the type information C string
 * immediately after the decoded information.
 */
const char *
NSGetSizeAndAlignment(const char *typePtr,
  NSUInteger *sizep, NSUInteger *alignp)
{
  if (typePtr != NULL)
    {
      /* Skip any offset, but don't call objc_skip_offset() as that's buggy.
       */
      if (*typePtr == '+' || *typePtr == '-')
	{
	  typePtr++;
	}
      while (isdigit(*typePtr))
	{
	  typePtr++;
	}
      typePtr = objc_skip_type_qualifiers (typePtr);
      if (sizep)
	{
          *sizep = objc_sizeof_type (typePtr);
	}
      if (alignp)
	{
          *alignp = objc_alignof_type (typePtr);
	}
      typePtr = objc_skip_typespec (typePtr);
    }
  return typePtr;
}

