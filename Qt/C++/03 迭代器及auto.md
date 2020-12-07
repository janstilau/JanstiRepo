# 迭代器及类型推导

#### 迭代器

stl中存在一些常见的已经封装好（开箱即食）数据结构相关的模板类，例如vector(动态数组)，list(链表), stack(栈)，queue(队列)，map（hash表/红黑树）等。这些类通常都有一些最基本的操作，例如：增加，删除，修改，遍历等等。

C++为了方便统一，采用了设计模式中的迭代器模式，也就是统一的提供了一种方法顺序访问一个聚合对象中的各种元素，而又不暴露该对象的内部表示。我们一般对这些数据结构的遍历都可以无脑使用迭代器，而不关心内部存储的差异。

```c++
#include "stdafx.h"
#include <iostream>
#include <vector>
#include <list>

int main()
{
    //普通的数组, 一旦申请，不能再扩增
    int ary[5] = { 1, 2, 3, 4, 5 };
    //int* pAry = new int[5];
    //for (int i = 0; i < sizeof(ary); i++){
    //    std::cout << ary[i] << std::endl;
    //}

    //容器---动态数组 不用指定其大小，会根据数组当前的使用情况进行动态的扩容
    //模板类型
    std::vector<int> v;

    //插入数据
    v.push_back(1);
    v.push_back(2);
    v.push_back(3);
    v.push_back(4);
    v.push_back(5);

    //for (int i = 0; i < v.size(); i++){
    //    std::cout << v[i] << std::endl;
    //}

    //使用迭代器的方式遍历数组
    std::vector<int>::iterator it; //迭代器，模板类中的内部类
    for (it = v.begin(); it != v.end(); it++){
        std::cout << *it << std::endl; //* it 来访问模板类的具体的值
    }

    //统一的遍历方式 链表
    std::list<std::string> l;
    l.push_back("hello1");
    l.push_back("hello2");
    l.push_back("hello3");

    //for (std::list<std::string>::iterator it2 = l.begin(); it2 != l.end(); it2++) {
    //    std::cout << (*it2).c_str() << std::endl; //* it 来访问模板类的具体的值
    //}

    //auto 类型推导关键字
    //for (auto it2 = l.begin(); it2 != l.end(); it2++) {
    //    std::cout << (*it2).c_str() << std::endl; //* it 来访问模板类的具体的值
    //}


    //for(std::string str : l){
    //    std::cout << str.c_str() << std::endl;
    //}

    for (auto str : l){
        std::cout << str.c_str() << std::endl;
    }

    return 0;
}
```



在传统 C 和 C++中，参数的类型都必须明确定义，这其实对我们快速进行编码没有任何帮助，尤其是当我们面对一大堆复杂的模板类型时，必须明确的指出变量的类型才能进行后续的编码，这不仅拖慢我们的开发效率，也让代码变得又臭又长。

C++ 11 引入了 `auto` 和 `decltype` 这两个关键字实现了类型推导，让编译器来操心变量的类型。这使得 C++ 也具有了和其他现代编程语言一样，某种意义上提供了无需操心变量类型的使用习惯。

#### auto

`auto` 在很早以前就已经进入了 C++，但是他始终作为一个存储类型的指示符存在，与 `register` 并存。在传统 C++ 中，如果一个变量没有声明为 `register` 变量，将自动被视为一个 `auto` 变量。而随着 `register` 被弃用，对 `auto` 的语义变更也就非常自然了。

使用 `auto` 进行类型推导的一个最为常见而且显著的例子就是迭代器。在以前我们需要这样来书写一个迭代器：

```cpp
for(vector<int>::const_iterator itr = vec.cbegin(); itr != vec.cend(); ++itr)
```

而有了 `auto` 之后可以：

```cpp
// 由于 cbegin() 将返回 vector<int>::const_iterator 
// 所以 itr 也应该是 vector<int>::const_iterator 类型
for(auto itr = vec.cbegin(); itr != vec.cend(); ++itr);
```

一些其他的常见用法：

```cpp
auto i = 5;             // i 被推导为 int
auto arr = new auto(10) // arr 被推导为 int *
```

**注意**：`auto` 不能用于函数传参，因此下面的做法是无法通过编译的（考虑重载的问题，我们应该使用模板）：

```cpp
int add(auto x, auto y);
```

此外，`auto` 还不能用于推导数组类型：

```cpp
#include <iostream>

int main() {
 auto i = 5;

 int arr[10] = {0};
 auto auto_arr = arr;
 auto auto_arr2[10] = arr;

 return 0;
}
```