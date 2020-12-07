# auto_ptr

> class template
>
> <memory>
>
> # std::auto_ptr
>
> ```
> template <class X> class auto_ptr;
> ```
>
> Automatic Pointer [deprecated]

 从官网的文档上就可以看出，这个auto_ptr指针不推荐使用(deprecated)，原因这里也有说明：

> **Note:** This class template is deprecated as of C++11. [unique_ptr](http://www.cplusplus.com/unique_ptr) is a new facility with a similar functionality, but with improved security (no fake copy assignments), added features (*deleters*) and support for arrays. See [unique_ptr](http://www.cplusplus.com/unique_ptr) for additional information.

 **解释**：auto_ptr指针在c++11标准中就被废除了，可以使用unique_ptr来替代，功能上是相同的，unique_ptr相比较auto_ptr而言，提升了安全性（没有浅拷贝），增加了特性（delete析构）和对数组的支持。



>  This class template provides a limited *garbage collection* facility for pointers, by allowing pointers to have the elements they point to automatically destroyed when the *auto_ptr* object is itself destroyed.

 **解释**：这个类模板提供了有限度的垃圾回收机制，通过将一个指针保存在auto_ptr对象中，当auto_ptr对象析构时，这个对象所保存的指针也会被析构掉。



> `auto_ptr` objects have the peculiarity of *taking ownership* of the pointers assigned to them: An `auto_ptr` object that has ownership over one element is in charge of destroying the element it points to and to deallocate the memory allocated to it when itself is destroyed. The destructor does this by calling `operator delete` automatically.

**解释**：  auto_ptr 对象拥有其内部指针的所有权。这意味着auto_ptr对其内部指针的释放负责，即当自身被释放时，会在析构函数中自动的调用delete，从而释放内部指针的内存。



> Therefore, no two `auto_ptr` objects should *own* the same element, since both would try to destruct them at some point. When an assignment operation takes place between two `auto_ptr` objects, *ownership* is transferred, which means that the object losing ownership is set to no longer point to the element (it is set to the *null pointer*).

解释：  

- 正因如此，不能有两个auto_ptr 对象拥有同一个内部指针的所有权，因为有可能在某个时机，两者均会尝试析构这个内部指针。

- 当**两个auto_ptr对象**之间发生**赋值**操作时，内部指针被拥有的所有权会发生转移，这意味着这个赋值的右者对象会丧失该所有权，不在指向这个内部指针（其会被设置成null指针）。



到这里，我们来看一下auto_ptr的提供的接口和使用方法：

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/e8cf20b5-92c4-492d-8640-e74991691dda/128/index_files/0fbfe140-81e6-40fe-a97e-b9fe13befeb9.png)

其中构造值得说一下：

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/e8cf20b5-92c4-492d-8640-e74991691dda/128/index_files/7fba329e-be79-4854-abcf-d9ea362f2cfd.png)

> Constructs an `auto_ptr` object either from a pointer or from another `auto_ptr` object.
> Since `auto_ptr` objects take ownership of the pointer they *point to*, when a new `auto_ptr` is constructed from another `auto_ptr`, the former owner *releases* it.

解释：  auto_ptr的构造的参数可以是一个指针，或者是另外一个auto_ptr对象。

- 当一个新的auto_ptr获取了内部指针的所有权后，之前的拥有者会释放其所有权。

**1.auto_ptr的构造及所有权的转移**

```c++
#include "stdafx.h"
#include <iostream>
#include <memory>
using namespace std;

int _tmain(int argc, _TCHAR* argv[])
{
	//通过指针进行构造
	std::auto_ptr<int> aptr(new int(3)); 
	
	printf("aptr %p : %d\r\n", aptr.get(), *aptr);
    
	//这样会编译出错，因为auto_ptr的构造有关键字explicit
	//explicit关键字表示调用构造函数时不能使用隐式赋值，而必须是显示调用
	//std::auto_ptr<int> aptr2 = new int(3); 

	//可以用其他的auto_ptr指针进行初始化
	std::auto_ptr<int> aptr2 = aptr;
	printf("aptr2 %p : %d\r\n", aptr2.get(), *aptr2);

	//但是这么内存访问出错，直接0xc05,因为aptr已经释放了其所有权。
	//*aptr = 4;
	printf("aptr %p\r\n", aptr.get());
	
	return 0;
}
```

**2.auto_ptr析构及资源的自动释放**

```C++
void foo_release()
{
	//释放
	int* pNew = new int(3);
	{
		std::auto_ptr<int> aptr(pNew);
	}

}
```

- 这里显然，当出了块作用域之后，aptr对象会自动调用析构，然后在析构中会自动的delete其内部指针，也就是出了这个作用域后，其内部指针就被释放了。

- 当然上面这种写法是不推荐的，因为我们这里本质上就是希望不去管理指针的释放工作，上面的写法就又需要程序员自己操心指针的问题，也就是使用**智能指针要避免出现指针的直接使用**！



在这里可以在使用前调用release，从而放弃其内部指针的使用权，但是同样这么做违背了智能指针的初衷。

```C++
void foo_release()
{
	//释放
	int* pNew = new int(3);
	{
		std::auto_ptr<int> aptr(pNew);
		int* p = aptr.release();
	}

}
```

**3.分配新的指针所有权**

  可以调用reset来重新分配指针的所有权，reset中会先释放原来的内部指针的内存，然后分配新的内部指针。

 

```
void foo_reset()
{
	//释放
	int* pNew = new int(3);
	int*p = new int(5);
	{
		std::auto_ptr<int> aptr(pNew);
		aptr.reset(p);

	}
}
```

**4.=运算符的使用**

```C++
void foo_assign()
{
	std::auto_ptr<int> p1;
	std::auto_ptr<int> p2;

	p1 = std::auto_ptr<int>(new int(3));
	*p1 = 4;
	p2 = p1;
}
```



#### auto_ptr存在的问题

为什么11标准会不让使用auto_ptr，原因是其使用有问题。

**1. 作为参数传递会存在问题。**

因为有拷贝构造和赋值的情况下，会释放原有的对象的内部指针，所以当有函数使用的是auto_ptr时，调用后会导致原来的内部指针释放。

```c++
void foo_test(std::auto_ptr<int> p)
{
	printf("%d\r\n", *p);
}

int _tmain(int argc, _TCHAR* argv[])
{
	std::auto_ptr<int> p1 = std::auto_ptr<int>(new int(3));
	foo_test(p1);

	//这里的调用就会出错，因为拷贝构造函数的存在，p1实际上已经释放了其内部指针的所有权了
	printf("%d\r\n", *p1);
	
	return 0;
}
```

**2. 不能使用vector数组**

因为数组的实现，所以这么定义会出错：

```c++
void foo_ary()
{
	std::vector<std::auto_ptr<int>> Ary;
	std::auto_ptr<int> p(new int(3));
	Ary.push_back(p);

	printf("%d\r\n", *p);

}
```

