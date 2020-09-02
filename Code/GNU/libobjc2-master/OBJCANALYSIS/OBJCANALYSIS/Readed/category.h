#pragma once
/**
 * The structure used to represent a category.
 *
 * This provides a set of new definitions that are used to replace those
 * contained within a class.
 */

/*
 分类的信息,
 */

struct objc_category 
{
	const char                *name;
	const char                *class_name; // 分类应该关联的类
	struct objc_method_list   *instance_methods; // 分类中的实例方法,
	struct objc_method_list   *class_methods; // 分类中的类方法
	struct objc_protocol_list *protocols; // 分类中的协议
	struct objc_property_list *properties; // 分类中的属性
	struct objc_property_list *class_properties; // ???
};

struct objc_category_gcc
{
	/** 
	 * The name of this category.
	 */
	const char                *name;
	/**
	 * The name of the class to which this category should be applied.
	 */
	const char                *class_name;
	/**
	 * The list of instance methods to add to the class.
	 */
	struct objc_method_list_gcc   *instance_methods;
	/**
	 * The list of class methods to add to the class.
	 */
	struct objc_method_list_gcc   *class_methods;
	/**
	 * The list of protocols adopted by this category.
	 */
	struct objc_protocol_list *protocols;
};
