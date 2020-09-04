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
	struct objc_protocol_list *protocols; // 分类中声明自己实现的协议.
	struct objc_property_list *properties; // 分类中的属性
	struct objc_property_list *class_properties; // ???
};

