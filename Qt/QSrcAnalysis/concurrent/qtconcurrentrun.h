// Generated code, do not edit! Use generator at tools/qtconcurrent/generaterun/
#ifndef QTCONCURRENT_RUN_H
#define QTCONCURRENT_RUN_H

#include <QtConcurrent/qtconcurrentcompilertest.h>

#if !defined(QT_NO_CONCURRENT) || defined(Q_CLANG_QDOC)

#include <QtConcurrent/qtconcurrentrunbase.h>
#include <QtConcurrent/qtconcurrentstoredfunctioncall.h>

QT_BEGIN_NAMESPACE


// QFutureInterface<T> 是 Future 的真正实现部分, Future 共享 QFutureInterface 来达到多线程, 多个位置共享数据的目的.
// std::future 应该和 QFuture 对标
// std::task_packge 应该和 RunFunctionTaskBase 对标, 都是对于可调用对象的封装
// std::promise 在 Qt 里面没有对应的类, 不过, 它应该是提供了某个机制, 让 future 实际的数据可以发生改变. 所以可以传递给子线程, 来做 future 的 setValue 操作.
// std::async 函数, 应该就像 Qt::run 函数一样, 利用上面的几个类, 来完成异步任务这个概念的实际实现.

/*
QtConcurrent::run(QThreadPool::globalInstance(), function, ...);

Runs function in a separate thread. The thread is taken from the global QThreadPool.
Note that function may not run immediately; function will only be run once a thread becomes available

T is the same type as the return value of function. Non-void return values can be accessed via the QFuture::result() function.

这个模板, 基本就是 std::async 的 Qt 版本的实现, 可以用这里的实现, 去理解 std 的实现.

后面的代码过于繁琐, 主要是类成员函数, 异常, 无异常, const, 非 const, 等等细节太多.
不过总之就是生成了各种 taskWrapper, 这一层的 taskWrapper 的主要工作是, 存储可调用对象, 以及可调用对象的传入参数.

并且重写 void runFunctor() override 方法, runfunctor 是 run 方法的一环, 在这个方法里面, 会将存储的数据, 传入存储的操作中, 进行任务的真正调用.

而 runFunctor 什么时候调用, result 被设值之后如何使用, 是 RunFunctionTask 这一层的事情.

qtconcurrentrun.h, qtconcurrentstoredfunctioncall.h
这两文件里面, run 模板函数的设计, 以及背后的各个模板类的设计, 就是为了提供一个简单使用的 run 接口而已, 将各种可调用对象:
函数指针, 闭包, 类成员函数都被包装成各自独特的类, 这些类, 都符合 RunFunctionTask 的抽象.

模板这个技术, 提供了非常通用的接口, 而这个接口的上层, 也应该屏蔽各种类型实现的细节, 使用抽象进行任务的管理.
那么这个通用接口, 就需要去面对这种封装的复杂性.
函数可以自动推到出类型来, 然后将这些类型, 封装成接口对象. 一般来说, 这是一个通用接口的处理逻辑. 这层抽象, 是通用接口所服务的高层算法所要求的抽象, 属于高层.
*/


// 对外的接口, 仅仅是一个 run 方法, 这个方法接受一个 invokable 参数, 以及后面的参数. 如果有 return value, 那么就可以通过 future 来进行获取.
// 而实际上, 有这么多个模板来支持这个功能.


// 这些方法, 返回一个 task_package 对象, 是 new 出来的, 也就是说, 是需要内存管理的.
// 在这个对象内部, 会有 future 对象, 进行线程之间的同步处理.

