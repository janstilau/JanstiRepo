# QMetaObject

https://zhuanlan.zhihu.com/p/99223617 



Qt 程序在交由标准编译器编译之前，先要使用 moc 分析 C++ 源文件。如果它发现在一个头文件中包含了宏 Q_OBJECT，则会生成另外一个 C++ 源文件, 以 Moc 开头。
这个源文件, 里面还是该类的实现函数. 这些函数, 是 Meta-Object-System 所需要的, 其中重要的有

类名为 MyProcesse	
Q_CLASSINFO(Name, Value)
Q_ENUM(...)
Q_ENUM_NS(...)
Q_INVOKABLE
Q_OBJECT
Q_PROPERTY(...)
Q_SIGNAL
Q_SIGNALS
Q_SLOT
Q_SLOTSr

* qt_meta_stringdata_MyProcesser 静态变量.
该对象里面, 存储了该类元信息的字符串描述.
所有由上述宏修饰的信息, 都会在这个对象里面存储.


* qt_meta_data_MyProcesser 静态变量.
该对象里面, 存储了该类元信息的实际存储, 格式由 Qt 系统设计. 不是人工可以直译的.
所有由上述宏修饰的信息, 都会在这个对象里面存储.

* const QMetaObject MyProcesser::staticMetaObject 静态变量;  
这个变量里面存储了
父类的元信息对象地址;
qt_meta_stringdata_MyProcesser 地址;
qt_meta_data_MyProcesser 地址;
qt_static_metacall 的函数地址.

* const QMetaObject *MyProcesser::metaObject() const 函数;
这个函数返回 staticMetaObject 的地址, 通过这个函数, 就可以从对象上, 获取到元信息.

* void MyProcesser::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a) 函数
这个函数是元信息编程成功的基础. 
每个类都有着这样的一个函数, 通过 _c 的类型, _id 值得不同, 调用到本类的不同的方法. _a 里面, 存储的是各个方法的参数.

* 各个信号函数的定义.
它们内部一般都是调用 QMetaObject::activate(this, &staticMetaObject, 0, _a);

各个文件源代码, 放在了本文档统计目录.

## Q_OBJECT

``` C++
#define Q_OBJECT \
public: \
    QT_WARNING_PUSH \
    Q_OBJECT_NO_OVERRIDE_WARNING \
    // 声明一个 staticMetaObject 用来存储该类的 MetaObject
    static const QMetaObject staticMetaObject; \ 
    // 这个函数, 在 moc 文件里面实现, 返回 staticMetaObject 的地址.
    virtual const QMetaObject *metaObject() const; \ // 声明一个函数, 返回元对象的指针.
    virtual void *qt_metacast(const char *); \
    virtual int qt_metacall(QMetaObject::Call, int, void **); \
    QT_TR_FUNCTIONS \
private: \
    Q_OBJECT_NO_ATTRIBUTES_WARNING \
    Q_DECL_HIDDEN_STATIC_METACALL static void qt_static_metacall(QObject *, QMetaObject::Call, int, void **); \
    QT_WARNING_POP \
    struct QPrivateSignal {}; \
    QT_ANNOTATE_CLASS(qt_qobject, "")
```

这个宏, 就是定义 metaObject 和相应的方法到 H 文件. 因为 C++ 里面, 要把类的所有信息都展示出来.

各个类的解析, 直接到各个类的源代码中进行.