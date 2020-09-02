#include <assert.h>

/**
 * Metadata structure describing a method.  
 */
// begin: objc_method
struct objc_method
{
	IMP         imp; // 实际的函数指针
	SEL         selector; // SEL 数据, key 值
	const char *types; // 函数的签名符号
};
// end: objc_method

struct objc_method_gcc
{
	/**
	 * Selector used to send messages to this method.  The type encoding of
	 * this method should match the types field.
	 */
	SEL         selector;
	/**
	 * The type encoding for this selector.  Used only for introspection, and
	 * only required because of the stupid selector handling in the old GNU
	 * runtime.  In future, this field may be reused for something else.
	 */
	const char *types;
	/**
	 * A pointer to the function implementing this method.
	 */
	IMP         imp;
};

/*
 methods 的单向链表, 分类, 类的原始信息里面, 关于方法, 是存储的这个对象, 在各个对象的里面, 按序存储着每个 method.
 */
struct objc_method_list
{
	/*
	  下一个 objc_method_list 的地址.
	 */
	struct objc_method_list  *next;
	/*
	 * The number of methods in this list.
	 */
	int                       count;
	size_t                    size;
	/*
	 真正方法存储的地方, 是用数组进行的存储. 因为是数组, 所以需要 count 这个值来标明范围.
	 */
	struct objc_method        *methods;
};
// end: objc_method_list

/**
 * Returns a pointer to the method inside the `objc_method` structure.  This
 * structure is designed to allow the compiler to add other fields without
 * breaking the ABI, so although the `methods` field appears to be an array
 * of `objc_method` structures, it may be an array of some future version of
 * `objc_method` structs, which have fields appended that this version of the
 * runtime does not know about.
 */
static inline struct objc_method *method_at_index(struct objc_method_list *l, int i)
{
	assert(l->size >= sizeof(struct objc_method));
	return (struct objc_method*)(((char*)l->methods) + (i * l->size));
}

