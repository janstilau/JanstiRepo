#ifndef QOBJECTDEFS_H
#define QOBJECTDEFS_H

Q_CORE_EXPORT const char *qFlagLocation(const char *method);

// 这里, 在 Connect 的时候, 这两个宏仅仅是在方法名前面增加了特殊的标识. 这样, 在验证的时候, 首先可以根据标识来进行验证.
#  define METHOD(a)   "0"#a
# define SLOT(a)     "1"#a
# define SIGNAL(a)   "2"#a

#define QMETHOD_CODE  0                        // member type codes
#define QSLOT_CODE    1
#define QSIGNAL_CODE  2
#endif // QT_NO_META_MACROS

/*
 QString retVal;
 QByteArray normalizedSignature = QMetaObject::normalizedSignature("compute(QString, int, double)");
 int methodIndex = obj->metaObject()->indexOfMethod(normalizedSignature);
 QMetaMethod method = obj->metaObject()->method(methodIndex);
 method.invoke(obj,
               Qt::DirectConnection,
               Q_RETURN_ARG(QString, retVal),
               Q_ARG(QString, "sqrt"),
               Q_ARG(int, 42),
               Q_ARG(double, 9.7));
 */

/*
 宏的应该用在, 在某些不太符合语法格式的地方.
 比如这里, 泛型里面的类型, 是要明确指定的.
 这个时候, 用宏就可以达到目的.
 */
#define Q_ARG(type, data) QArgument<type >(#type, data)
#define Q_RETURN_ARG(type, data) QReturnArgument<type >(#type, data)

class QObject;
class QMetaMethod;
class QMetaEnum;
class QMetaProperty;
class QMetaClassInfo;

class Q_CORE_EXPORT QGenericArgument
{
public:
    inline QGenericArgument(const char *aName = Q_NULLPTR, const void *aData = Q_NULLPTR)
        : _data(aData), _name(aName) {}
    inline void *data() const { return const_cast<void *>(_data); }
    inline const char *name() const { return _name; }

private:
    const void *_data;
    const char *_name;
};

class Q_CORE_EXPORT QGenericReturnArgument: public QGenericArgument
{
public:
    inline QGenericReturnArgument(const char *aName = Q_NULLPTR, void *aData = Q_NULLPTR)
        : QGenericArgument(aName, aData)
        {}
};

/*
 QGenericArgument 里面, 会存储 type , 和 data 的指针, QGrgument 里面, 则会有泛型的指定.
 */
template <class T>
class QArgument: public QGenericArgument
{
public:
    inline QArgument(const char *aName, const T &aData)
        : QGenericArgument(aName, static_cast<const void *>(&aData))
        {}
};

template <class T>
class QArgument<T &>: public QGenericArgument
{
public:
    inline QArgument(const char *aName, T &aData)
        : QGenericArgument(aName, static_cast<const void *>(&aData))
        {}
};


template <typename T>
class QReturnArgument: public QGenericReturnArgument
{
public:
    inline QReturnArgument(const char *aName, T &aData)
        : QGenericReturnArgument(aName, static_cast<void *>(&aData))
        {}
};


/*
 一个类的元信息数据.
 */
struct Q_CORE_EXPORT QMetaObject
{
    class Connection;
    const char *className() const;
    const QMetaObject *superClass() const;
    
    // 这几个函数能够实现, 得力于 metaobject 里面, 存储了父类的 metaobject 的指针.
    bool inherits(const QMetaObject *metaObject) const Q_DECL_NOEXCEPT;
    QObject *cast(QObject *obj) const;
    const QObject *cast(const QObject *obj) const;

    // 以下的几个 get 函数, 就是从自己存储的信息里面取值. 如何读取, 是 Qt 内部的规格, 不用太抠这些细节.
    int methodOffset() const;
    int enumeratorOffset() const;
    int propertyOffset() const;
    int classInfoOffset() const;

    int constructorCount() const;
    int methodCount() const;
    int enumeratorCount() const;
    int propertyCount() const;
    int classInfoCount() const;

    int indexOfConstructor(const char *constructor) const;
    int indexOfMethod(const char *method) const;
    int indexOfSignal(const char *signal) const;
    int indexOfSlot(const char *slot) const;
    int indexOfEnumerator(const char *name) const;
    int indexOfProperty(const char *name) const;
    int indexOfClassInfo(const char *name) const;

    QMetaMethod constructor(int index) const;
    QMetaMethod method(int index) const;
    QMetaEnum enumerator(int index) const;
    QMetaProperty property(int index) const;
    QMetaClassInfo classInfo(int index) const;
    QMetaProperty userProperty() const;