namespace QtConcurrent {

// 当 可调用对象是一个无参, 返回值为 T 的函数指针时.
template <typename T> // T 有可能是 Void
QFuture<T> run(T (*functionPointer)())
{
    // 生成一个 StoredFunctorCall0 对象, 调用 start 方法.
    return (new StoredFunctorCall0<T, T (*)()> (functionPointer))   ->start();
}

// 当 可调用对象, 是一个参数为Param1, 返回值是 T 的函数指针时, 传递的参数是 Arg1 类型的.
// 这里可以看出, 传递的参数, 有可能和可调用参数是不一致的. 所以, 实际 StoredFunctorCall1 内部调用的时候, 应该会有类型转化.
template <typename T, typename Param1, typename Arg1>
QFuture<T> run(T (*functionPointer)(Param1), const Arg1 &arg1)
{
    // 生成一个 StoredFunctorCall1 对象, 调用 start 方法. StoredFunctorCall1 带参了
    return (new StoredFunctorCall1<T, T (*)(Param1), Arg1>(functionPointer, arg1))->start();
}

// 当可调用对象, 有两个参数, 一个 Param1, 一个Param2, 传入两个参数, Arg1, Arg2
// 处理的过程和, StoredFunctorCall1 类似.
// 所以这就是模板的作用.提供的是一个统一的接口, 但是实际上, 生成不同类型的对象, 去完成同样的工作.
// 这个过程, 是必须实现的, 因为存储相应数据, 如何调用可调用对象都是不同的. 但是接口层, 用户看不到这些.
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(T (*functionPointer)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<T, T (*)(Param1, Param2), Arg1, Arg2>(functionPointer, arg1, arg2))->start();
}

// 三个参数版本的实现, 处理的逻辑类似, 但是这个过程不可缺少, 因为, 模板, 就是要处理各种复杂的实现细节.
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<T, T (*)(Param1, Param2, Param3), Arg1, Arg2, Arg3>(functionPointer, arg1, arg2, arg3))->start();
}

// 四个参数版本的实现.
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<T, T (*)(Param1, Param2, Param3, Param4), Arg1, Arg2, Arg3, Arg4>(functionPointer, arg1, arg2, arg3, arg4))->start();
}

// 五个参数版本的实现.
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<T, T (*)(Param1, Param2, Param3, Param4, Param5), Arg1, Arg2, Arg3, Arg4, Arg5>(functionPointer, arg1, arg2, arg3, arg4, arg5))->start();
}





// template <bool, class _Tp = void> struct enable_if {};
// template <class _Tp> struct enable_if<true, _Tp> {typedef _Tp type;};
/*
 * 这里的处理逻辑是, 使用 Functor, QtPrivate::HasResultType 来构造一个 enable_if struct, 这个 struct 里面, 仅仅有一个 typedef.
 * 如果, !QtPrivate::HasResultType<Functor>::Value 为 Yes, 就使用 QFuture<decltype(functor())> 的::type 作为返回值
 * 如果, !QtPrivate::HasResultType<Functor>::Value 为 No, 编译就不通过.
 */
// 这里实现细节不做专门要求, 有点难. 总之, 这里就是包装的可调用对象.
// 包装可调用对象的实际类型, StoredFunctorCall0, 和函数指针是一样的, 因为都是调用 operator() 操作符.
template <typename Functor>
auto run(Functor functor) -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor())> >::type
{
    typedef decltype(functor()) result_type;
    return (new StoredFunctorCall0<result_type, Functor>(functor))->start();
}

// 包装了, 有一个参数的可调用对象.
template <typename Functor, typename Arg1>
auto run(Functor functor, const Arg1 &arg1)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1))>>::type
{
    typedef decltype(functor(arg1)) result_type;
    return (new StoredFunctorCall1<result_type, Functor, Arg1>(functor, arg1))->start();
}

// 两个参数的可调用对象.
template <typename Functor, typename Arg1, typename Arg2>
auto run(Functor functor, const Arg1 &arg1, const Arg2 &arg2)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2))>>::type
{
    typedef decltype(functor(arg1, arg2)) result_type;
    return (new StoredFunctorCall2<result_type, Functor, Arg1, Arg2>(functor, arg1, arg2))->start();
}

// 3 个
template <typename Functor, typename Arg1, typename Arg2, typename Arg3>
auto run(Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3)) result_type;
    return (new StoredFunctorCall3<result_type, Functor, Arg1, Arg2, Arg3>(functor, arg1, arg2, arg3))->start();
}

