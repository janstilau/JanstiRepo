# 深入分析shared_ptr与weak_ptr的实现

  stl中使用了shared_ptr来管理一个对象的内部指针，并且使用了weak_ptr来防止前面所提到的shared_ptr循环引用的问题。

  接下来简单的分析shared_ptr和weak_ptr的实现，最后通过自己写代码来模拟shared_ptr和weak_ptr，达到深入学习的目的：

  测试代码如下：

```c++
#include "stdafx.h"
#include <memory>

int _tmain(int argc, _TCHAR* argv[])
{   
    std::shared_ptr<int> sptr(new int(3));
    std::shared_ptr<int> sptr2 = sptr;

    std::weak_ptr<int> wptr = sptr;

    if (!wptr.expired()){
        
        std::shared_ptr<int> sptr3 = wptr.lock();
    }

    return 0;
}
```

1.   **首先**看直接看继承关系和类成员：

   shared_ptr与weak_ptr均继承自同一个父类  _Ptr_base

 

```c++
template<class _Ty>
    class shared_ptr
        : public _Ptr_base<_Ty>
    {   // class for reference counted resource management
public:
    typedef shared_ptr<_Ty> _Myt;
    typedef _Ptr_base<_Ty> _Mybase;

    shared_ptr() _NOEXCEPT
        {   // construct empty shared_ptr
        }

    template<class _Ux>
        explicit shared_ptr(_Ux *_Px)
        {   // construct shared_ptr object that owns _Px
        _Resetp(_Px);
        }

    template<class _Ux,
        class _Dx>
        shared_ptr(_Ux *_Px, _Dx _Dt)
        {   // construct with _Px, deleter
        _Resetp(_Px, _Dt);
        }

    shared_ptr(nullptr_t)
        {   // construct empty shared_ptr
        }

    _Myt& operator=(_Myt&& _Right) _NOEXCEPT
        {   // construct shared_ptr object that takes resource from _Right
        shared_ptr(_STD move(_Right)).swap(*this);
        return (*this);
        }

    template<class _Ty2>
        _Myt& operator=(shared_ptr<_Ty2>&& _Right) _NOEXCEPT
        {   // construct shared_ptr object that takes resource from _Right
        shared_ptr(_STD move(_Right)).swap(*this);
        return (*this);
        }

    ~shared_ptr() _NOEXCEPT
        {   // release resource
        this->_Decref();
        }

    _Myt& operator=(const _Myt& _Right) _NOEXCEPT
        {   // assign shared ownership of resource owned by _Right
        shared_ptr(_Right).swap(*this);
        return (*this);
        }

    template<class _Ty2>
        _Myt& operator=(const shared_ptr<_Ty2>& _Right) _NOEXCEPT
        {   // assign shared ownership of resource owned by _Right
        shared_ptr(_Right).swap(*this);
        return (*this);
        }


    void reset() _NOEXCEPT
        {   // release resource and convert to empty shared_ptr object
        shared_ptr().swap(*this);
        }

    template<class _Ux>
        void reset(_Ux *_Px)
        {   // release, take ownership of _Px
        shared_ptr(_Px).swap(*this);
        }

    template<class _Ux,
        class _Dx>
        void reset(_Ux *_Px, _Dx _Dt)
        {   // release, take ownership of _Px, with deleter _Dt
        shared_ptr(_Px, _Dt).swap(*this);
        }

    void swap(_Myt& _Other) _NOEXCEPT
        {   // swap pointers
        this->_Swap(_Other);
        }

    _Ty *get() const _NOEXCEPT
        {   // return pointer to resource
        return (this->_Get());
        }

    typename add_reference<_Ty>::type operator*() const _NOEXCEPT
        {   // return reference to resource
        return (*this->_Get());
        }

    _Ty *operator->() const _NOEXCEPT
        {   // return pointer to resource
        return (this->_Get());
        }

    bool unique() const _NOEXCEPT
        {   // return true if no other shared_ptr object owns this resource
        return (this->use_count() == 1);
        }

    explicit operator bool() const _NOEXCEPT
        {   // test if shared_ptr object owns no resource
        return (this->_Get() != 0);
        }
    };
```

 

