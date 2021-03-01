#ifndef __SGI_STL_INTERNAL_FUNCTION_H
#define __SGI_STL_INTERNAL_FUNCTION_H

__STL_BEGIN_NAMESPACE

/*
 如果, 自己写的仿函数, 没有继承下面的定义, 那么就没有能力回答 argument_type, result_type 的类型.
 可以正常的传入到算法中使用, 因为算法仅仅要求可以 func call, 也就是 operator () 调用就行.
 
 但是, 如果想让 binder1st 进行修饰, 因为没有办法回答这些类要求的 result_type, argument_type 是什么, 就不能和 STL 对于仿函数的设计融合到一起.
 */
template <class Arg, class Result>
struct unary_function {
    typedef Arg argument_type;
    typedef Result result_type;
};

template <class Arg1, class Arg2, class Result>
struct binary_function {
    typedef Arg1 first_argument_type;
    typedef Arg2 second_argument_type;
    typedef Result result_type;
};      

/*
 里面大量的使用了操作符重载.
 可以把操作符, 理解为, 具有通用性的一组特殊接口.
 模板不管到底这些操作符到底如何实现, 如果没有实现, 编译不通过.
 */

// 所有的函数对象模板, 都继承自了相应的父类, 并且写好了父类相应的模板.

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct plus : public binary_function<T, T, T> {
    T operator()(const T& x, const T& y) const { return x + y; }
};

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct minus : public binary_function<T, T, T> {
    T operator()(const T& x, const T& y) const { return x - y; }
};

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct multiplies : public binary_function<T, T, T> {
    T operator()(const T& x, const T& y) const { return x * y; }
};

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct divides : public binary_function<T, T, T> {
    T operator()(const T& x, const T& y) const { return x / y; }
};

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct modulus : public binary_function<T, T, T> {
    T operator()(const T& x, const T& y) const { return x % y; }
};

// 传入一个类型参数, 可以确定 first, last, return 三个类型参数.
template <class T>
struct negate : public unary_function<T, T> {
    T operator()(const T& x) const { return -x; }
};



// 这种, 返回值是 bool 的 functor, 叫做 predicate.

// 返回 bool 值的类型对象, 在 STL 里面叫做 predicate.
// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct equal_to : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x == y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct not_equal_to : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x != y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct greater : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x > y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct less : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x < y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct greater_equal : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x >= y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct less_equal : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x <= y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct logical_and : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x && y; }
};

// 传入一个类型参数, 可以确定 first, last, 两个类型参数, return 的类型固定为 bool.
template <class T>
struct logical_or : public binary_function<T, T, bool> {
    bool operator()(const T& x, const T& y) const { return x || y; }
};

// 传入一个类型参数, 可以确定 first 的类型参数, return 的类型固定为 bool.
template <class T>
struct logical_not : public unary_function<T, bool> {
    bool operator()(const T& x) const { return !x; }
};


// 这是一个函数对象适配器.
// 类型名叫做 Predicate, 是提醒, 应该传入一个 return type 为 bool 的函数对象进来.
// Predicate::argument_type 是对于传入对象的询问操作, 所以, Predicate 必须继承自 unary_function, 不然这个适配器无法工作.

template <class Predicate>
class unary_negate // 直接, 根据 Predicate 的 argument, 确定 unary_function 中的类型.
: public unary_function<typename Predicate::argument_type, bool> {
protected:
    Predicate pred; // 传入一个闭包, 存储起来. 真正调用的时候, 就是调用这个闭包, 然后取反.
public:
    explicit unary_negate(const Predicate& x) : pred(x) {}
    
    bool operator()(const typename Predicate::argument_type& x) const {
        return !pred(x);
    }
};

