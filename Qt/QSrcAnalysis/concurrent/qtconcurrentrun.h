// Generated code, do not edit! Use generator at tools/qtconcurrent/generaterun/
#ifndef QTCONCURRENT_RUN_H
#define QTCONCURRENT_RUN_H

#include <QtConcurrent/qtconcurrentcompilertest.h>

#if !defined(QT_NO_CONCURRENT) || defined(Q_CLANG_QDOC)

#include <QtConcurrent/qtconcurrentrunbase.h>
#include <QtConcurrent/qtconcurrentstoredfunctioncall.h>

QT_BEGIN_NAMESPACE

#ifdef Q_CLANG_QDOC

typedef int Function;

namespace QtConcurrent {

    template <typename T>
    QFuture<T> run(Function function, ...);

    template <typename T>
    QFuture<T> run(QThreadPool *pool, Function function, ...);

} // namespace QtConcurrent

#else

/*
QtConcurrent::run(QThreadPool::globalInstance(), function, ...);

Runs function in a separate thread. The thread is taken from the global QThreadPool. Note that function may not run immediately; function will only be run once a thread becomes available.

T is the same type as the return value of function. Non-void return values can be accessed via the QFuture::result() function.
*/


// 对外的接口, 仅仅是一个 run 方法, 这个方法接受一个 invokable 参数, 以及后面的参数. 如果有 return value, 那么就可以通过 future 来进行获取.
// 而实际上, 有这么多个模板来支持这个功能.

/*
    从这里, 其实也可以窥探一下, Std::thread 的运行.
    thread 是一个模板, 实际的构造, 应该就是复制了 callable 对象, 以及各个参数.
    真正执行, 应该就是调用 callable 对象, 并且传递各个参数进去. 所以, 实际上, thread 存储的是构造函数调用时传递的数据, 这个数据, 有可能和 callable 所需要的参数类型不匹配, 调用 callable 的时候, 会发生类型转化.
    带来的问题可能是, 生命周期不相同. 比如, thread 构造的时候, 传递的是 char*, 真正 callable 调用传递的是 string;
    string 内部会有数据的复制, 但是 char * 不会有相关操作. 为了避免这种问题, 最好就是 thread 生成时, 传递 callable 对应的数据类型, 没有的话, 就显式地生成一下.
 */


// 这些方法, 返回一个 task_package 对象, 是 new 出来的, 也就是说, 是需要内存管理的.
// 在这个对象内部, 会有 future 对象, 进行线程之间的同步处理.
namespace QtConcurrent {

template <typename T>
QFuture<T> run(T (*functionPointer)())
{
    // 生成一个 StoredFunctorCall0 对象, 调用 start 方法.
    return (new StoredFunctorCall0<T, T (*)()> (functionPointer))   ->start();
}

template <typename T, typename Param1, typename Arg1>
QFuture<T> run(T (*functionPointer)(Param1), const Arg1 &arg1)
{
    // 生成一个 StoredFunctorCall1 对象, 调用 start 方法. StoredFunctorCall1 带参了
    return (new StoredFunctorCall1<T, T (*)(Param1), Arg1>(functionPointer, arg1))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2>
QFuture<T> run(T (*functionPointer)(Param1, Param2), const Arg1 &arg1, const Arg2 &arg2)
{
    return (new StoredFunctorCall2<T, T (*)(Param1, Param2), Arg1, Arg2>(functionPointer, arg1, arg2))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3)
{
    return (new StoredFunctorCall3<T, T (*)(Param1, Param2, Param3), Arg1, Arg2, Arg3>(functionPointer, arg1, arg2, arg3))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4)
{
    return (new StoredFunctorCall4<T, T (*)(Param1, Param2, Param3, Param4), Arg1, Arg2, Arg3, Arg4>(functionPointer, arg1, arg2, arg3, arg4))->start();
}
template <typename T, typename Param1, typename Arg1, typename Param2, typename Arg2, typename Param3, typename Arg3, typename Param4, typename Arg4, typename Param5, typename Arg5>
QFuture<T> run(T (*functionPointer)(Param1, Param2, Param3, Param4, Param5), const Arg1 &arg1, const Arg2 &arg2, const Arg3 &arg3, const Arg4 &arg4, const Arg5 &arg5)
{
    return (new StoredFunctorCall5<T, T (*)(Param1, Param2, Param3, Param4, Param5), Arg1, Arg2, Arg3, Arg4, Arg5>(functionPointer, arg1, arg2, arg3, arg4, arg5))->start();
}






template <typename Functor>
auto run(Functor functor) -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor())>>::type
{
    typedef decltype(functor()) result_type;
    return (new StoredFunctorCall0<result_type, Functor>(functor))->start();
}

template <typename Functor, typename Arg1>
auto run(Functor functor, const Arg1 &arg1)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1))>>::type
{
    typedef decltype(functor(arg1)) result_type;
    return (new StoredFunctorCall1<result_type, Functor, Arg1>(functor, arg1))->start();
}

template <typename Functor, typename Arg1, typename Arg2>
auto run(Functor functor, const Arg1 &arg1, const Arg2 &arg2)
    -> typename std::enable_if<!QtPrivate::HasResultType<Functor>::Value, QFuture<decltype(functor(arg1, arg2))>>::type
{
    typedef decltype(functor(arg1, arg2)) result_type;
    return (new StoredFunctorCall2<result_type, Functor, Arg1, Arg2>(functor, arg1, arg2))->start();
}

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

#endif // QT_NO_CONCURRENT

#endif