```c++
   
            
template<class _Ty>
    class weak_ptr
        : public _Ptr_base<_Ty>
    {   // class for pointer to reference counted resource
public:
    weak_ptr() _NOEXCEPT
        {   // construct empty weak_ptr object
        }

    weak_ptr(const weak_ptr& _Other) _NOEXCEPT
        {   // construct weak_ptr object for resource pointed to by _Other
        this->_Resetw(_Other);
        }

    template<class _Ty2,
        class = typename enable_if<is_convertible<_Ty2 *, _Ty *>::value,
            void>::type>
        weak_ptr(const shared_ptr<_Ty2>& _Other) _NOEXCEPT
        {   // construct weak_ptr object for resource owned by _Other
        this->_Resetw(_Other);
        }

    template<class _Ty2,
        class = typename enable_if<is_convertible<_Ty2 *, _Ty *>::value,
            void>::type>
        weak_ptr(const weak_ptr<_Ty2>& _Other) _NOEXCEPT
        {   // construct weak_ptr object for resource pointed to by _Other
        this->_Resetw(_Other.lock());
        }

    ~weak_ptr() _NOEXCEPT
        {   // release resource
        this->_Decwref();
        }

    weak_ptr& operator=(const weak_ptr& _Right) _NOEXCEPT
        {   // assign from _Right
        this->_Resetw(_Right);
        return (*this);
        }

    template<class _Ty2>
        weak_ptr& operator=(const weak_ptr<_Ty2>& _Right) _NOEXCEPT
        {   // assign from _Right
        this->_Resetw(_Right.lock());
        return (*this);
        }

    template<class _Ty2>
        weak_ptr& operator=(const shared_ptr<_Ty2>& _Right) _NOEXCEPT
        {   // assign from _Right
        this->_Resetw(_Right);
        return (*this);
        }

    void reset() _NOEXCEPT
        {   // release resource, convert to null weak_ptr object
        this->_Resetw();
        }

    void swap(weak_ptr& _Other) _NOEXCEPT
        {   // swap pointers
        this->_Swap(_Other);
        }

    bool expired() const _NOEXCEPT
        {   // return true if resource no longer exists
        return (this->_Expired());
        }

    shared_ptr<_Ty> lock() const _NOEXCEPT
        {   // convert to shared_ptr
        return (shared_ptr<_Ty>(*this, false));
        }
    };
```

  从这里可以看出来shared_ptr和weak_ptr里面本身并没有成员变量，提供的是对外的接口。shared_ptr可以对外提供模拟内部指针的操作，而weak_ptr是用来提供获取shared_ptr的接口。

  

  具体用来记录保存内部指针和使用次数是他们的共同父类_Ptr_base：