// 不要直接使用 unary_negate 这个类. not1 的作用, 更多的是利用编译器的类型推到, 得到 pred 的真实类型.
// 如果传入的 pred 不是一个 unary_function, 那么编译是通过不了的. 所以, 不能是一个 lambda 表达式.
template <class Predicate>
inline unary_negate<Predicate> not1(const Predicate& pred) {
    return unary_negate<Predicate>(pred);
}

// 和上面的模式基本一样.
template <class Predicate> 
class binary_negate 
: public binary_function<typename Predicate::first_argument_type,
                        typename Predicate::second_argument_type,
                        bool>
{
protected:
    Predicate pred;
public:
    explicit binary_negate(const Predicate& x) : pred(x) {}
    bool operator()(const typename Predicate::first_argument_type& x,
                    const typename Predicate::second_argument_type& y) const {
        return !pred(x, y);
    }
};

// 通过一个简单地接口, 把类型参数确认的事情, 交给了编译器.
template <class Predicate>
inline binary_negate<Predicate> not2(const Predicate& pred) {
    return binary_negate<Predicate>(pred);
}

// 传入一个二元函数, 经过 binder1st 的包装, 就变成了一个一元函数.
template <class Operation>
class binder1st
: public unary_function<typename Operation::second_argument_type,
                        typename Operation::result_type> {
// unary_function 的 type, 应该是从 Operation 中获取. 所以, 这类使用 Operation 里面的值, 写入到类型参数是很重要的.
// operator() 里面的类型名, 和这里的类型名必须是一样的.   
protected:
    Operation op; // 存函数闭包
    typename Operation::first_argument_type value; // 存需要绑定的值.
public:
    binder1st(const Operation& x,
              const typename Operation::first_argument_type& y)
    : op(x), value(y) {}
    
    typename Operation::result_type
    operator()(const typename Operation::second_argument_type& x) const {
        return op(value, x);
    }
};

// 通过编译器, 来确定二元函数的各个实际类型, 填充到 binder1st 中去.
template <class Operation, class T>
inline binder1st<Operation> bind1st(const Operation& op, const T& x) {
    typedef typename Operation::first_argument_type arg1_type; // 这里, 使用 type 强包了一层.
    return binder1st<Operation>(op, arg1_type(x));
}

template <class Operation>
class binder2nd
: public unary_function<typename Operation::first_argument_type,
typename Operation::result_type> {
protected:
    Operation op;
    typename Operation::second_argument_type value;
public:
    binder2nd(const Operation& x,
              const typename Operation::second_argument_type& y)
    : op(x), value(y) {}
    typename Operation::result_type
    operator()(const typename Operation::first_argument_type& x) const {
        return op(x, value);
    }
};

// 写出一个方法来, 通过编译器的推导, 推导出 op 的类型.
template <class Operation, class T>
inline binder2nd<Operation> bind2nd(const Operation& op, const T& x) {
    // 这里, 如果传递过来的 op, 没有继承相应的父类, 在这里就报错了 second_argument_type.
    typedef typename Operation::second_argument_type arg2_type;
    return binder2nd<Operation>(op, arg2_type(x));
}

/*
 这个函数, 基本没有用到过.
 */
template <class Operation1, class Operation2>
class unary_compose : public unary_function<typename Operation2::argument_type,
typename Operation1::result_type> {
protected:
    Operation1 op1;
    Operation2 op2;
public:
    unary_compose(const Operation1& x, const Operation2& y) : op1(x), op2(y) {}
    typename Operation1::result_type
    operator()(const typename Operation2::argument_type& x) const {
        return op1(op2(x));
    }
};

// 同样的, 内部的处理数据结构, 不会暴露出去, 一个简便的方法, 封装了里面的特定类型的数据结构的建立.
template <class Operation1, class Operation2>
inline unary_compose<Operation1, Operation2> compose1(const Operation1& op1, 
                                                      const Operation2& op2) {
    return unary_compose<Operation1, Operation2>(op1, op2);
}

