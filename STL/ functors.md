# 仿函数 functors

这是程序最可能编写的东西, 用于 stl 的应用.
对于熟悉现在多种语言的将函数当做第一类型来看待的模式之后, functors 可以看做 c++ 将函数包装成对象的一种模式.
它的结构也很简单, 重载小括号就可以了.
算法里面, 可以接受一个函数或者仿函数, 或者说, 可以调用() 的东西, 用于算法里面的比较, 赋值, 复制等等操作.
我们经常这样写 sort(nums.begin(), nums.end(), less<int>());
这里, less<int>() 是什么, 其实就是一个仿函数类, 但是, 函数调用怎么能够传入一个类型呢, 所以(), 表示生成一个临时对象, 这个临时对象仅仅是 sort 的内部使用, 作为比较大小的函数使用了. stl 里面经常用到这样的临时对象. 算法通过 iterator 中定义的不同 category 进行分类的时候, 也是根据不同的 category 生成的临时对象, 调用了不同的函数.

```cpp
struct less : binary_function<_Tp, _Tp, bool>
{
    bool operator()(const _Tp& __x, const _Tp& __y) const
        {return __x < __y;}
};
```


```cpp

template <class T>
struct plus: public binary_function<T, T, T>
{
    T operator() (const T&x, const T&y) const
    {
        return x + y;
    }
};

template <class T>
struct minus: public binary_function<T, T, T>
{
    T operator()(const T& x, const T& y) const
    {
        return x - y;
    }

};

template <class T>
struct logic_and: public binary_function<T, T, bool>
{
    bool operator()(const T&x, const T& y) const
    {
        return x && y;
    }
};

template <class T>
struct equal_to: public binary_function<T, T, bool>
{
    bool operator()(const T& x, const T& y) const
    {
        return x == y;
    }
};

template <class T>
struct less: public binary_function<T, T, bool>
{
    bool operator()(const T& x, const T& y) const
    {
        return x < y;
    }
};

```

为什么标准库提供的仿函数, 都要继承某个 function, 而这个 function 里面其实什么都没做, 仅仅做了一些 typedef ???

``` cpp
struct _LIBCPP_TEMPLATE_VIS binary_function
{
    typedef _Arg1   first_argument_type;
    typedef _Arg2   second_argument_type;
    typedef _Result result_type;
}; // 这个类的对象的空间大小是多少呢? 0, 但是它的对象会是1, 这是实现的问题. 但是, 一旦他被继承了, 那么作为父类空间, 它还是0. 如果子类没有空间, 子类对象空间是1, 如果子类中有一个 char, 那么子类空间就是1, 而这个1指的是 char.
```

STL 中, 对 functors 其实是有要求的, 如果不继承, 在某些时候, 其实会因为不符合 STL 的算法的要求, 不能通过编译. 之前的继承, 想的仅仅是, 继承父类的数据, 父类的函数, 但是其实, 还有继承 typedef. 这在标准库里面用到的非常多.

仿函数, 如果想要成为一个 adaptable, 就要继承某些类来继承, 用来继承某些 类型的命名.

所以, 如果没有继承, 就没有这些 typedef, 就不能回答 adapter 的问题, 也就不能被 adapter 进行改造了.