```c++
template<class _Ty>
    class _Ptr_base
    {   // base class for shared_ptr and weak_ptr
public:
    typedef _Ptr_base<_Ty> _Myt;
    typedef _Ty element_type;

    _Ptr_base()
        : _Ptr(0), _Rep(0)
        {   // construct
        }

    _Ptr_base(_Myt&& _Right)
        : _Ptr(0), _Rep(0)
        {   // construct _Ptr_base object that takes resource from _Right
        _Assign_rv(_STD forward<_Myt>(_Right));
        }

    template<class _Ty2>
        _Ptr_base(_Ptr_base<_Ty2>&& _Right)
        : _Ptr(_Right._Ptr), _Rep(_Right._Rep)
        {   // construct _Ptr_base object that takes resource from _Right
        _Right._Ptr = 0;
        _Right._Rep = 0;
        }

    _Myt& operator=(_Myt&& _Right)
        {   // construct _Ptr_base object that takes resource from _Right
        _Assign_rv(_STD forward<_Myt>(_Right));
        return (*this);
        }

    void _Assign_rv(_Myt&& _Right)
        {   // assign by moving _Right
        if (this != &_Right)
            _Swap(_Right);
        }

    long use_count() const _NOEXCEPT
        {   // return use count
        return (_Rep ? _Rep->_Use_count() : 0);
        }

    void _Swap(_Ptr_base& _Right)
        {   // swap pointers
        _STD swap(_Rep, _Right._Rep);
        _STD swap(_Ptr, _Right._Ptr);
        }

    template<class _Ty2>
        bool owner_before(const _Ptr_base<_Ty2>& _Right) const
        {   // compare addresses of manager objects
        return (_Rep < _Right._Rep);
        }

    void *_Get_deleter(const _XSTD2 type_info& _Typeid) const
        {   // return pointer to deleter object if its type is _Typeid
        return (_Rep ? _Rep->_Get_deleter(_Typeid) : 0);
        }

    _Ty *_Get() const
        {   // return pointer to resource
        return (_Ptr);
        }

    bool _Expired() const
        {   // test if expired
        return (!_Rep || _Rep->_Expired());
        }

    void _Decref()
        {   // decrement reference count
        if (_Rep != 0)
            _Rep->_Decref();
        }

    void _Reset()
        {   // release resource
        _Reset(0, 0);
        }

    template<class _Ty2>
        void _Reset(const _Ptr_base<_Ty2>& _Other)
        {   // release resource and take ownership of _Other._Ptr
        _Reset(_Other._Ptr, _Other._Rep);
        }

    template<class _Ty2>
        void _Reset(const _Ptr_base<_Ty2>& _Other, bool _Throw)
        {   // release resource and take ownership from weak_ptr _Other._Ptr
        _Reset(_Other._Ptr, _Other._Rep, _Throw);
        }

    template<class _Ty2>
        void _Reset(const _Ptr_base<_Ty2>& _Other, const _Static_tag&)
        {   // release resource and take ownership of _Other._Ptr
        _Reset(static_cast<_Ty *>(_Other._Ptr), _Other._Rep);
        }

    template<class _Ty2>
        void _Reset(const _Ptr_base<_Ty2>& _Other, const _Const_tag&)
        {   // release resource and take ownership of _Other._Ptr
        _Reset(const_cast<_Ty *>(_Other._Ptr), _Other._Rep);
        }

    template<class _Ty2>
        void _Reset(const _Ptr_base<_Ty2>& _Other, const _Dynamic_tag&)
        {   // release resource and take ownership of _Other._Ptr
        _Ty *_Ptr = dynamic_cast<_Ty *>(_Other._Ptr);
        if (_Ptr)
            _Reset(_Ptr, _Other._Rep);
        else
            _Reset();
        }

    template<class _Ty2>
        void _Reset(auto_ptr<_Ty2>&& _Other)
        {   // release resource and take _Other.get()
        _Ty2 *_Px = _Other.get();
        _Reset0(_Px, new _Ref_count<_Ty>(_Px));
        _Other.release();
        _Enable_shared(_Px, _Rep);
        }

    template<class _Ty2>
        void _Reset(_Ty *_Ptr, const _Ptr_base<_Ty2>& _Other)
        {   // release resource and alias _Ptr with _Other_rep
        _Reset(_Ptr, _Other._Rep);
        }

    void _Reset(_Ty *_Other_ptr, _Ref_count_base *_Other_rep)
        {   // release resource and take _Other_ptr through _Other_rep
        if (_Other_rep)
            _Other_rep->_Incref();
        _Reset0(_Other_ptr, _Other_rep);
        }

    void _Reset(_Ty *_Other_ptr, _Ref_count_base *_Other_rep, bool _Throw)
        {   // take _Other_ptr through _Other_rep from weak_ptr if not expired
            // otherwise, leave in default state if !_Throw,
            // otherwise throw exception
        if (_Other_rep && _Other_rep->_Incref_nz())
            _Reset0(_Other_ptr, _Other_rep);
        else if (_Throw)
            _THROW_NCEE(bad_weak_ptr, 0);
        }

    void _Reset0(_Ty *_Other_ptr, _Ref_count_base *_Other_rep)
        {   // release resource and take new resource
        if (_Rep != 0)
            _Rep->_Decref();
        _Rep = _Other_rep;
        _Ptr = _Other_ptr;
        }

    void _Decwref()
        {   // decrement weak reference count
        if (_Rep != 0)
            _Rep->_Decwref();
        }

    void _Resetw()
        {   // release weak reference to resource
        _Resetw((_Ty *)0, 0);
        }

    template<class _Ty2>
        void _Resetw(const _Ptr_base<_Ty2>& _Other)
        {   // release weak reference to resource and take _Other._Ptr
        _Resetw(_Other._Ptr, _Other._Rep);
        }

    template<class _Ty2>
        void _Resetw(const _Ty2 *_Other_ptr, _Ref_count_base *_Other_rep)
        {   // point to _Other_ptr through _Other_rep
        _Resetw(const_cast<_Ty2*>(_Other_ptr), _Other_rep);
        }

    template<class _Ty2>
        void _Resetw(_Ty2 *_Other_ptr, _Ref_count_base *_Other_rep)
        {   // point to _Other_ptr through _Other_rep
        if (_Other_rep)
            _Other_rep->_Incwref();
        if (_Rep != 0)
            _Rep->_Decwref();
        _Rep = _Other_rep;
        _Ptr = _Other_ptr;
        }

private:
    _Ty *_Ptr;
    _Ref_count_base *_Rep;
    template<class _Ty0>
        friend class _Ptr_base;
    };
```

