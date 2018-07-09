# CPPExtension

## 转换函数 conversion function

```cpp
class Fraction
{
public:
    Fraction(int num, int den = 1)
            :mNumerator(num),
             mDenominator(den)
    {
    }
    operator double() const 
    {
        return double(mNumerator * 1.0 / mDenominator)
    }


private:
    int mNumerator;
    int mDenominator;
};

Fraction f(3, 5);
double d = 4 + f;
```

首先, 编译器会去寻找, 有没有全局的+函数, 它需要一个整数和 Fraction 作为参数. 没有, 然后他会去寻找, f 可以转成 int 或者浮点数吗, 也就是有没有转换函数. 这里, 如果定义了两个转换函数, int, double, main 里面会报错, 因为出现了歧义.

## pointer-linke class

``` cpp

template <typename T>
class share_prt
{
public:
    share_prt(T *p)
            : px(p)
    {

    }

    T& operator*() const {
        return *px;
    }

    T* operator->() const {
        return px;
    }

private:
    T * px;
    long *pn;
};

/*
 *  share_prt<Foo> sp(new Foo());
 *  sp->method() == > px->method(); 箭头符号虽然被消耗掉了, 但是箭头符号有个特殊的行为, 可以继续作用下去. 只有箭头符号这样.
 *  (*sp)q.method() ==> (*px).method()
 * */
```

迭代器也可以看做是一个智能指针. 但是一定要有个 ++, --


## function-like class 仿函数

任何东西, 只要能接受()操作符, 那么就可以认为是一个仿函数.