template <class Operation1, class Operation2, class Operation3>
class binary_compose
: public unary_function<typename Operation2::argument_type,
typename Operation1::result_type> {
protected:
    Operation1 op1;
    Operation2 op2;
    Operation3 op3;
public:
    binary_compose(const Operation1& x, const Operation2& y,
                   const Operation3& z) : op1(x), op2(y), op3(z) { }
    typename Operation1::result_type
    operator()(const typename Operation2::argument_type& x) const {
        return op1(op2(x), op3(x));
    }
};

template <class Operation1, class Operation2, class Operation3>
inline binary_compose<Operation1, Operation2, Operation3> 
compose2(const Operation1& op1, const Operation2& op2, const Operation3& op3) {
    return binary_compose<Operation1, Operation2, Operation3>(op1, op2, op3);
}

// identity, 直接返回元素本身.
template <class T>
struct identity : public unary_function<T, T> {
    const T& operator()(const T& x) const { return x; }
};

// unary_function, 第一个类型参数是 pair, 返回值类型, 是 pair 里面的 first_type.
// 所以, Pair 必须 typedef first_type 是什么才可以.
template <class Pair>
struct select1st : public unary_function<Pair, typename Pair::first_type> {
    const typename Pair::first_type& operator()(const Pair& x) const
    {
        return x.first;
    }
};

template <class Pair>
struct select2nd : public unary_function<Pair, typename Pair::second_type> {
    const typename Pair::second_type& operator()(const Pair& x) const
    {
        return x.second;
    }
};

/*
 下面的函数, 感觉用户都不大, 没有细看.
 */
template <class Arg1, class Arg2>
struct project1st : public binary_function<Arg1, Arg2, Arg1> {
    Arg1 operator()(const Arg1& x, const Arg2&) const { return x; }
};

template <class Arg1, class Arg2>
struct project2nd : public binary_function<Arg1, Arg2, Arg2> {
    Arg2 operator()(const Arg1&, const Arg2& y) const { return y; }
};

template <class Result>
struct constant_void_fun
{
    typedef Result result_type;
    result_type val;
    constant_void_fun(const result_type& v) : val(v) {}
    const result_type& operator()() const { return val; }
};  

#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class Result, class Argument = Result>
#else
template <class Result, class Argument>
#endif
struct constant_unary_fun : public unary_function<Argument, Result> {
    Result val;
    constant_unary_fun(const Result& v) : val(v) {}
    const Result& operator()(const Argument&) const { return val; }
};

#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class Result, class Arg1 = Result, class Arg2 = Arg1>
#else
template <class Result, class Arg1, class Arg2>
#endif
struct constant_binary_fun : public binary_function<Arg1, Arg2, Result> {
    Result val;
    constant_binary_fun(const Result& v) : val(v) {}
    const Result& operator()(const Arg1&, const Arg2&) const {
        return val;
    }
};

template <class Result>
inline constant_void_fun<Result> constant0(const Result& val)
{
    return constant_void_fun<Result>(val);
}

template <class Result>
inline constant_unary_fun<Result,Result> constant1(const Result& val)
{
    return constant_unary_fun<Result,Result>(val);
}

template <class Result>
inline constant_binary_fun<Result,Result,Result> constant2(const Result& val)
{
    return constant_binary_fun<Result,Result,Result>(val);
}

// Note: this code assumes that int is 32 bits.
class subtractive_rng : public unary_function<unsigned int, unsigned int> {
private:
    unsigned int table[55];
    size_t index1;
    size_t index2;
public:
    unsigned int operator()(unsigned int limit) {
        index1 = (index1 + 1) % 55;
        index2 = (index2 + 1) % 55;
        table[index1] = table[index1] - table[index2];
        return table[index1] % limit;
    }
    
    void initialize(unsigned int seed)
    {
        unsigned int k = 1;
        table[54] = seed;
        size_t i;
        for (i = 0; i < 54; i++) {
            size_t ii = (21 * (i + 1) % 55) - 1;
            table[ii] = k;
            k = seed - k;
            seed = table[ii];
        }
        for (int loop = 0; loop < 4; loop++) {
            for (i = 0; i < 55; i++)
                table[i] = table[i] - table[(1 + i + 30) % 55];
        }
        index1 = 0;
        index2 = 31;
    }
    
