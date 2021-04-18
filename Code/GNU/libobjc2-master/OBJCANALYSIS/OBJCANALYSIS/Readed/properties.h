#include "visibility.h"
#include <assert.h>

enum PropertyAttributeKind 
{
	/**
	 * Property has no attributes.
	 */
	OBJC_PR_noattr    = 0x00,
	/**
	 * The property is declared read-only.
	 */
	OBJC_PR_readonly  = (1<<0), 0000 0001
	/**
	 * The property has a getter.
	 */
	OBJC_PR_getter    = (1<<1), 0000 0010
	/**
	 * The property has assign semantics.
	 */
	OBJC_PR_assign    = (1<<2), 0000 0100
	/**
	 * The property is declared read-write.
	 */
	OBJC_PR_readwrite = (1<<3), 0000 1000
	/**
	 * Property has retain semantics.
	 */
	OBJC_PR_retain    = (1<<4), 0001 0000
	/**
	 * Property has copy semantics.
	 */
	OBJC_PR_copy      = (1<<5), 0010 0000
	/**
	 * Property is marked as non-atomic.
	 */
	OBJC_PR_nonatomic = (1<<6), 0100 0000
	/**
	 * Property has setter.
	 */
	OBJC_PR_setter    = (1<<7) 1000 0000
};

// begin: objc_property
/*
 1.property_attribute为T@”NSString”,&,N,V_exprice时：
 T 是固定的，放在第一个
 @”NSString” 代表这个property是一个字符串对象
 & 代表强引用，其中与之并列的是：’C’代表Copy，’&’代表强引用，’W’表示weak，assign为空，默认为assign。
 N 区分的nonatomic和atomic，默认为atomic，atomic为空，’N’代表是nonatomic
 V_exprice V代表变量，后面紧跟着的是成员变量名，代表这个property的成员变量名为_exprice。

 2.property_attribute为T@”NSNumber”,R,N,V_yearsOld时：
 T 是固定的，放在第一个
 @”NSNumber” 代表这个property是一个NSNumber对象
 R 代表readOnly属性，readwrite时为空
 N 区分的nonatomic和atomic，默认为atomic，atomic为空，’N’代表是nonatomic
 V_yearsOld V代表变量，后面紧跟着的是成员变量名，代表这个property的成员变量名为_yearsOld。

 3.对应的编码值
 //下面对应的编码值可以在官方文档里面找到
 //编码值   含意
 //c     代表char类型
 //i     代表int类型
 //s     代表short类型
 //l     代表long类型，在64位处理器上也是按照32位处理
 //q     代表long long类型
 //C     代表unsigned char类型
 //I     代表unsigned int类型
 //S     代表unsigned short类型
 //L     代表unsigned long类型
 //Q     代表unsigned long long类型
 //f     代表float类型
 //d     代表double类型
 //B     代表C++中的bool或者C99中的_Bool
 //v     代表void类型
 //*     代表char *类型
 //@     代表对象类型
 //#     代表类对象 (Class)
 //:     代表方法selector (SEL)
 //[array type]  代表array
 //{name=type…}  代表结构体
 //(name=type…)  代表union
 //bnum  A bit field of num bits
 //^type     A pointer to type
 //?     An unknown type (among other things, this code is used for function pointers)

 4.其他
 G(name) getter=(name)
 S(name) setter=(name)
 D @dynamic
 P 用于垃圾回收机制
 */
struct objc_property
{
	const char *name;
    /*
     一串, 关于 property 的描述信息. 例如.
     property_attr:T@"NSString",&,N,V_name,
     */
	const char *attributes;
	/**
	 * The type encoding of the property.
	 */
	const char *type;
	/**
	 * The selector for the getter for this property.
	 */
	SEL getter;
	/**
	 * The selector for the setter for this property.
	 */
	SEL setter;
};
// end: objc_property

/*
 objc_property_list, 存储 分类里面, 或者类里面 关于属性的集合信息.
 */
// begin: objc_property_list
struct objc_property_list
{
	/**
	 * Number of properties in this array.
	 */
	int count;
	/**
	 * Size of `struct objc_property`.  This allows the runtime to
	 * transparently support newer ABIs with more fields in the property
	 * metadata.
	 */
	int size;
	/*
	 * The next property in a linked list.
	 */
	struct objc_property_list *next;
	/**
	 * List of properties.
	 */
	struct objc_property properties[];
};
// end: objc_property_list

/**
 * Returns a pointer to the property inside the `objc_property` structure.
 * This structure is designed to allow the compiler to add other fields without
 * breaking the ABI, so although the `properties` field appears to be an array
 * of `objc_property` structures, it may be an array of some future version of
 * `objc_property` structs, which have fields appended that this version of the
 * runtime does not know about.
 */
static inline struct objc_property *property_at_index(struct objc_property_list *l, int i)
{
	assert(l->size >= sizeof(struct objc_property));
	return (struct objc_property*)(((char*)l->properties) + (i * l->size));
}

/**
 * Constructs a property description from a list of attributes, returning the
 * instance variable name via the third parameter.
 */
PRIVATE struct objc_property propertyFromAttrs(const objc_property_attribute_t *attributes,
                                               unsigned int attributeCount,
                                               const char *name);

/**
 * Constructs and installs a property attribute string from the property
 * attributes and, optionally, an ivar string.
 */
PRIVATE const char *constructPropertyAttributes(objc_property_t property,
                                                const char *iVarName);
