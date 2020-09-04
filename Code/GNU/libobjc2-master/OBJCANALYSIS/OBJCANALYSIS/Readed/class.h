#ifndef __OBJC_CLASS_H_INCLUDED
#define __OBJC_CLASS_H_INCLUDED
#include "visibility.h"
#include "objc/runtime.h"
#include <stdint.h>

/**
 * Overflow bitfield.  Used for bitfields that are more than 63 bits.
 */
struct objc_bitfield
{
	/**
	 * The number of elements in the values array.
	 */
	int32_t  length;
	/**
	 * An array of values.  Each 32 bits is stored in the native endian for the
	 * platform.
	 */
	int32_t values[0];
};

static inline BOOL objc_bitfield_test(uintptr_t bitfield, uint64_t field)
{
	if (bitfield & 1)
	{
		uint64_t bit = 1<<(field+1);
		return (bitfield & bit) == bit;
	}
	struct objc_bitfield *bf = (struct objc_bitfield*)bitfield;
	uint64_t byte = field / 32;
	if (byte >= bf->length)
	{
		return NO;
	}
	uint64_t bit = 1<<(field%32);
	return (bf->values[byte] & bit) == bit;
}

/*
 类对象的定义. 这个和苹果的实现不相符, 不过不妨碍理解.
 */
struct objc_class
{
	Class                      isa; // 原类的指针, 元类上存储了类对象的方法, 也就是类方法.
	Class                      super_class; // 父类的类对象的指针.
	const char                *name; // 类名, 父类和元类都要进行设置.
	long                       version;
	/**
	 * A bitfield containing various flags.  See the objc_class_flags
	 * enumerated type for possible values.  
	 */
    /*
     就是一个值的保存. 里面存储了各种 enum 相关的值, 根据位的与运算, 分别取出各个值. 和 isa 指针的获取一样.
     */
	unsigned long              info;
	
	long                       instance_size; // 对象的大小. alloc 的时候, 就是拿到这个大小去开辟内存空间.

	struct objc_ivar_list     *ivars; // 成员列表的元信息.
	
	struct objc_method_list   *methods; // 方法列表的元信息.
    
    struct objc_protocol_list *protocols; // 协议列表的元信息
    
    struct objc_property_list *properties; // 属性列表的元信息
    
	/**
	 * The dispatch table for this class.  Intialized and maintained by the
	 * runtime.
	 */
	void                      *dtable;
	/**
	 * A pointer to the first subclass for this class.  Filled in by the
	 * runtime.
	 */
	Class                      subclass_list;
	/**
	 * Pointer to the .cxx_construct method if one exists.  This method needs
	 * to be called outside of the normal dispatch mechanism.
	 */
	IMP                        cxx_construct;
	/**
	 * Pointer to the .cxx_destruct method if one exists.  This method needs to
	 * be called outside of the normal dispatch mechanism.
	 */
	IMP                        cxx_destruct;
	/**
	 * A pointer to the next sibling class to this.  You may find all
	 * subclasses of a given class by following the subclass_list pointer and
	 * then subsequently following the sibling_class pointers in the
	 * subclasses.
	 */
	Class                      sibling_class;

	/**
	 * Linked list of extra data attached to this class.
	 */
	struct reference_list     *extra_data;
	/**
	* The version of the ABI used for this class.  Currently always zero for v2
	* ABI classes.
	*/
	long                       abi_version;
	
};
// end: objc_class

/**
 * An enumerated type describing all of the valid flags that may be used in the
 * info field of a class.
 */
enum objc_class_flags
{
	/** This class structure represents a metaclass. */
	objc_class_flag_meta = (1<<0),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved1 = (1<<1),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved2 = (1<<2),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved3 = (1<<3),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved4 = (1<<4),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved5 = (1<<5),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved6 = (1<<6),
	/** Reserved for future ABI versions. */
	objc_class_flag_reserved7 = (1<<7),
	/**
	 * This class has been sent a +initalize message.  This message is sent
	 * exactly once to every class that is sent a message by the runtime, just
	 * before the first other message is sent.
	 */
	objc_class_flag_initialized = (1<<8),
	/** 
	 * The class has been initialized by the runtime.  Its super_class pointer
	 * should now point to a class, rather than a C string containing the class
	 * name, and its subclass and sibling class links will have been assigned,
	 * if applicable.
	 */
    /*
     
     */
	objc_class_flag_resolved = (1<<9),
	/**
	 * This class was created at run time and may be freed.
	 */
	objc_class_flag_user_created = (1<<10),
	/** 
	 * Instances of this class are provide ARC-safe retain / release /
	 * autorelease implementations.
	 */
	objc_class_flag_fast_arc = (1<<11),
	/**
	 * This class is a hidden class (should not be registered in the class
	 * table nor returned from object_getClass()).
	 */
	objc_class_flag_hidden_class = (1<<12),
	/**
	 * This class is a hidden class used to store associated values.
	 */
	objc_class_flag_assoc_class = (1<<13),
	/**
	 * This class has instances that are never deallocated and are therefore
	 * safe to store directly into weak variables and to skip all reference
	 * count manipulations.
	 */
	objc_class_flag_permanent_instances = (1<<14)
};

/**
 * Sets the specific class flag.  Note: This is not atomic.
 */
static inline void objc_set_class_flag(Class aClass,
                                       enum objc_class_flags flag)
{
	aClass->info |= (unsigned long)flag;
}
/**
 * Unsets the specific class flag.  Note: This is not atomic.
 */
static inline void objc_clear_class_flag(Class aClass,
                                         enum objc_class_flags flag)
{
	aClass->info &= ~(unsigned long)flag;
}
/**
 * Checks whether a specific class flag is set.
 */
static inline BOOL objc_test_class_flag(Class aClass,
                                        enum objc_class_flags flag)
{
	return (aClass->info & (unsigned long)flag) == (unsigned long)flag;
}


/**
 * Adds a class to the class table.
 */
void class_table_insert(Class cls);

/**
 * Removes a class from the class table.  Must be called with the runtime lock
 * held!
 */
void class_table_remove(Class cls);

/**
 * Array of classes used for small objects.  Small objects are embedded in
 * their pointer.  In 32-bit mode, we have one small object class (typically
 * used for storing 31-bit signed integers.  In 64-bit mode then we can have 7,
 * because classes are guaranteed to be word aligned. 
 */
extern Class SmallObjectClasses[7];

static BOOL isSmallObject(id obj)
{
	uintptr_t addr = ((uintptr_t)obj);
	return (addr & OBJC_SMALL_OBJECT_MASK) != 0;
}

/*
 直接获取 obj 的 isa 信息.
 */
__attribute__((always_inline))
static inline Class classForObject(id obj)
{
	if (UNLIKELY(isSmallObject(obj)))
	{
		if (sizeof(Class) == 4)
		{
			return SmallObjectClasses[0];
		}
		else
		{
			uintptr_t addr = ((uintptr_t)obj);
			return SmallObjectClasses[(addr & OBJC_SMALL_OBJECT_MASK)];
		}
	}
	return obj->isa;
}

static inline BOOL classIsOrInherits(Class cls, Class base)
{
	for (Class c = cls ;
		Nil != c ;
		c = c->super_class)
	{
		if (c == base) { return YES; }
	}
	return NO;
}

/**
 * Free the instance variable lists associated with a class.
 */
void freeIvarLists(Class aClass);
/**
 * Free the method lists associated with a class.
 */
void freeMethodLists(Class aClass);

#endif //__OBJC_CLASS_H_INCLUDED