    subtractive_rng(unsigned int seed) { initialize(seed); }
    subtractive_rng() { initialize(161803398u); }
};


// Adaptor function objects: pointers to member functions.

// There are a total of 16 = 2^4 function objects in this family.
//  (1) Member functions taking no arguments vs member functions taking
//       one argument.
//  (2) Call through pointer vs call through reference.
//  (3) Member function with void return type vs member function with
//      non-void return type.
//  (4) Const vs non-const member function.

// Note that choice (4) is not present in the 8/97 draft C++ standard, 
//  which only allows these adaptors to be used with non-const functions.
//  This is likely to be recified before the standard becomes final.
// Note also that choice (3) is nothing more than a workaround: according
//  to the draft, compilers should handle void and non-void the same way.
//  This feature is not yet widely implemented, though.  You can only use
//  member functions returning void if your compiler supports partial
//  specialization.

// All of this complexity is in the function objects themselves.  You can
//  ignore it by using the helper function mem_fun, mem_fun_ref,
//  mem_fun1, and mem_fun1_ref, which create whichever type of adaptor
//  is appropriate.


template <class S, class T>
class mem_fun_t : public unary_function<T*, S> {
public:
    explicit mem_fun_t(S (T::*pf)()) : f(pf) {}
    S operator()(T* p) const { return (p->*f)(); }
private:
    S (T::*f)();
};

template <class S, class T>
class const_mem_fun_t : public unary_function<const T*, S> {
public:
    explicit const_mem_fun_t(S (T::*pf)() const) : f(pf) {}
    S operator()(const T* p) const { return (p->*f)(); }
private:
    S (T::*f)() const;
};


template <class S, class T>
class mem_fun_ref_t : public unary_function<T, S> {
public:
    explicit mem_fun_ref_t(S (T::*pf)()) : f(pf) {}
    S operator()(T& r) const { return (r.*f)(); }
private:
    S (T::*f)();
};

template <class S, class T>
class const_mem_fun_ref_t : public unary_function<T, S> {
public:
    explicit const_mem_fun_ref_t(S (T::*pf)() const) : f(pf) {}
    S operator()(const T& r) const { return (r.*f)(); }
private:
    S (T::*f)() const;
};

template <class S, class T, class A>
class mem_fun1_t : public binary_function<T*, A, S> {
public:
    explicit mem_fun1_t(S (T::*pf)(A)) : f(pf) {}
    S operator()(T* p, A x) const { return (p->*f)(x); }
private:
    S (T::*f)(A);
};

template <class S, class T, class A>
class const_mem_fun1_t : public binary_function<const T*, A, S> {
public:
    explicit const_mem_fun1_t(S (T::*pf)(A) const) : f(pf) {}
    S operator()(const T* p, A x) const { return (p->*f)(x); }
private:
    S (T::*f)(A) const;
};

template <class S, class T, class A>
class mem_fun1_ref_t : public binary_function<T, A, S> {
public:
    explicit mem_fun1_ref_t(S (T::*pf)(A)) : f(pf) {}
    S operator()(T& r, A x) const { return (r.*f)(x); }
private:
    S (T::*f)(A);
};

template <class S, class T, class A>
class const_mem_fun1_ref_t : public binary_function<T, A, S> {
public:
    explicit const_mem_fun1_ref_t(S (T::*pf)(A) const) : f(pf) {}
    S operator()(const T& r, A x) const { return (r.*f)(x); }
private:
    S (T::*f)(A) const;
};

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class T>
class mem_fun_t<void, T> : public unary_function<T*, void> {
public:
    explicit mem_fun_t(void (T::*pf)()) : f(pf) {}
    void operator()(T* p) const { (p->*f)(); }
private:
    void (T::*f)();
};