可以看到这个类里面主要提供了两个成员

-   成员_Ty *_Ptr主要用来记录内部指针。 

-   成员_Ref_count_base *_Rep用来记录使用次数和弱指针使用次数。

​      实际上_Ref_count_base *_Rep 这个指针也是new出来的，当weak_count为0时就可以删除，而使用次数是用来记录内部指针的，当使用次数为0时，就可以释放内部指针了。

一些重要的成员函数：

   Reset  _Decref _Decwref use_count等。

  

 再来看看类_Ref_count_base的实现：

```c++
class _Ref_count_base
    {   // common code for reference counting
private:
    virtual void _Destroy() = 0;
    virtual void _Delete_this() = 0;

private:
    _Atomic_counter_t _Uses;
    _Atomic_counter_t _Weaks;

protected:
    _Ref_count_base()
        {   // construct
        _Init_atomic_counter(_Uses, 1);
        _Init_atomic_counter(_Weaks, 1);
        }

public:
    virtual ~_Ref_count_base() _NOEXCEPT
        {   // ensure that derived classes can be destroyed properly
        }

    bool _Incref_nz()
        {   // increment use count if not zero, return true if successful
        for (; ; )
            {   // loop until state is known
 #if defined(_M_IX86) || defined(_M_X64) || defined(_M_CEE_PURE)
            _Atomic_integral_t _Count =
                static_cast<volatile _Atomic_counter_t&>(_Uses);

            if (_Count == 0)
                return (false);

            if (static_cast<_Atomic_integral_t>(_InterlockedCompareExchange(
                    reinterpret_cast<volatile long *>(&_Uses),
                    _Count + 1, _Count)) == _Count)
                return (true);

 #else /* defined(_M_IX86) || defined(_M_X64) || defined(_M_CEE_PURE) */
            _Atomic_integral_t _Count =
                _Load_atomic_counter(_Uses);

            if (_Count == 0)
                return (false);

            if (_Compare_increment_atomic_counter(_Uses, _Count))
                return (true);
 #endif /* defined(_M_IX86) || defined(_M_X64) || defined(_M_CEE_PURE) */
            }
        }

    unsigned int _Get_uses() const
        {   // return use count
        return (_Get_atomic_count(_Uses));
        }

    void _Incref()
        {   // increment use count
        _MT_INCR(_Mtx, _Uses);
        }

    void _Incwref()
        {   // increment weak reference count
        _MT_INCR(_Mtx, _Weaks);
        }

    void _Decref()
        {   // decrement use count
        if (_MT_DECR(_Mtx, _Uses) == 0)
            {   // destroy managed resource, decrement weak reference count
            _Destroy();
            _Decwref();
            }
        }

    void _Decwref()
        {   // decrement weak reference count
        if (_MT_DECR(_Mtx, _Weaks) == 0)
            _Delete_this();
        }

    long _Use_count() const
        {   // return use count
        return (_Get_uses());
        }

    bool _Expired() const
        {   // return true if _Uses == 0
        return (_Get_uses() == 0);
        }

    virtual void *_Get_deleter(const _XSTD2 type_info&) const
        {   // return address of deleter object
        return (0);
        }
    };
```

 

在这个_Ref_count_base类中提供了

   _Atomic_counter_t _Uses;

​    _Atomic_counter_t _Weaks;

 实际上就是记录的内部指针使用次数和_Ref_count_base使用次数。

在这里有一个简单的继承关系：_Ref_count继承自_Ref_count_base

```c++
template<class _Ty>
    class _Ref_count
    : public _Ref_count_base
    {   // handle reference counting for object without deleter
public:
    _Ref_count(_Ty *_Px)
        : _Ref_count_base(), _Ptr(_Px)
        {   // construct
        }

private:
    virtual void _Destroy()
        {   // destroy managed resource
        delete _Ptr;
        }

    virtual void _Delete_this()
        {   // destroy self
        delete this;
        }

    _Ty * _Ptr;
    };
```

这里_Ptr_base中的_Ref_count_base*  _Rep成员是使用的new  _Ref_count。

 

```c++
void _Resetp(_Ux *_Px)
{   // release, take ownership of _Px
    _TRY_BEGIN  // allocate control block and reset
        _Resetp0(_Px, new _Ref_count<_Ux>(_Px));
    _CATCH_ALL  // allocation failed, delete resource
        delete _Px;
    _RERAISE;
    _CATCH_END
}
```