template <typename Functor, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
auto run(Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3, arg4))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3, arg4)) result_type;
    return (new StoredFunctorCall4<result_type, Functor, Arg1, Arg2, Arg3, Arg4>(functor, arg1, arg2, arg3, arg4))->start();
}

template <typename Functor, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
auto run(Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3, arg4, arg5))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3, arg4, arg5)) result_type;
    return (new StoredFunctorCall5<result_type, Functor, Arg1, Arg2, Arg3, Arg4, Arg5>(functor, arg1, arg2, arg3, arg4, arg5))->start();
}

// 又是新的信息, 如果这个类型, 里面有这 FunctionObject::result_type 的定义.                                                                                                                                   // 同样是 StoredFunctorCall0 进行包装
template <typename FunctionObject>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject)
{
    return (new StoredFunctorCall0<typename FunctionObject::result_type, FunctionObject>(functionObject))->start();
}
template <typename FunctionObject, typename Arg1>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject, const Arg1 &arg1)
{
    return (new StoredFunctorCall1<typename FunctionObject::result_type, FunctionObject, Arg1>(functionObject, arg1))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2>(functionObject, arg1, arg2))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3>(functionObject, arg1, arg2, arg3))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4>(functionObject, arg1, arg2, arg3, arg4))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
QFuture<typename FunctionObject::result_type> run(FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4, Arg5>(functionObject, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename FunctionObject>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject)
{
    return (new typename SelectStoredFunctorPointerCall0<typename FunctionObject::result_type, FunctionObject>::type(functionObject))->start();
}
template <typename FunctionObject, typename Arg1>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject, const Arg1 &arg1)
{
    return (new typename SelectStoredFunctorPointerCall1<typename FunctionObject::result_type, FunctionObject, Arg1>::type(functionObject, arg1))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredFunctorPointerCall2<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2>::type(functionObject, arg1, arg2))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredFunctorPointerCall3<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3>::type(functionObject, arg1, arg2, arg3))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredFunctorPointerCall4<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4>::type(functionObject, arg1, arg2, arg3, arg4))->start();
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
QFuture<typename FunctionObject::result_type> run(FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredFunctorPointerCall5<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4, Arg5>::type(functionObject, arg1, arg2, arg3, arg4, arg5))->start();
}


// 类成员函数的适配, 最终包装对象是 StoredMemberFunctionCall0 类型.的
template <typename T, typename Class>
QFuture<T> run(const Class &object, T (Class::*fn)())
{
    return (new typename SelectStoredMemberFunctionCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1), const Arg1 &arg1)
{
    return (new typename SelectStoredMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}


// Const 版本, Const 版本的函数, 和普通的成员函数是不一样的.
template <typename T, typename Class>
QFuture<T> run(const Class &object, T (Class::*fn)() const)
{
    return (new typename SelectStoredConstMemberFunctionCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1) const, const Arg1 &arg1)
{
    return (new typename SelectStoredConstMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2) const, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(Class *object, T (Class::*fn)())
{
    return (new typename SelectStoredMemberFunctionPointerCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(Class *object, T (Class::*fn)(Param1), const Arg1 &arg1)
{
    return (new typename SelectStoredMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(const Class *object, T (Class::*fn)() const)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1) const, const Arg1 &arg1)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2) const, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

// ...and the same with a QThreadPool *pool argument...
// generate from the above by c'n'p and s/run(/run(QThreadPool *pool, / and s/start()/start(pool)/

template <typename T>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)())
{
    return (new StoredFunctorCall0<T, T (*)()>(functionPointer))->start(pool);
}
template <typename T, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1), const Arg1 &arg1)
{
    return (new StoredFunctorCall1<T, T (*)(Param1), Arg1>(functionPointer, arg1))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<T, T (*)(Param1, Param2), Arg1, Arg2>(functionPointer, arg1, arg2))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<T, T (*)(Param1, Param2, Param3), Arg1, Arg2, Arg3>(functionPointer, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<T, T (*)(Param1, Param2, Param3, Param4), Arg1, Arg2, Arg3, Arg4>(functionPointer, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<T, T (*)(Param1, Param2, Param3, Param4, Param5), Arg1, Arg2, Arg3, Arg4, Arg5>(functionPointer, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename Functor>
auto run(QThreadPool *pool, Functor functor) -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor())>>::type
{
    typedef decltype(functor()) result_type;
    return (new StoredFunctorCall0<result_type, Functor>(functor))->start(pool);
}

template <typename Functor, typename Arg1>
auto run(QThreadPool *pool, Functor functor, const Arg1 &arg1)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1))>>::type
{
    typedef decltype(functor(arg1)) result_type;
    return (new StoredFunctorCall1<result_type, Functor, Arg1>(functor, arg1))->start(pool);
}