    /*
     check 函数非常重要, 它是在 connect 的时候, 判断信号槽是否匹配的.
     */
    static bool checkConnectArgs(const char *signal, const char *method);
    static bool checkConnectArgs(const QMetaMethod &signal,
                                 const QMetaMethod &method);
    static QByteArray normalizedSignature(const char *method);
    static QByteArray normalizedType(const char *type);

    // connect 实现的基础. 通过 sender, receiver 的信息, 建立一个 connect, 然后存储到 sender 内部.
    static Connection connect(const QObject *sender, int signal_index,
                        const QObject *receiver, int method_index,
                        int type = 0, int *types = Q_NULLPTR);
    // 通过 sender, receiver 的信息, 把之前存储的 Connnection 删除.
    static bool disconnect(const QObject *sender, int signal_index,
                           const QObject *receiver, int method_index);
    static bool disconnectOne(const QObject *sender, int signal_index,
                              const QObject *receiver, int method_index);
    // internal slot-name based connect
    static void connectSlotsByName(QObject *o);

    // 信号槽机制可以运行的基础. 发送一个信号, 就是调用一下的几个函数.
    // 通过 sender 里面存储的 connection, 找到对应的 receiver, 然后调用对应的 slot 方法.
    static void activate(QObject *sender, int signal_index, void **argv);
    static void activate(QObject *sender, const QMetaObject *, int local_signal_index, void **argv);
    static void activate(QObject *sender, int signal_offset, int local_signal_index, void **argv);

    // 找到对应的 MetaMethod, 然后调用它的 invoke 方法.
    static bool invokeMethod(QObject *obj, const char *member,
                             Qt::ConnectionType,
                             QGenericReturnArgument ret,
                             QGenericArgument val0 = QGenericArgument(Q_NULLPTR),
                             QGenericArgument val1 = QGenericArgument(),
                             QGenericArgument val2 = QGenericArgument(),
                             QGenericArgument val3 = QGenericArgument(),
                             QGenericArgument val4 = QGenericArgument(),
                             QGenericArgument val5 = QGenericArgument(),
                             QGenericArgument val6 = QGenericArgument(),
                             QGenericArgument val7 = QGenericArgument(),
                             QGenericArgument val8 = QGenericArgument(),
                             QGenericArgument val9 = QGenericArgument());
    // 找到对应的 构造函数, 然后调用.
    QObject *newInstance(QGenericArgument val0 = QGenericArgument(Q_NULLPTR),
                         QGenericArgument val1 = QGenericArgument(),
                         QGenericArgument val2 = QGenericArgument(),
                         QGenericArgument val3 = QGenericArgument(),
                         QGenericArgument val4 = QGenericArgument(),
                         QGenericArgument val5 = QGenericArgument(),
                         QGenericArgument val6 = QGenericArgument(),
                         QGenericArgument val7 = QGenericArgument(),
                         QGenericArgument val8 = QGenericArgument(),
                         QGenericArgument val9 = QGenericArgument()) const;

    enum Call {
        InvokeMetaMethod,
        ReadProperty,
        WriteProperty,
        ResetProperty,
        QueryPropertyDesignable,
        QueryPropertyScriptable,
        QueryPropertyStored,
        QueryPropertyEditable,
        QueryPropertyUser,
        CreateInstance,
        IndexOfMethod,
        RegisterPropertyMetaType,
        RegisterMethodArgumentMetaType
    };

    int static_metacall(Call, int, void **) const;
    static int metacall(QObject *, Call, int, void **);

    typedef void (*StaticMetacallFunction)(QObject *, QMetaObject::Call, int, void **);
    struct { // private data
        const QMetaObject *superdata;
        const QByteArrayData *stringdata;
        const uint *data;
        StaticMetacallFunction static_metacall;
        const QMetaObject * const *relatedMetaObjects;
        void *extradata; //reserved for future use
    } d;
};

class Q_CORE_EXPORT QMetaObject::Connection {
    void *d_ptr; //QObjectPrivate::Connection*
    explicit Connection(void *data) : d_ptr(data) {  }
    bool isConnected_helper() const;
public:
    ~Connection();
    Connection();
    Connection(const Connection &other);
    Connection &operator=(const Connection &other);
#ifdef Q_QDOC
    operator bool() const;
#else
    typedef void *Connection::*RestrictedBool;
    operator RestrictedBool() const { return d_ptr && isConnected_helper() ? &Connection::d_ptr : Q_NULLPTR; }
#endif

};

inline const QMetaObject *QMetaObject::superClass() const
{ return d.superdata; }

QT_END_NAMESPACE

#endif // QOBJECTDEFS_H