然后使用子类转父类，而这个类实现了_Ref_count_base*的两个接口函数：

  virtual void _Destroy() = 0;

  virtual void _Delete_this() = 0;

这个引用的次数：

 

```
    _Ref_count_base()
        {   // construct
        _Init_atomic_counter(_Uses, 1);
        _Init_atomic_counter(_Weaks, 1);
        }
```

接下来分析内存结构：

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/1cb3edc2-5dce-4b0f-9a56-c796844b128f/128/index_files/127c8569-7b95-4f0e-8bd6-b392e462031a.png)

这里有两个成员，分别是

 _Ptr(内部指针) ：0x71b8d0

 _Rep(引用base)：0x0071b910

 而引用base这里实际上是_Ref_count对象，因为有虚函数，所以这里存在虚表指针：

 

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/1cb3edc2-5dce-4b0f-9a56-c796844b128f/128/index_files/ceed5ffa-7608-4150-8071-f82766ff4c8e.png)

前4个字节是虚表指针

中间两个4字节分别是内部对象计数器和自身的计数器。

最后4个字节是内部对象指针。

到这里就shared_ptr与weak_ptr的代码就分析的差不多了



最后说一下**计数器增减**的规则：

初始化及增加的情形：

- 当创建一个新的shared_ptr时，内部对象计数器和自身的计数器均置1.

- 当将另外一个shared_ptr赋值给新的shared_ptr时，内部对象计数器+1,自身计数器不变。

- 当将另外一个shared_ptr赋值给新的weak_ptr时,内部对象计数器不变,自身计数器+1。

- 当从weak_ptr获取一个shared_ptr时，内部对象计数器+1,自身计数器不变。

减少的情形：

- 当一个shared_ptr析构时，内部对象计数器-1。当内部对象计数器减为0时，则释放内部对象，并将自身计数器-1。

- 当一个weak_ptr析构时，自身计数器-1。当自身计数器减为0时，则释放自身_Ref_count*对象。

那么就可以自己来模拟强弱指针，并修改成模板。

 

```
#include "stdafx.h"
#include <memory>


/*
    问题1：
     为什么会存在强弱指针的计数？
     A{

        B对象弱智能指针（引用次数  1） weak_ptr_uses_count
     }

     B{
     
        A对象智能指针（引用次数  2）   shared_ptr_uses_count
     }




    问题2：
     强弱指针计数的用途是什么，具体的代码实现是什么？

     shared_ptr :  对外提供接口，并无成员变量 表示强指针
               父类：_Ptr_base

     weak_ptr   :  对外提供接口，并无成员变量 表示弱指针
               父类：_Ptr_base

     _Ptr_base{
 
        两个成员变量：
            _Ty *_Ptr;    //表示智能指针关联的原始的指针， 内部指针
            _Ref_count_base *_Rep; //用于管理智能指针的次数
     }

     基类 纯虚类
     _Ref_count_base{
            virtual void _Destroy() _NOEXCEPT = 0;
            virtual void _Delete_this() _NOEXCEPT = 0;

            //实际上表达的是当前有多少个强指针在引用内部指针
            _Atomic_counter_t _Uses;  //表示强指针使用次数 

            //实际上表达的是当前_Ref_count_base类型的使用次数
            _Atomic_counter_t _Weaks; //表示弱指针使用次数
     }

     有一个派生类：
     _Ref_count： //真正的计数器对象，使用时，需要将指针强转为父类指针，仅仅使用接口
                _Ref_count_base
     {
        //派生类多了一个成员
        _Ty * _Ptr; //表达的是内部指针
     }

     //强指针构造，析构，=赋值 拷贝构造等情况下，计数器的变化
     //弱指针构造，析构，=赋值 拷贝构造等情况下，计数器的变化
     //弱指针提升为强指针时，计数器的变化

     //强指针直接构造（拿原始指针构造）时：
     //1. 初始化_Ty * _Ptr
     //2. 创建_Ref_count对象
     //3. _Ref_count_base对象构造时，会分别为_Uses = 1 并且 _Weaks = 1

*/

int _tmain(int argc, _TCHAR* argv[])
{
    std::shared_ptr<int> sptr(new int(3));
    std::shared_ptr<int> sptr2 = sptr;

    std::weak_ptr<int> wptr = sptr;

    if (!wptr.expired()) {
        std::shared_ptr<int> sptr3 = wptr.lock();
    }

    return 0;
}
```