template <typename Functor, typename Arg1, typename Arg2>
auto run(QThreadPool *pool, Functor functor, const Arg1 &arg1, const Arg2 &arg2)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2))>>::type
{
    typedef decltype(functor(arg1, arg2)) result_type;
    return (new StoredFunctorCall2<result_type, Functor, Arg1, Arg2>(functor, arg1, arg2))->start(pool);
}

template <typename Functor, typename Arg1, typename Arg2, typename Arg3>
auto run(QThreadPool *pool, Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3)) result_type;
    return (new StoredFunctorCall3<result_type, Functor, Arg1, Arg2, Arg3>(functor, arg1, arg2, arg3))->start(pool);
}

template <typename Functor, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
auto run(QThreadPool *pool, Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3, arg4))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3, arg4)) result_type;
    return (new StoredFunctorCall4<result_type, Functor, Arg1, Arg2, Arg3, Arg4>(functor, arg1, arg2, arg3, arg4))->start(pool);
}

template <typename Functor, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
auto run(QThreadPool *pool, Functor functor, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2, arg3, arg4, arg5))>>::type
{
    typedef decltype(functor(arg1, arg2, arg3, arg4, arg5)) result_type;
    return (new StoredFunctorCall5<result_type, Functor, Arg1, Arg2, Arg3, Arg4, Arg5>(functor, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename FunctionObject>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject)
{
    return (new StoredFunctorCall0<typename FunctionObject::result_type, FunctionObject>(functionObject))->start(pool);
}
template <typename FunctionObject, typename Arg1>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject, const Arg1 &arg1)
{
    return (new StoredFunctorCall1<typename FunctionObject::result_type, FunctionObject, Arg1>(functionObject, arg1))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2>(functionObject, arg1, arg2))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3>(functionObject, arg1, arg2, arg3))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4>(functionObject, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4, Arg5>(functionObject, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename FunctionObject>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject)
{
    return (new typename SelectStoredFunctorPointerCall0<typename FunctionObject::result_type, FunctionObject>::type(functionObject))->start(pool);
}
template <typename FunctionObject, typename Arg1>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject, const Arg1 &arg1)
{
    return (new typename SelectStoredFunctorPointerCall1<typename FunctionObject::result_type, FunctionObject, Arg1>::type(functionObject, arg1))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredFunctorPointerCall2<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2>::type(functionObject, arg1, arg2))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredFunctorPointerCall3<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3>::type(functionObject, arg1, arg2, arg3))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredFunctorPointerCall4<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4>::type(functionObject, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename FunctionObject, typename Arg1, typename Arg2, typename Arg3, typename Arg4, typename Arg5>
QFuture<typename FunctionObject::result_type> run(QThreadPool *pool, FunctionObject *functionObject, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredFunctorPointerCall5<typename FunctionObject::result_type, FunctionObject, Arg1, Arg2, Arg3, Arg4, Arg5>::type(functionObject, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)())
{
    return (new typename SelectStoredMemberFunctionCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1), const Arg1 &arg1)
{
    return (new typename SelectStoredMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)() const)
{
    return (new typename SelectStoredConstMemberFunctionCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1) const, const Arg1 &arg1)
{
    return (new typename SelectStoredConstMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2) const, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)())
{
    return (new typename SelectStoredMemberFunctionPointerCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1), const Arg1 &arg1)
{
    return (new typename SelectStoredMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)() const)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1) const, const Arg1 &arg1)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2) const, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

