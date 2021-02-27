#ifndef QTCONCURRENT_FUNCTIONWRAPPERS_H
#define QTCONCURRENT_FUNCTIONWRAPPERS_H

#include <QtConcurrent/qtconcurrentcompilertest.h>
#include <QtCore/QStringList>

#if !defined(QT_NO_CONCURRENT) || defined(Q_CLANG_QDOC)

QT_BEGIN_NAMESPACE

namespace QtConcurrent {

// C++ 里面的泛型, 就是可以通过编译就可以. 所以, 可以写通用名称的算法.
// 但是, 名称是不固定的, 在 C++ 里面, 最通用的算法就是 operator 了.
// 所以, 各种 warpper, 其实就是包装可调用对象, 在 Operator () 中调用
// 下面的各个类, 不是直接使用的, 而是通过函数模板, 获得传入可调用对象的类型, 根据 参数个数, 可调用对象的类型, 选择正确的 warpper 类进行创建.

// 包装,  不带参数的函数指针.
template <typename T>
class FunctionWrapper0
{
public:
    typedef T (*FunctionPointerType)();
    typedef T result_type;
    inline FunctionWrapper0(FunctionPointerType _functionPointer)
    :functionPointer(_functionPointer) { }
    inline T operator()()
    {
        return functionPointer();
    }
private:
    FunctionPointerType functionPointer;
};

// 包装, 有一个参数的 函数指针
template <typename T, typename U>
class FunctionWrapper1
{
public:
    typedef T (*FunctionPointerType)(U u);
    typedef T result_type;
    inline FunctionWrapper1(FunctionPointerType _functionPointer)
    :functionPointer(_functionPointer) { }

    inline T operator()(U u)
    {
        return functionPointer(u);
    }

private:
    FunctionPointerType functionPointer;
};

// 包装有两个参数的函数指针
template <typename T, typename U, typename V>
class FunctionWrapper2
{
public:
    typedef T (*FunctionPointerType)(U u, V v);
    typedef T result_type;
    inline FunctionWrapper2(FunctionPointerType _functionPointer)
    :functionPointer(_functionPointer) { }

    inline T operator()(U u, V v)
    {
        return functionPointer(u, v);
    }
private:
    FunctionPointerType functionPointer;
};

// 包装, 类的成员函数, 没有参数. 注意, 调用的时候, 要传入对象引用
template <typename T, typename C>
class MemberFunctionWrapper
{
public:
    typedef T (C::*FunctionPointerType)();
    typedef T result_type;
    inline MemberFunctionWrapper(FunctionPointerType _functionPointer)
    :functionPointer(_functionPointer) { }

    inline T operator()(C &c)
    {
        return (c.*functionPointer)();
    }
private:
    FunctionPointerType functionPointer;
};

// 带有参数的对象成员函数.
template <typename T, typename C, typename U>
class MemberFunctionWrapper1
{
public:
    typedef T (C::*FunctionPointerType)(U);
    typedef T result_type;

    inline MemberFunctionWrapper1(FunctionPointerType _functionPointer)
        : functionPointer(_functionPointer)
    { }

    inline T operator()(C &c, U u)
    {
        return (c.*functionPointer)(u);
    }

private:
    FunctionPointerType functionPointer;
};

// 带有 const 性质的对象成员函数, 传入的时候, 对象是 const 修饰的引用
template <typename T, typename C>
class ConstMemberFunctionWrapper
{
public:
    typedef T (C::*FunctionPointerType)() const;
    typedef T result_type;
    inline ConstMemberFunctionWrapper(FunctionPointerType _functionPointer)
    :functionPointer(_functionPointer) { }

    inline T operator()(const C &c) const
    {
        return (c.*functionPointer)();
    }
private:
    FunctionPointerType functionPointer;
};

} // namespace QtConcurrent.

namespace QtPrivate {

// 以下, 就是根据可调用对象的类型, 使用函数模板, 生成上面各个类型的对象实例.

// 如果, 传递过来的是一个函数对象, 那么直接返回.
template <typename T>
const T& createFunctionWrapper(const T& t)
{
    return t;
}

template <typename T, typename U>
QtConcurrent::FunctionWrapper1<T, U> createFunctionWrapper(T (*func)(U))
{
    return QtConcurrent::FunctionWrapper1<T, U>(func);
}

template <typename T, typename C>
QtConcurrent::MemberFunctionWrapper<T, C> createFunctionWrapper(T (C::*func)())
{
    return QtConcurrent::MemberFunctionWrapper<T, C>(func);
}

template <typename T, typename C, typename U>
QtConcurrent::MemberFunctionWrapper1<T, C, U> createFunctionWrapper(T (C::*func)(U))
{
    return QtConcurrent::MemberFunctionWrapper1<T, C, U>(func);
}

template <typename T, typename C>
QtConcurrent::ConstMemberFunctionWrapper<T, C> createFunctionWrapper(T (C::*func)() const)
{
    return QtConcurrent::ConstMemberFunctionWrapper<T, C>(func);
}

template <typename T, typename U>
QtConcurrent::FunctionWrapper1<T, U> createFunctionWrapper(T (*func)(U) noexcept)
{
    return QtConcurrent::FunctionWrapper1<T, U>(func);
}

template <typename T, typename C>
QtConcurrent::MemberFunctionWrapper<T, C> createFunctionWrapper(T (C::*func)() noexcept)
{
    return QtConcurrent::MemberFunctionWrapper<T, C>(func);
}

template <typename T, typename C, typename U>
QtConcurrent::MemberFunctionWrapper1<T, C, U> createFunctionWrapper(T (C::*func)(U) noexcept)
{
    return QtConcurrent::MemberFunctionWrapper1<T, C, U>(func);
}

template <typename T, typename C>
QtConcurrent::ConstMemberFunctionWrapper<T, C> createFunctionWrapper(T (C::*func)() const noexcept)
{
    return QtConcurrent::ConstMemberFunctionWrapper<T, C>(func);
}








struct PushBackWrapper
{
    typedef void result_type;

    template <class C, class U>
    inline void operator()(C &c, const U &u) const
    {
        return c.push_back(u);
    }

    template <class C, class U>
    inline void operator()(C &c, U &&u) const
    {
        return c.push_back(u);
    }
};

template <typename Functor, bool foo = HasResultType<Functor>::Value>
struct LazyResultType { typedef typename Functor::result_type Type; };
template <typename Functor>
struct LazyResultType<Functor, false> { typedef void Type; };

template <class T>
struct ReduceResultType;

template <class U, class V>
struct ReduceResultType<void(*)(U&,V)>
{
    typedef U ResultType;
};

template <class T, class C, class U>
struct ReduceResultType<T(C::*)(U)>
{
    typedef C ResultType;
};

template <class U, class V>
struct ReduceResultType<void(*)(U&,V) noexcept>
{
    typedef U ResultType;
};

template <class T, class C, class U>
struct ReduceResultType<T(C::*)(U) noexcept>
{
    typedef C ResultType;
};

template <class InputSequence, class MapFunctor>
struct MapResultType
{
    typedef typename LazyResultType<MapFunctor>::Type ResultType;
};

template <class U, class V>
struct MapResultType<void, U (*)(V)>
{
    typedef U ResultType;
};

template <class T, class C>
struct MapResultType<void, T(C::*)() const>
{
    typedef T ResultType;
};

template <class U, class V>
struct MapResultType<void, U (*)(V) noexcept>
{
    typedef U ResultType;
};

template <class T, class C>
struct MapResultType<void, T(C::*)() const noexcept>
{
    typedef T ResultType;
};

#ifndef QT_NO_TEMPLATE_TEMPLATE_PARAMETERS

template <template <typename> class InputSequence, typename MapFunctor, typename T>
struct MapResultType<InputSequence<T>, MapFunctor>
{
    typedef InputSequence<typename LazyResultType<MapFunctor>::Type> ResultType;
};

template <template <typename> class InputSequence, class T, class U, class V>
struct MapResultType<InputSequence<T>, U (*)(V)>
{
    typedef InputSequence<U> ResultType;
};

template <template <typename> class InputSequence, class T, class U, class C>
struct MapResultType<InputSequence<T>, U(C::*)() const>
{
    typedef InputSequence<U> ResultType;
};

template <template <typename> class InputSequence, class T, class U, class V>
struct MapResultType<InputSequence<T>, U (*)(V) noexcept>
{
    typedef InputSequence<U> ResultType;
};

template <template <typename> class InputSequence, class T, class U, class C>
struct MapResultType<InputSequence<T>, U(C::*)() const noexcept>
{
    typedef InputSequence<U> ResultType;
};
#endif

#endif // QT_NO_TEMPLATE_TEMPLATE_PARAMETER

template <class MapFunctor>
struct MapResultType<QStringList, MapFunctor>
{
    typedef QList<typename LazyResultType<MapFunctor>::Type> ResultType;
};

template <class U, class V>
struct MapResultType<QStringList, U (*)(V)>
{
    typedef QList<U> ResultType;
};

template <class U, class C>
struct MapResultType<QStringList, U(C::*)() const>
{
    typedef QList<U> ResultType;
};


template <class U, class V>
struct MapResultType<QStringList, U (*)(V) noexcept>
{
    typedef QList<U> ResultType;
};

template <class U, class C>
struct MapResultType<QStringList, U(C::*)() const noexcept>
{
    typedef QList<U> ResultType;
};
#endif

} // namespace QtPrivate.


QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT

#endif
