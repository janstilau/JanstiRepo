#ifndef QMETAOBJECT_H
#define QMETAOBJECT_H

#include <QtCore/qobjectdefs.h>
#include <QtCore/qvariant.h>

QT_BEGIN_NAMESPACE

template <typename T> class QList;

#define Q_METAMETHOD_INVOKE_MAX_ARGS 10
/*
 Meta 相关的类, 都在一个文件里面.
 */
/*
 QMetaMethod 表示, 一个类中的某个函数.
 这个函数, 一定是 SLOT, SIGNAL, 还有被 QINVOKABLE 修饰过得其他函数.
 */
class Q_CORE_EXPORT QMetaMethod
{
public:
    Q_DECL_CONSTEXPR inline QMetaMethod() : mobj(nullptr), handle(0) {}

    QByteArray methodSignature() const;
    QByteArray name() const;
    const char *typeName() const;
    int returnType() const;
    int parameterCount() const;
    int parameterType(int index) const;
    void getParameterTypes(int *types) const;
    QList<QByteArray> parameterTypes() const;
    QList<QByteArray> parameterNames() const;
    const char *tag() const;
    enum Access { Private, Protected, Public };
    Access access() const;
    enum MethodType { Method, Signal, Slot, Constructor };
    MethodType methodType() const;
    enum Attributes { Compatibility = 0x1, Cloned = 0x2, Scriptable = 0x4 };
    int attributes() const;
    int methodIndex() const;
    int revision() const;

    inline const QMetaObject *enclosingMetaObject() const { return mobj; }

    bool invoke(QObject *object,
                Qt::ConnectionType connectionType,
                QGenericReturnArgument returnValue,
                QGenericArgument val0 = QGenericArgument(nullptr),
                QGenericArgument val1 = QGenericArgument(),
                QGenericArgument val2 = QGenericArgument(),
                QGenericArgument val3 = QGenericArgument(),
                QGenericArgument val4 = QGenericArgument(),
                QGenericArgument val5 = QGenericArgument(),
                QGenericArgument val6 = QGenericArgument(),
                QGenericArgument val7 = QGenericArgument(),
                QGenericArgument val8 = QGenericArgument(),
                QGenericArgument val9 = QGenericArgument()) const;

    inline bool isValid() const { return mobj != nullptr; }

    // 从 &QObject::destoryed 这种信息, 还是会变为 fromSignalImpl. 这里也说明了, PointerToMemberFunction 里面, 会存储类型的元信息.
    template <typename PointerToMemberFunction>
    static inline QMetaMethod fromSignal(PointerToMemberFunction signal)
    {
        typedef QtPrivate::FunctionPointer<PointerToMemberFunction> SignalType;
        Q_STATIC_ASSERT_X(QtPrivate::HasQ_OBJECT_Macro<typename SignalType::Object>::Value,
                          "No Q_OBJECT in the class with the signal");
        return fromSignalImpl(&SignalType::Object::staticMetaObject,
                              reinterpret_cast<void **>(&signal));
    }

private:
    static QMetaMethod fromSignalImpl(const QMetaObject *, void **);
    
private:
    // 实际上, 这个类仅仅存储两个值, QMetaObject 的地址, 和句柄值.
    const QMetaObject *mobj;
    uint handle;
};
Q_DECLARE_TYPEINFO(QMetaMethod, Q_MOVABLE_TYPE);

inline bool operator==(const QMetaMethod &m1, const QMetaMethod &m2)
{ return m1.mobj == m2.mobj && m1.handle == m2.handle; }
inline bool operator!=(const QMetaMethod &m1, const QMetaMethod &m2)
{ return !(m1 == m2); }

/*
 这个类代表着, 在某个类里面定义的 枚举 信息. 一般来说, 没有太多使用的必要.
 相比较纯粹的 Int 表示 Enum, 它将 Enum 的描述信息, 保存到了内部.
 */
class Q_CORE_EXPORT QMetaEnum
{
public:
    Q_DECL_CONSTEXPR inline QMetaEnum() : mobj(nullptr), handle(0) {}

    const char *name() const;
    const char *enumName() const;
    bool isFlag() const;
    bool isScoped() const;

    int keyCount() const;
    const char *key(int index) const;
    int value(int index) const;

    const char *scope() const;

    int keyToValue(const char *key, bool *ok = nullptr) const;
    const char* valueToKey(int value) const;
    int keysToValue(const char * keys, bool *ok = nullptr) const;
    QByteArray valueToKeys(int value) const;

    inline const QMetaObject *enclosingMetaObject() const { return mobj; }

    inline bool isValid() const { return name() != nullptr; }

    template<typename T> static QMetaEnum fromType() {
        const QMetaObject *metaObject = qt_getEnumMetaObject(T());
        const char *name = qt_getEnumName(T());
        return metaObject->enumerator(metaObject->indexOfEnumerator(name));
    }

private:
    const QMetaObject *mobj;
    uint handle;
    friend struct QMetaObject;
};
Q_DECLARE_TYPEINFO(QMetaEnum, Q_MOVABLE_TYPE);

/*
 属性的元信息存储类.
 概念上和 OC 的差不太多.
 notify 指的是, 这个属性值改变了之后, 会自动发送对应的信号.
 reset 指的是, 给这个属性, 设置一个非法值之后, 会自动调用 reset 函数.
 */
class Q_CORE_EXPORT QMetaProperty
{
public:
    QMetaProperty();

    const char *name() const;
    const char *typeName() const;
    QVariant::Type type() const;
    int userType() const;
    int propertyIndex() const;

    bool isReadable() const;
    bool isWritable() const;
    bool isResettable() const;
    bool isDesignable(const QObject *obj = nullptr) const;
    bool isScriptable(const QObject *obj = nullptr) const;
    bool isStored(const QObject *obj = nullptr) const;
    bool isEditable(const QObject *obj = nullptr) const;
    bool isUser(const QObject *obj = nullptr) const;
    bool isConstant() const;
    bool isFinal() const;

    bool isFlagType() const;
    bool isEnumType() const;
    QMetaEnum enumerator() const;

    bool hasNotifySignal() const;
    QMetaMethod notifySignal() const;
    int notifySignalIndex() const;

    int revision() const;

    QVariant read(const QObject *obj) const;
    bool write(QObject *obj, const QVariant &value) const;
    bool reset(QObject *obj) const;

    QVariant readOnGadget(const void *gadget) const;
    bool writeOnGadget(void *gadget, const QVariant &value) const;
    bool resetOnGadget(void *gadget) const;

    bool hasStdCppSet() const;
    inline bool isValid() const { return isReadable(); }
    inline const QMetaObject *enclosingMetaObject() const { return mobj; }

private:
    int registerPropertyType() const;

    const QMetaObject *mobj;
    uint handle;
    int idx;
    QMetaEnum menum;
    friend struct QMetaObject;
    friend struct QMetaObjectPrivate;
};

/*
 类的一些附加信息, 可以认为是类的一些静态变量, keyvalue 的形式.
 */
class Q_CORE_EXPORT QMetaClassInfo
{
public:
    Q_DECL_CONSTEXPR inline QMetaClassInfo() : mobj(nullptr), handle(0) {}
    const char *name() const;
    const char *value() const;
    inline const QMetaObject *enclosingMetaObject() const { return mobj; }
private:
    const QMetaObject *mobj;
    uint handle;
    friend struct QMetaObject;
};
Q_DECLARE_TYPEINFO(QMetaClassInfo, Q_MOVABLE_TYPE);

QT_END_NAMESPACE

#endif // QMETAOBJECT_H