#if defined(__cpp_noexcept_function_type) && __cpp_noexcept_function_type >= 201510
template <typename T>
QFuture<T> run(T (*functionPointer)() noexcept)
{
    return (new StoredFunctorCall0<T, T (*)() noexcept>(functionPointer))->start();
}
template <typename T, typename Param1, typename Arg1>
QFuture<T> run(T (*functionPointer)(Param1) noexcept, const Arg1 &arg1)
{
    return (new StoredFunctorCall1<T, T (*)(Param1) noexcept, Arg1>(functionPointer, arg1))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(T (*functionPointer)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<T, T (*)(Param1, Param2) noexcept, Arg1, Arg2>(functionPointer, arg1, arg2))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<T, T (*)(Param1, Param2, Param3) noexcept, Arg1, Arg2, Arg3>(functionPointer, arg1, arg2, arg3))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<T, T (*)(Param1, Param2, Param3, Param4) noexcept, Arg1, Arg2, Arg3, Arg4>(functionPointer, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<T, T (*)(Param1, Param2, Param3, Param4, Param5) noexcept, Arg1, Arg2, Arg3, Arg4, Arg5>(functionPointer, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(const Class &object, T (Class::*fn)() noexcept)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1) noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(const Class &object, T (Class::*fn)() const noexcept)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1) const noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2) const noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(Class *object, T (Class::*fn)() noexcept)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(Class *object, T (Class::*fn)(Param1) noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}

template <typename T, typename Class>
QFuture<T> run(const Class *object, T (Class::*fn)() const noexcept)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall0<T, Class>::type(fn, object))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1) const noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2) const noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start();
}
template <typename T>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)() noexcept)
{
    return (new StoredFunctorCall0<T, T (*)() noexcept>(functionPointer))->start(pool);
}
template <typename T, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1) noexcept, const Arg1 &arg1)
{
    return (new StoredFunctorCall1<T, T (*)(Param1) noexcept, Arg1>(functionPointer, arg1))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<T, T (*)(Param1, Param2) noexcept, Arg1, Arg2>(functionPointer, arg1, arg2))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<T, T (*)(Param1, Param2, Param3) noexcept, Arg1, Arg2, Arg3>(functionPointer, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<T, T (*)(Param1, Param2, Param3, Param4) noexcept, Arg1, Arg2, Arg3, Arg4>(functionPointer, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, T (*functionPointer)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<T, T (*)(Param1, Param2, Param3, Param4, Param5) noexcept, Arg1, Arg2, Arg3, Arg4, Arg5>(functionPointer, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)() noexcept)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1) noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredNoExceptMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)() const noexcept)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1) const noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2) const noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class &object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)() noexcept)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1) noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2) noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredNoExceptMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}

template <typename T, typename Class>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)() const noexcept)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall0<T, Class>::type(fn, object))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1) const noexcept, const Arg1 &arg1)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall1<T, Class, Param1, Arg1>::type(fn, object, arg1))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2) const noexcept, const Arg1 &arg1, const Arg2 &arg2)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall2<T, Class, Param1, Arg1, Param2, Arg2>::type(fn, object, arg1, arg2))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall3<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3>::type(fn, object, arg1, arg2, arg3))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall4<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4>::type(fn, object, arg1, arg2, arg3, arg4))->start(pool);
}
template <typename T, typename Class, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(QThreadPool *pool, const Class *object, T (Class::*fn)(Param1, Param2, Param3, Param4, Param5) const noexcept, const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new typename SelectStoredConstNoExceptMemberFunctionPointerCall5<T, Class, Param1, Arg1, Param2, Arg2, Param3, Arg3, Param4, Arg4, Param5, Arg5>::type(fn, object, arg1, arg2, arg3, arg4, arg5))->start(pool);
}
#endif

} //namespace QtConcurrent

#endif // Q_CLANG_QDOC

QT_END_NAMESPACE

#endif