template <class T>
class const_mem_fun_t<void, T> : public unary_function<const T*, void> {
public:
    explicit const_mem_fun_t(void (T::*pf)() const) : f(pf) {}
    void operator()(const T* p) const { (p->*f)(); }
private:
    void (T::*f)() const;
};

template <class T>
class mem_fun_ref_t<void, T> : public unary_function<T, void> {
public:
    explicit mem_fun_ref_t(void (T::*pf)()) : f(pf) {}
    void operator()(T& r) const { (r.*f)(); }
private:
    void (T::*f)();
};

template <class T>
class const_mem_fun_ref_t<void, T> : public unary_function<T, void> {
public:
    explicit const_mem_fun_ref_t(void (T::*pf)() const) : f(pf) {}
    void operator()(const T& r) const { (r.*f)(); }
private:
    void (T::*f)() const;
};

template <class T, class A>
class mem_fun1_t<void, T, A> : public binary_function<T*, A, void> {
public:
    explicit mem_fun1_t(void (T::*pf)(A)) : f(pf) {}
    void operator()(T* p, A x) const { (p->*f)(x); }
private:
    void (T::*f)(A);
};

template <class T, class A>
class const_mem_fun1_t<void, T, A> : public binary_function<const T*, A, void> {
public:
    explicit const_mem_fun1_t(void (T::*pf)(A) const) : f(pf) {}
    void operator()(const T* p, A x) const { (p->*f)(x); }
private:
    void (T::*f)(A) const;
};

template <class T, class A>
class mem_fun1_ref_t<void, T, A> : public binary_function<T, A, void> {
public:
    explicit mem_fun1_ref_t(void (T::*pf)(A)) : f(pf) {}
    void operator()(T& r, A x) const { (r.*f)(x); }
private:
    void (T::*f)(A);
};

template <class T, class A>
class const_mem_fun1_ref_t<void, T, A> : public binary_function<T, A, void> {
public:
    explicit const_mem_fun1_ref_t(void (T::*pf)(A) const) : f(pf) {}
    void operator()(const T& r, A x) const { (r.*f)(x); }
private:
    void (T::*f)(A) const;
};

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

// Mem_fun adaptor helper functions.  There are only four:
//  mem_fun, mem_fun_ref, mem_fun1, mem_fun1_ref.

template <class S, class T>
inline mem_fun_t<S,T> mem_fun(S (T::*f)()) { 
    return mem_fun_t<S,T>(f);
}

template <class S, class T>
inline const_mem_fun_t<S,T> mem_fun(S (T::*f)() const) {
    return const_mem_fun_t<S,T>(f);
}

template <class S, class T>
inline mem_fun_ref_t<S,T> mem_fun_ref(S (T::*f)()) { 
    return mem_fun_ref_t<S,T>(f);
}

template <class S, class T>
inline const_mem_fun_ref_t<S,T> mem_fun_ref(S (T::*f)() const) {
    return const_mem_fun_ref_t<S,T>(f);
}

template <class S, class T, class A>
inline mem_fun1_t<S,T,A> mem_fun1(S (T::*f)(A)) { 
    return mem_fun1_t<S,T,A>(f);
}

template <class S, class T, class A>
inline const_mem_fun1_t<S,T,A> mem_fun1(S (T::*f)(A) const) {
    return const_mem_fun1_t<S,T,A>(f);
}

template <class S, class T, class A>
inline mem_fun1_ref_t<S,T,A> mem_fun1_ref(S (T::*f)(A)) { 
    return mem_fun1_ref_t<S,T,A>(f);
}

template <class S, class T, class A>
inline const_mem_fun1_ref_t<S,T,A> mem_fun1_ref(S (T::*f)(A) const) {
    return const_mem_fun1_ref_t<S,T,A>(f);
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_FUNCTION_H */

// Local Variables:
// mode:C++
// End:
