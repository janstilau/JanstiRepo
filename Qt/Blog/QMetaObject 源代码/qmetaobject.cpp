#include "qmetaobject.h"
#include "qmetatype.h"
#include "qobject.h"
#include "qmetaobject_p.h"

#include <qcoreapplication.h>
#include <qcoreevent.h>
#include <qdatastream.h>
#include <qstringlist.h>
#include <qthread.h>
#include <qvariant.h>
#include <qdebug.h>
#include <qsemaphore.h>

QT_BEGIN_NAMESPACE

/*
 Q_ASSERT(priv(m->d.data)->revision >= 7);
 是因为, 现在的 QObject 的存储 revision 是 7.
*/

static inline const QMetaObjectPrivate *priv(const uint* data)
{ return reinterpret_cast<const QMetaObjectPrivate*>(data); }

static inline const QByteArray stringData(const QMetaObject *mo, int index)
{
    const QByteArrayDataPtr data = { const_cast<QByteArrayData*>(&mo->d.stringdata[index]) };
    return data;
}

static inline const char *rawStringData(const QMetaObject *mo, int index)
{
    return stringData(mo, index).data();
}

static inline QByteArray typeNameFromTypeInfo(const QMetaObject *mo, uint typeInfo)
{
    if (typeInfo & IsUnresolvedType) {
        return stringData(mo, typeInfo & TypeNameIndexMask);
    } else {
        // ### Use the QMetaType::typeName() that returns QByteArray
        const char *t = QMetaType::typeName(typeInfo);
        return QByteArray::fromRawData(t, qstrlen(t));
    }
}

static inline const char *rawTypeNameFromTypeInfo(const QMetaObject *mo, uint typeInfo)
{
    return typeNameFromTypeInfo(mo, typeInfo).constData();
}

static inline int typeFromTypeInfo(const QMetaObject *mo, uint typeInfo)
{
    if (!(typeInfo & IsUnresolvedType))
        return typeInfo;
    return QMetaType::type(stringData(mo, typeInfo & TypeNameIndexMask));
}

// QMetaMethod 的内部实现类. 这个类里面没有存储的事情.
// 在使用上, 很多时候是通过 get 函数, 将 QMetaMethod 变为一个 QMetaMethodPrivate 对象, 然后调用 QMetaMethodPrivate 的方法.
// 之所以要这样, 是因为, C++ 需要将所有的方法, 声明在 H 文件里面. 但是有些函数, 本身就是只会在 m 中出现.
// 这种方式, 将这些函数都放在 QMetaMethodPrivate 里面, 避免了暴露.
// 在 QMetaMethod 的 h 文件里面, 声明了 friend QMetaMethodPrivate , 这样, Private 里面也可以访问数据.
// QMetaMethodPrivate 里面, 只是做方法的集合, 没有任何数据层面的事情.
class QMetaMethodPrivate : public QMetaMethod
{
public:
    static const QMetaMethodPrivate *get(const QMetaMethod *q)
    { return static_cast<const QMetaMethodPrivate *>(q); }

    inline QByteArray signature() const;
    inline QByteArray name() const;
    inline int typesDataIndex() const;
    inline const char *rawReturnTypeName() const;
    inline int returnType() const;
    inline int parameterCount() const;
    inline int parametersDataIndex() const;
    inline uint parameterTypeInfo(int index) const;
    inline int parameterType(int index) const;
    inline void getParameterTypes(int *types) const;
    inline QList<QByteArray> parameterTypes() const;
    inline QList<QByteArray> parameterNames() const;
    inline QByteArray tag() const;
    inline int ownMethodIndex() const;

private:
    QMetaMethodPrivate();
};

QObject *QMetaObject::newInstance(QGenericArgument val0,
                                  QGenericArgument val1,
                                  QGenericArgument val2,
                                  QGenericArgument val3,
                                  QGenericArgument val4,
                                  QGenericArgument val5,
                                  QGenericArgument val6,
                                  QGenericArgument val7,
                                  QGenericArgument val8,
                                  QGenericArgument val9) const
{
    QByteArray constructorName = className();
    {
        int idx = constructorName.lastIndexOf(':');
        if (idx != -1)
            constructorName.remove(0, idx+1);
        // remove qualified part, 这里, 首先删除 className.
    }
    // 然后就是拼接构造函数的签名的过程.
    QVarLengthArray<char, 512> sig;
    sig.append(constructorName.constData(), constructorName.length());
    sig.append('(');

    enum { MaximumParamCount = 10 }; // 一个 const int 不更好吗.
    // QGenericArgument 里面, 存储了就存储了 type, 就是为了在拼接函数签名的时候使用.
    const char *typeNames[] = {val0.name(), val1.name(), val2.name(), val3.name(), val4.name(),
                               val5.name(), val6.name(), val7.name(), val8.name(), val9.name()};

    int paramCount;
    for (paramCount = 0; paramCount < MaximumParamCount; ++paramCount) {
        int len = qstrlen(typeNames[paramCount]);
        if (len <= 0)
            break;
        sig.append(typeNames[paramCount], len);
        sig.append(',');
    }
    if (paramCount == 0)
        sig.append(')'); // no parameters
    else
        sig[sig.size() - 1] = ')';
    sig.append('\0');
    // 经过了之前的拼接过程, 现在 sig 里面, 就是

    int idx = indexOfConstructor(sig.constData());
    if (idx < 0) {
        QByteArray norm = QMetaObject::normalizedSignature(sig.constData());
        idx = indexOfConstructor(norm.constData());
    }
    if (idx < 0)
        return 0;
    // 到了这里, idx 就是构造函数在 metaObject 里面的索引值了.

    QObject *returnValue = 0;
    void *param[] = {&returnValue, val0.data(), val1.data(), val2.data(), val3.data(), val4.data(),
                     val5.data(), val6.data(), val7.data(), val8.data(), val9.data()};
    
    // 然后, 就是传入 Call 的类型为 CreateInstance, Idx 的值, 参数的值. 最终, 返回值保存在 returnValue 里面.
    if (static_metacall(CreateInstance, idx, param) >= 0)
        return 0;
    return returnValue;
}

/*
 这个方法, 非常核心.
 它的实现很简单, 就是调用 static_metacall 这个函数指针而已.
 而这个函数指针, 是 moc 文件里面指定的.
 每个类, 如何能够动态的调用到相应的 Constructor, method, setProperty, getProperty, 都是在 Moc 文件里面写明的.
 这个函数, 被存储到了 metaObject 里面, 然后在这, 进行调用.
 */
int QMetaObject::static_metacall(Call cl, int idx, void **argv) const
{
    if (!d.static_metacall)
        return 0;
    d.static_metacall(0, cl, idx, argv);
    return -1;
}

int QMetaObject::metacall(QObject *object, Call cl, int idx, void **argv)
{
    if (object->d_ptr->metaObject)
        return object->d_ptr->metaObject->metaCall(object, cl, idx, argv);
    else
        return object->qt_metacall(cl, idx, argv);
}

// className 的实现很简单, 就是读取数据, 然后返回.
static inline const char *objectClassName(const QMetaObject *m)
{
    return rawStringData(m, priv(m->d.data)->className);
}

const char *QMetaObject::className() const
{
    return objectClassName(this);
}

// 继承关系的判断, 完全依赖于 metaobject 里面, 存储了 superdata.
bool QMetaObject::inherits(const QMetaObject *metaObject) const Q_DECL_NOEXCEPT
{
    const QMetaObject *m = this;
    do {
        if (metaObject == m)
            return true;
    } while ((m = m->d.superdata));
    return false;
}

QObject *QMetaObject::cast(QObject *obj) const
{
    return const_cast<QObject*>(cast(const_cast<const QObject*>(obj)));
}

const QObject *QMetaObject::cast(const QObject *obj) const
{
    return (obj && obj->metaObject()->inherits(this)) ? obj : nullptr;
}

// 这里, 就是为什么在类中使用 tr, 会自动变为类名所在的 TranslationGroup 的原因所在.
// 感觉 QObject 里面, 做了太多的东西了.
QString QMetaObject::tr(const char *s, const char *c, int n) const
{
    return QCoreApplication::translate(objectClassName(this), s, c, n);
}

// 每个类的元信息里面, 仅仅存放在自己的数据. 不过, 这里把所有的父类的占位都计算进去了.
int QMetaObject::methodOffset() const
{
    int offset = 0;
    const QMetaObject *m = d.superdata;
    while (m) {
        offset += priv(m->d.data)->methodCount;
        m = m->d.superdata;
    }
    return offset;
}

int QMetaObject::enumeratorOffset() const
{
    int offset = 0;
    const QMetaObject *m = d.superdata;
    while (m) {
        offset += priv(m->d.data)->enumeratorCount;
        m = m->d.superdata;
    }
    return offset;
}

int QMetaObject::propertyOffset() const
{
    int offset = 0;
    const QMetaObject *m = d.superdata;
    while (m) {
        offset += priv(m->d.data)->propertyCount;
        m = m->d.superdata;
    }
    return offset;
}

int QMetaObject::classInfoOffset() const
{
    int offset = 0;
    const QMetaObject *m = d.superdata;
    while (m) {
        offset += priv(m->d.data)->classInfoCount;
        m = m->d.superdata;
    }
    return offset;
}

// 以下函数, 就是直接读取 元信息的值而已.
int QMetaObject::constructorCount() const
{
    Q_ASSERT(priv(d.data)->revision >= 2);
    return priv(d.data)->constructorCount;
}

int QMetaObject::methodCount() const
{
    int n = priv(d.data)->methodCount;
    const QMetaObject *m = d.superdata;
    while (m) {
        n += priv(m->d.data)->methodCount;
        m = m->d.superdata;
    }
    return n;
}

int QMetaObject::enumeratorCount() const
{
    int n = priv(d.data)->enumeratorCount;
    const QMetaObject *m = d.superdata;
    while (m) {
        n += priv(m->d.data)->enumeratorCount;
        m = m->d.superdata;
    }
    return n;
}

int QMetaObject::propertyCount() const
{
    int n = priv(d.data)->propertyCount;
    const QMetaObject *m = d.superdata;
    while (m) {
        n += priv(m->d.data)->propertyCount;
        m = m->d.superdata;
    }
    return n;
}

int QMetaObject::classInfoCount() const
{
    int n = priv(d.data)->classInfoCount;
    const QMetaObject *m = d.superdata;
    while (m) {
        n += priv(m->d.data)->classInfoCount;
        m = m->d.superdata;
    }
    return n;
}

// 比对某个元信息的某个方法, 函数名, 参数个数, 参数类型 是否和参数一致.
static bool methodMatch(const QMetaObject *m, int handle,
                        const QByteArray &name, int argc,
                        const QArgumentType *types)
{
    // 首先, 是比对参数个数.
    // m->d.data[handle + 1] 是参数个数, 不用去深究, 因为如何进行存储, 是 Qt 内部自己设计的.
    if (int(m->d.data[handle + 1]) != argc)
        return false;

    // 然后是函数名
    if (stringData(m, m->d.data[handle]) != name)
        return false;
    // 然后是各个参数的类型.
    int paramsIndex = m->d.data[handle + 2] + 1;
    for (int i = 0; i < argc; ++i) {
        uint typeInfo = m->d.data[paramsIndex + i];
        if (types[i].type()) {
            if (types[i].type() != typeFromTypeInfo(m, typeInfo))
                return false;
        } else {
            if (types[i].name() != typeNameFromTypeInfo(m, typeInfo))
                return false;
        }
    }

    return true;
}

// 这里, 写法很诡异.
// MethodType 其实是当做一个参数来使用了, 用来区分, memberMethod, signal, slot.
// 本质上, 这个方法就是, 函数在 MetaObject 里面存储的信息, 和各个参数的比对.
template<int MethodType>
static inline int indexOfMethodRelative(const QMetaObject **baseObject,
                                        const QByteArray &name, int argc,
                                        const QArgumentType *types)
{
    for (const QMetaObject *m = *baseObject; m; m = m->d.superdata) {
        int i = (MethodType == MethodSignal)
                 ? (priv(m->d.data)->signalCount - 1) : (priv(m->d.data)->methodCount - 1);
        const int end = (MethodType == MethodSlot)
                        ? (priv(m->d.data)->signalCount) : 0;

        for (; i >= end; --i) {
            int handle = priv(m->d.data)->methodData + 5*i;
            if (methodMatch(m, handle, name, argc, types)) {
                *baseObject = m;
                return i;
            }
        }
    }
    return -1;
}

// 返回, 某个构造函数, 在元信息里面存储的位置.
int QMetaObject::indexOfConstructor(const char *constructor) const
{
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(constructor, types);
    return QMetaObjectPrivate::indexOfConstructor(this,
                                                  name,
                                                  types.size(),
                                                  types.constData());
}

int QMetaObject::indexOfMethod(const char *method) const
{
    const QMetaObject *m = this;
    int i;
    Q_ASSERT(priv(m->d.data)->revision >= 7);
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(method, types);
    i = indexOfMethodRelative<0>(&m, name, types.size(), types.constData());
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

// 这里就是最简单的, 根据 , 进行分割的逻辑.
static void argumentTypesFromString(const char *str, const char *end,
                                    QArgumentTypeArray &types)
{
    while (str != end) {
        if (!types.isEmpty())
            ++str; // Skip comma
        const char *begin = str;
        int level = 0;
        while (str != end && (level > 0 || *str != ',')) {
            if (*str == '<')
                ++level;
            else if (*str == '>')
                --level;
            ++str;
        }
        types += QArgumentType(QByteArray(begin, str - begin));
    }
}

// 分解函数签名, 返回函数名, 并且把参数的 type 用 inout 参数传出.
QByteArray QMetaObjectPrivate::decodeMethodSignature(
        const char *signature, QArgumentTypeArray &types)
{
    const char *lparens = strchr(signature, '(');
    if (!lparens)
        return QByteArray();
    const char *rparens = strrchr(lparens + 1, ')');
    if (!rparens || *(rparens+1))
        return QByteArray();
    int nameLength = lparens - signature;
    argumentTypesFromString(lparens + 1, rparens, types);
    return QByteArray::fromRawData(signature, nameLength);
}

int QMetaObject::indexOfSignal(const char *signal) const
{
    const QMetaObject *m = this;
    int i;
    Q_ASSERT(priv(m->d.data)->revision >= 7);
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(signal, types);
    i = QMetaObjectPrivate::indexOfSignalRelative(&m, name, types.size(), types.constData());
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

/*!
    \internal
    Same as QMetaObject::indexOfSignal, but the result is the local offset to the base object.

    \a baseObject will be adjusted to the enclosing QMetaObject, or 0 if the signal is not found
*/
int QMetaObjectPrivate::indexOfSignalRelative(const QMetaObject **baseObject,
                                              const QByteArray &name, int argc,
                                              const QArgumentType *types)
{
    int i = indexOfMethodRelative<MethodSignal>(baseObject, name, argc, types);
#ifndef QT_NO_DEBUG
    const QMetaObject *m = *baseObject;
    if (i >= 0 && m && m->d.superdata) {
        int conflict = indexOfMethod(m->d.superdata, name, argc, types);
     }
 #endif
     return i;
}

/*!
    Finds \a slot and returns its index; otherwise returns -1.

    This is the same as indexOfMethod(), except that it will return
    -1 if the method exists but isn't a slot.

    \sa indexOfMethod(), method(), methodCount(), methodOffset()
*/
int QMetaObject::indexOfSlot(const char *slot) const
{
    const QMetaObject *m = this;
    int i;
    Q_ASSERT(priv(m->d.data)->revision >= 7);
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(slot, types);
    i = QMetaObjectPrivate::indexOfSlotRelative(&m, name, types.size(), types.constData());
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

// Signal, SLot, 和普通方法的区别没有去细研究, 逻辑应该就是方法比对那一套.
int QMetaObjectPrivate::indexOfSlotRelative(const QMetaObject **m,
                                            const QByteArray &name, int argc,
                                            const QArgumentType *types)
{
    return indexOfMethodRelative<MethodSlot>(m, name, argc, types);
}

int QMetaObjectPrivate::indexOfSignal(const QMetaObject *m, const QByteArray &name,
                                      int argc, const QArgumentType *types)
{
    int i = indexOfSignalRelative(&m, name, argc, types);
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

int QMetaObjectPrivate::indexOfSlot(const QMetaObject *m, const QByteArray &name,
                                    int argc, const QArgumentType *types)
{
    int i = indexOfSlotRelative(&m, name, argc, types);
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

int QMetaObjectPrivate::indexOfMethod(const QMetaObject *m, const QByteArray &name,
                                      int argc, const QArgumentType *types)
{
    int i = indexOfMethodRelative<0>(&m, name, argc, types);
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

int QMetaObjectPrivate::indexOfConstructor(const QMetaObject *m, const QByteArray &name,
                                           int argc, const QArgumentType *types)
{
    for (int i = priv(m->d.data)->constructorCount-1;
         i >= 0;
         --i) {
        int handle = priv(m->d.data)->constructorData + 5*i;
        if (methodMatch(m, handle, name, argc, types))
            return i;
    }
    return -1;
}

int QMetaObjectPrivate::signalOffset(const QMetaObject *m)
{
    Q_ASSERT(m != 0);
    int offset = 0;
    for (m = m->d.superdata; m; m = m->d.superdata)
        offset += priv(m->d.data)->signalCount;
    return offset;
}

int QMetaObjectPrivate::absoluteSignalCount(const QMetaObject *m)
{
    Q_ASSERT(m != 0);
    int n = priv(m->d.data)->signalCount;
    for (m = m->d.superdata; m; m = m->d.superdata)
        n += priv(m->d.data)->signalCount;
    return n;
}

int QMetaObjectPrivate::signalIndex(const QMetaMethod &m)
{
    if (!m.mobj)
        return -1;
    return QMetaMethodPrivate::get(&m)->ownMethodIndex() + signalOffset(m.mobj);
}

QMetaMethod QMetaObjectPrivate::signal(const QMetaObject *m, int signal_index)
{
    QMetaMethod result;
    if (signal_index < 0)
        return result;
    int i = signal_index;
    i -= signalOffset(m);
    if (i < 0 && m->d.superdata)
        return signal(m->d.superdata, signal_index);

    if (i >= 0 && i < priv(m->d.data)->signalCount) {
        result.mobj = m;
        result.handle = priv(m->d.data)->methodData + 5*i;
    }
    return result;
}

// 这里, 就是判断, 信号的个数, 比如要大于槽的个数的地方. 然后就是类型的完全比对.
bool QMetaObjectPrivate::checkConnectArgs(int signalArgc,
                                          const QArgumentType *signalTypes,
                                          int methodArgc,
                                          const QArgumentType *methodTypes)
{
    if (signalArgc < methodArgc)
        return false;
    for (int i = 0; i < methodArgc; ++i) {
        if (signalTypes[i] != methodTypes[i])
            return false;
    }
    return true;
}

bool QMetaObjectPrivate::checkConnectArgs(const QMetaMethodPrivate *signal,
                                          const QMetaMethodPrivate *method)
{
    // 首先, 信号方法的类型, 一定应该是信号
    if (signal->methodType() != QMetaMethod::Signal)
        return false;
    // 信号参数的个数, 一定要大于槽的个数
    if (signal->parameterCount() < method->parameterCount())
        return false;
    
    const QMetaObject *smeta = signal->enclosingMetaObject();
    const QMetaObject *rmeta = method->enclosingMetaObject();
    
    // 然后是, 参数的 type 的字符串比对.
    for (int i = 0; i < method->parameterCount(); ++i) {
        uint sourceTypeInfo = signal->parameterTypeInfo(i);
        uint targetTypeInfo = method->parameterTypeInfo(i);
        if ((sourceTypeInfo & IsUnresolvedType)
            || (targetTypeInfo & IsUnresolvedType)) {
            QByteArray sourceName = typeNameFromTypeInfo(smeta, sourceTypeInfo);
            QByteArray targetName = typeNameFromTypeInfo(rmeta, targetTypeInfo);
            if (sourceName != targetName)
                return false;
        } else {
            int sourceType = typeFromTypeInfo(smeta, sourceTypeInfo);
            int targetType = typeFromTypeInfo(rmeta, targetTypeInfo);
            if (sourceType != targetType)
                return false;
        }
    }
    return true;
}

static const QMetaObject *QMetaObject_findMetaObject(const QMetaObject *self, const char *name)
{
    while (self) {
        if (strcmp(objectClassName(self), name) == 0)
            return self;
        if (self->d.relatedMetaObjects) {
            Q_ASSERT(priv(self->d.data)->revision >= 2);
            const QMetaObject * const *e = self->d.relatedMetaObjects;
            if (e) {
                while (*e) {
                    if (const QMetaObject *m =QMetaObject_findMetaObject((*e), name))
                        return m;
                    ++e;
                }
            }
        }
        self = self->d.superdata;
    }
    return self;
}

int QMetaObject::indexOfEnumerator(const char *name) const
{
    const QMetaObject *m = this;
    while (m) {
        const QMetaObjectPrivate *d = priv(m->d.data);
        for (int i = d->enumeratorCount - 1; i >= 0; --i) {
            const char *prop = rawStringData(m, m->d.data[d->enumeratorData + 4*i]);
            if (name[0] == prop[0] && strcmp(name + 1, prop + 1) == 0) {
                i += m->enumeratorOffset();
                return i;
            }
        }
        m = m->d.superdata;
    }
    return -1;
}

int QMetaObject::indexOfProperty(const char *name) const
{
    const QMetaObject *m = this;
    while (m) {
        const QMetaObjectPrivate *d = priv(m->d.data);
        for (int i = d->propertyCount-1; i >= 0; --i) {
            const char *prop = rawStringData(m, m->d.data[d->propertyData + 3*i]);
            if (name[0] == prop[0] && strcmp(name + 1, prop + 1) == 0) {
                i += m->propertyOffset();
                return i;
            }
        }
        m = m->d.superdata;
    }

    Q_ASSERT(priv(this->d.data)->revision >= 3);
    if (priv(this->d.data)->flags & DynamicMetaObject) {
        QAbstractDynamicMetaObject *me =
            const_cast<QAbstractDynamicMetaObject *>(static_cast<const QAbstractDynamicMetaObject *>(this));

        return me->createProperty(name, 0);
    }

    return -1;
}

int QMetaObject::indexOfClassInfo(const char *name) const
{
    int i = -1;
    const QMetaObject *m = this;
    while (m && i < 0) {
        for (i = priv(m->d.data)->classInfoCount-1; i >= 0; --i)
            if (strcmp(name, rawStringData(m, m->d.data[priv(m->d.data)->classInfoData + 2*i])) == 0) {
                i += m->classInfoOffset();
                break;
            }
        m = m->d.superdata;
    }
    return i;
}

QMetaMethod QMetaObject::constructor(int index) const
{
    int i = index;
    QMetaMethod result;
    Q_ASSERT(priv(d.data)->revision >= 2);
    if (i >= 0 && i < priv(d.data)->constructorCount) {
        result.mobj = this;
        result.handle = priv(d.data)->constructorData + 5*i;
    }
    return result;
}

QMetaMethod QMetaObject::method(int index) const
{
    int i = index;
    i -= methodOffset();
    if (i < 0 && d.superdata)
        return d.superdata->method(index);

    QMetaMethod result;
    if (i >= 0 && i < priv(d.data)->methodCount) {
        result.mobj = this;
        result.handle = priv(d.data)->methodData + 5*i;
    }
    return result;
}

QMetaEnum QMetaObject::enumerator(int index) const
{
    int i = index;
    i -= enumeratorOffset();
    if (i < 0 && d.superdata)
        return d.superdata->enumerator(index);

    QMetaEnum result;
    if (i >= 0 && i < priv(d.data)->enumeratorCount) {
        result.mobj = this;
        result.handle = priv(d.data)->enumeratorData + 4*i;
    }
    return result;
}

QMetaProperty QMetaObject::property(int index) const
{
    int i = index;
    i -= propertyOffset();
    if (i < 0 && d.superdata)
        return d.superdata->property(index);

    QMetaProperty result;
    if (i >= 0 && i < priv(d.data)->propertyCount) {
        int handle = priv(d.data)->propertyData + 3*i;
        int flags = d.data[handle + 2];
        result.mobj = this;
        result.handle = handle;
        result.idx = i;

        if (flags & EnumOrFlag) {
            const char *type = rawTypeNameFromTypeInfo(this, d.data[handle + 1]);
            result.menum = enumerator(indexOfEnumerator(type));
            if (!result.menum.isValid()) {
                const char *enum_name = type;
                const char *scope_name = objectClassName(this);
                char *scope_buffer = 0;

                const char *colon = strrchr(enum_name, ':');
                // ':' will always appear in pairs
                Q_ASSERT(colon <= enum_name || *(colon-1) == ':');
                if (colon > enum_name) {
                    int len = colon-enum_name-1;
                    scope_buffer = (char *)malloc(len+1);
                    memcpy(scope_buffer, enum_name, len);
                    scope_buffer[len] = '\0';
                    scope_name = scope_buffer;
                    enum_name = colon+1;
                }

                const QMetaObject *scope = 0;
                if (qstrcmp(scope_name, "Qt") == 0)
                    scope = &QObject::staticQtMetaObject;
                else
                    scope = QMetaObject_findMetaObject(this, scope_name);
                if (scope)
                    result.menum = scope->enumerator(scope->indexOfEnumerator(enum_name));
                if (scope_buffer)
                    free(scope_buffer);
            }
        }
    }
    return result;
}

QMetaProperty QMetaObject::userProperty() const
{
    const int propCount = propertyCount();
    for (int i = propCount - 1; i >= 0; --i) {
        const QMetaProperty prop = property(i);
        if (prop.isUser())
            return prop;
    }
    return QMetaProperty();
}

QMetaClassInfo QMetaObject::classInfo(int index) const
{
    int i = index;
    i -= classInfoOffset();
    if (i < 0 && d.superdata)
        return d.superdata->classInfo(index);

    QMetaClassInfo result;
    if (i >= 0 && i < priv(d.data)->classInfoCount) {
        result.mobj = this;
        result.handle = priv(d.data)->classInfoData + 2*i;
    }
    return result;
}

bool QMetaObject::checkConnectArgs(const char *signal, const char *method)
{
    const char *s1 = signal;
    const char *s2 = method;
    while (*s1++ != '(') { }                        // scan to first '('
    while (*s2++ != '(') { }
    if (*s2 == ')' || qstrcmp(s1,s2) == 0)        // method has no args or
        return true;                                //   exact match
    int s1len = qstrlen(s1);
    int s2len = qstrlen(s2);
    if (s2len < s1len && strncmp(s1,s2,s2len-1)==0 && s1[s2len-1]==',')
        return true;                                // method has less args
    return false;
}

// 最上层的函数.
bool QMetaObject::checkConnectArgs(const QMetaMethod &signal,
                                   const QMetaMethod &method)
{
    return QMetaObjectPrivate::checkConnectArgs(
            QMetaMethodPrivate::get(&signal),
            QMetaMethodPrivate::get(&method));
}

static void qRemoveWhitespace(const char *s, char *d)
{
    char last = 0;
    while (*s && is_space(*s))
        s++;
    while (*s) {
        while (*s && !is_space(*s))
            last = *d++ = *s++;
        while (*s && is_space(*s))
            s++;
        if (*s && ((is_ident_char(*s) && is_ident_char(last))
                   || ((*s == ':') && (last == '<')))) {
            last = *d++ = ' ';
        }
    }
    *d = '\0';
}

static char *qNormalizeType(char *d, int &templdepth, QByteArray &result)
{
    const char *t = d;
    while (*d && (templdepth
                   || (*d != ',' && *d != ')'))) {
        if (*d == '<')
            ++templdepth;
        if (*d == '>')
            --templdepth;
        ++d;
    }
    // "void" should only be removed if this is part of a signature that has
    // an explicit void argument; e.g., "void foo(void)" --> "void foo()"
    if (strncmp("void)", t, d - t + 1) != 0)
        result += normalizeTypeInternal(t, d);

    return d;
}


QByteArray QMetaObject::normalizedType(const char *type)
{
    QByteArray result;

    if (!type || !*type)
        return result;

    QVarLengthArray<char> stackbuf(qstrlen(type) + 1);
    qRemoveWhitespace(type, stackbuf.data());
    int templdepth = 0;
    qNormalizeType(stackbuf.data(), templdepth, result);

    return result;
}

QByteArray QMetaObject::normalizedSignature(const char *method)
{
    QByteArray result;
    if (!method || !*method)
        return result;
    int len = int(strlen(method));
    QVarLengthArray<char> stackbuf(len + 1);
    char *d = stackbuf.data();
    qRemoveWhitespace(method, d);

    result.reserve(len);

    int argdepth = 0;
    int templdepth = 0;
    while (*d) {
        if (argdepth == 1) {
            d = qNormalizeType(d, templdepth, result);
            if (!*d) //most likely an invalid signature.
                break;
        }
        if (*d == '(')
            ++argdepth;
        if (*d == ')')
            --argdepth;
        result += *d++;
    }

    return result;
}

enum { MaximumParamCount = 11 }; // up to 10 arguments + 1 return value

/*!
    Returns the signatures of all methods whose name matches \a nonExistentMember,
    or an empty QByteArray if there are no matches.
*/
static inline QByteArray findMethodCandidates(const QMetaObject *metaObject, const char *nonExistentMember)
{
    QByteArray candidateMessage;
    // Prevent full string comparison in every iteration.
    const QByteArray memberByteArray = nonExistentMember;
    for (int i = 0; i < metaObject->methodCount(); ++i) {
        const QMetaMethod method = metaObject->method(i);
        if (method.name() == memberByteArray)
            candidateMessage += "    " + method.methodSignature() + '\n';
    }
    if (!candidateMessage.isEmpty()) {
        candidateMessage.prepend("\nCandidates are:\n");
        candidateMessage.chop(1);
    }
    return candidateMessage;
}

bool QMetaObject::invokeMethod(QObject *obj,
                               const char *member,
                               Qt::ConnectionType type,
                               QGenericReturnArgument ret,
                               QGenericArgument val0,
                               QGenericArgument val1,
                               QGenericArgument val2,
                               QGenericArgument val3,
                               QGenericArgument val4,
                               QGenericArgument val5,
                               QGenericArgument val6,
                               QGenericArgument val7,
                               QGenericArgument val8,
                               QGenericArgument val9)
{
    if (!obj)
        return false;

    QVarLengthArray<char, 512> sig;
    int len = qstrlen(member);
    if (len <= 0)
        return false;
    sig.append(member, len);
    sig.append('(');

    const char *typeNames[] = {ret.name(), val0.name(), val1.name(), val2.name(), val3.name(),
                               val4.name(), val5.name(), val6.name(), val7.name(), val8.name(),
                               val9.name()};

    int paramCount;
    for (paramCount = 1; paramCount < MaximumParamCount; ++paramCount) {
        len = qstrlen(typeNames[paramCount]);
        if (len <= 0)
            break;
        sig.append(typeNames[paramCount], len);
        sig.append(',');
    }
    if (paramCount == 1)
        sig.append(')'); // no parameters
    else
        sig[sig.size() - 1] = ')';
    sig.append('\0');

    const QMetaObject *meta = obj->metaObject();
    int idx = meta->indexOfMethod(sig.constData());
    if (idx < 0) {
        QByteArray norm = QMetaObject::normalizedSignature(sig.constData());
        idx = meta->indexOfMethod(norm.constData());
    }

    if (idx < 0 || idx >= meta->methodCount()) {
        // This method doesn't belong to us; print out a nice warning with candidates.
        qWarning("QMetaObject::invokeMethod: No such method %s::%s%s",
                 meta->className(), sig.constData(), findMethodCandidates(meta, member).constData());
        return false;
    }
    QMetaMethod method = meta->method(idx);
    // 最终, 还是要调用到 method 的 invoke 方法.
    // method invoke 方法, 会调用到每个类的 static_meta_call 方法.
    return method.invoke(obj, type, ret,
                         val0, val1, val2, val3, val4, val5, val6, val7, val8, val9);
}

QByteArray QMetaMethodPrivate::signature() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    QByteArray result;
    result.reserve(256);
    result += name();
    result += '(';
    QList<QByteArray> argTypes = parameterTypes();
    for (int i = 0; i < argTypes.size(); ++i) {
        if (i)
            result += ',';
        result += argTypes.at(i);
    }
    result += ')';
    return result;
}

QByteArray QMetaMethodPrivate::name() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return stringData(mobj, mobj->d.data[handle]);
}

int QMetaMethodPrivate::typesDataIndex() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return mobj->d.data[handle + 2];
}

const char *QMetaMethodPrivate::rawReturnTypeName() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    uint typeInfo = mobj->d.data[typesDataIndex()];
    if (typeInfo & IsUnresolvedType)
        return rawStringData(mobj, typeInfo & TypeNameIndexMask);
    else
        return QMetaType::typeName(typeInfo);
}

int QMetaMethodPrivate::returnType() const
{
    return parameterType(-1);
}

int QMetaMethodPrivate::parameterCount() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return mobj->d.data[handle + 1];
}

int QMetaMethodPrivate::parametersDataIndex() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return typesDataIndex() + 1;
}

uint QMetaMethodPrivate::parameterTypeInfo(int index) const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return mobj->d.data[parametersDataIndex() + index];
}

int QMetaMethodPrivate::parameterType(int index) const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return typeFromTypeInfo(mobj, parameterTypeInfo(index));
}

void QMetaMethodPrivate::getParameterTypes(int *types) const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    int dataIndex = parametersDataIndex();
    int argc = parameterCount();
    for (int i = 0; i < argc; ++i) {
        int id = typeFromTypeInfo(mobj, mobj->d.data[dataIndex++]);
        *(types++) = id;
    }
}

QList<QByteArray> QMetaMethodPrivate::parameterTypes() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    int argc = parameterCount();
    QList<QByteArray> list;
    list.reserve(argc);
    int paramsIndex = parametersDataIndex();
    for (int i = 0; i < argc; ++i)
        list += typeNameFromTypeInfo(mobj, mobj->d.data[paramsIndex + i]);
    return list;
}

QList<QByteArray> QMetaMethodPrivate::parameterNames() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    int argc = parameterCount();
    QList<QByteArray> list;
    list.reserve(argc);
    int namesIndex = parametersDataIndex() + argc;
    for (int i = 0; i < argc; ++i)
        list += stringData(mobj, mobj->d.data[namesIndex + i]);
    return list;
}

QByteArray QMetaMethodPrivate::tag() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return stringData(mobj, mobj->d.data[handle + 3]);
}

int QMetaMethodPrivate::ownMethodIndex() const
{
    // recompute the methodIndex by reversing the arithmetic in QMetaObject::property()
    return (handle - priv(mobj->d.data)->methodData) / 5;
}

QByteArray QMetaMethod::methodSignature() const
{
    if (!mobj)
        return QByteArray();
    return QMetaMethodPrivate::get(this)->signature();
}

QByteArray QMetaMethod::name() const
{
    if (!mobj)
        return QByteArray();
    return QMetaMethodPrivate::get(this)->name();
}

int QMetaMethod::returnType() const
 {
     if (!mobj)
         return QMetaType::UnknownType;
    return QMetaMethodPrivate::get(this)->returnType();
}

int QMetaMethod::parameterCount() const
{
    if (!mobj)
        return 0;
    return QMetaMethodPrivate::get(this)->parameterCount();
}

int QMetaMethod::parameterType(int index) const
{
    if (!mobj || index < 0)
        return QMetaType::UnknownType;
    if (index >= QMetaMethodPrivate::get(this)->parameterCount())
        return QMetaType::UnknownType;

    int type = QMetaMethodPrivate::get(this)->parameterType(index);
    if (type != QMetaType::UnknownType)
        return type;

    void *argv[] = { &type, &index };
    mobj->static_metacall(QMetaObject::RegisterMethodArgumentMetaType, QMetaMethodPrivate::get(this)->ownMethodIndex(), argv);
    if (type != -1)
        return type;
    return QMetaType::UnknownType;
}

void QMetaMethod::getParameterTypes(int *types) const
{
    if (!mobj)
        return;
    QMetaMethodPrivate::get(this)->getParameterTypes(types);
}

QList<QByteArray> QMetaMethod::parameterTypes() const
{
    if (!mobj)
        return QList<QByteArray>();
    return QMetaMethodPrivate::get(this)->parameterTypes();
}

QList<QByteArray> QMetaMethod::parameterNames() const
{
    QList<QByteArray> list;
    if (!mobj)
        return list;
    return QMetaMethodPrivate::get(this)->parameterNames();
}

const char *QMetaMethod::typeName() const
{
    if (!mobj)
        return 0;
    return QMetaMethodPrivate::get(this)->rawReturnTypeName();
}

const char *QMetaMethod::tag() const
{
    if (!mobj)
        return 0;
    return QMetaMethodPrivate::get(this)->tag().constData();
}

int QMetaMethod::attributes() const
{
    if (!mobj)
        return false;
    return ((mobj->d.data[handle + 4])>>4);
}

int QMetaMethod::methodIndex() const
{
    if (!mobj)
        return -1;
    return QMetaMethodPrivate::get(this)->ownMethodIndex() + mobj->methodOffset();
}

int QMetaMethod::revision() const
{
    if (!mobj)
        return 0;
    if ((QMetaMethod::Access)(mobj->d.data[handle + 4] & MethodRevisioned)) {
        int offset = priv(mobj->d.data)->methodData
                     + priv(mobj->d.data)->methodCount * 5
                     + QMetaMethodPrivate::get(this)->ownMethodIndex();
        return mobj->d.data[offset];
    }
    return 0;
}

QMetaMethod::Access QMetaMethod::access() const
{
    if (!mobj)
        return Private;
    return (QMetaMethod::Access)(mobj->d.data[handle + 4] & AccessMask);
}

QMetaMethod::MethodType QMetaMethod::methodType() const
{
    if (!mobj)
        return QMetaMethod::Method;
    return (QMetaMethod::MethodType)((mobj->d.data[handle + 4] & MethodTypeMask)>>2);
}

QMetaMethod QMetaMethod::fromSignalImpl(const QMetaObject *metaObject, void **signal)
{
    int i = -1;
    void *args[] = { &i, signal };
    QMetaMethod result;
    for (const QMetaObject *m = metaObject; m; m = m->d.superdata) {
        m->static_metacall(QMetaObject::IndexOfMethod, 0, args);
        if (i >= 0) {
            result.mobj = m;
            result.handle = priv(m->d.data)->methodData + 5*i;
            break;
        }
    }
    return result;
}

//
bool QMetaMethod::invoke(QObject *object,
                         Qt::ConnectionType connectionType,
                         QGenericReturnArgument returnValue,
                         QGenericArgument val0,
                         QGenericArgument val1,
                         QGenericArgument val2,
                         QGenericArgument val3,
                         QGenericArgument val4,
                         QGenericArgument val5,
                         QGenericArgument val6,
                         QGenericArgument val7,
                         QGenericArgument val8,
                         QGenericArgument val9) const
{
    if (!object || !mobj)
        return false;


    if (returnValue.data()) {
        const char *retType = typeName();
        if (qstrcmp(returnValue.name(), retType) != 0) {
            // normalize the return value as well
            QByteArray normalized = QMetaObject::normalizedType(returnValue.name());
            if (qstrcmp(normalized.constData(), retType) != 0) {
                // String comparison failed, try compare the metatype.
                int t = returnType();
                if (t == QMetaType::UnknownType || t != QMetaType::type(normalized))
                    return false;
            }
        }
    }

    // check argument count (we don't allow invoking a method if given too few arguments)
    const char *typeNames[] = {
        returnValue.name(),
        val0.name(),
        val1.name(),
        val2.name(),
        val3.name(),
        val4.name(),
        val5.name(),
        val6.name(),
        val7.name(),
        val8.name(),
        val9.name()
    };
    int paramCount;
    for (paramCount = 1; paramCount < MaximumParamCount; ++paramCount) {
        if (qstrlen(typeNames[paramCount]) <= 0)
            break;
    }
    if (paramCount <= QMetaMethodPrivate::get(this)->parameterCount())
        return false;

    // 在这里, 有着线程的控制. 如果, 如果, 目标不在当前线程的话, 就会异步调用.
    QThread *currentThread = QThread::currentThread();
    QThread *objectThread = object->thread();
    if (connectionType == Qt::AutoConnection) {
        connectionType = currentThread == objectThread
                         ? Qt::DirectConnection
                         : Qt::QueuedConnection;
    }

    if (connectionType == Qt::BlockingQueuedConnection) {
        connectionType = Qt::DirectConnection;
    }

    // invoke!
    void *param[] = {
        returnValue.data(),
        val0.data(),
        val1.data(),
        val2.data(),
        val3.data(),
        val4.data(),
        val5.data(),
        val6.data(),
        val7.data(),
        val8.data(),
        val9.data()
    };
    int idx_relative = QMetaMethodPrivate::get(this)->ownMethodIndex();
    int idx_offset =  mobj->methodOffset();
    QObjectPrivate::StaticMetaCallFunction callFunction = mobj->d.static_metacall;

    if (connectionType == Qt::DirectConnection) {
        // 同步调用.
        if (callFunction) {
            callFunction(object, QMetaObject::InvokeMetaMethod, idx_relative, param);
            return true;
        } else {
            return QMetaObject::metacall(object, QMetaObject::InvokeMetaMethod, idx_relative + idx_offset, param) < 0;
        }
    } else if (connectionType == Qt::QueuedConnection) {
        // 异步调用, returnValue 没用.
        if (returnValue.data()) {
            qWarning("QMetaMethod::invoke: Unable to invoke methods with return values in "
                     "queued connections");
            return false;
        }

        int nargs = 1; // include return type
        void **args = (void **) malloc(paramCount * sizeof(void *));
        Q_CHECK_PTR(args);
        int *types = (int *) malloc(paramCount * sizeof(int));
        Q_CHECK_PTR(types);
        types[0] = 0; // return type
        args[0] = 0;

        for (int i = 1; i < paramCount; ++i) {
            types[i] = QMetaType::type(typeNames[i]);
            if (types[i] == QMetaType::UnknownType && param[i]) {
                int index = nargs - 1;
                void *argv[] = { &types[i], &index };
                QMetaObject::metacall(object, QMetaObject::RegisterMethodArgumentMetaType,
                                      idx_relative + idx_offset, argv);
                if (types[i] == -1) {
                    for (int x = 1; x < i; ++x) {
                        if (types[x] && args[x])
                            QMetaType::destroy(types[x], args[x]);
                    }
                    free(types);
                    free(args);
                    return false;
                }
            }
            // 这里, 会将所有参数复制一遍.
            // 所以, 这些参数的类型, 要有拷贝构造函数, 这也就是 Qt 为什么会对类型有要求的原因. 某些时候, 必须调用拷贝构造函数的.
            if (types[i] != QMetaType::UnknownType) {
                args[i] = QMetaType::create(types[i], param[i]);
                ++nargs;
            }
        }
        
        // 然后, 将方法调用, 包装成为一个事件, 通过 QCoreApplication 通过 PostEvent, 将这个事件, 交给目标所在现成的 waitingEvents 里面.
        QCoreApplication::postEvent(object, new QMetaCallEvent(idx_offset, idx_relative, callFunction,
                                                        0, -1, nargs, types, args));
    } else { // blocking queued connection
        // 如果, 需要 Block 当前线程, 就使用信号量进行 wait 就可以了.
        QSemaphore semaphore;
        QCoreApplication::postEvent(object, new QMetaCallEvent(idx_offset, idx_relative, callFunction,
                                                        0, -1, 0, 0, param, &semaphore));
        semaphore.acquire();
    }
    return true;
}

const char *QMetaEnum::name() const
{
    if (!mobj)
        return 0;
    return rawStringData(mobj, mobj->d.data[handle]);
}

int QMetaEnum::keyCount() const
{
    if (!mobj)
        return 0;
    return mobj->d.data[handle + 2];
}

const char *QMetaEnum::key(int index) const
{
    if (!mobj)
        return 0;
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    if (index >= 0  && index < count)
        return rawStringData(mobj, mobj->d.data[data + 2*index]);
    return 0;
}

int QMetaEnum::value(int index) const
{
    if (!mobj)
        return 0;
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    if (index >= 0  && index < count)
        return mobj->d.data[data + 2*index + 1];
    return -1;
}


bool QMetaEnum::isFlag() const
{
    return mobj && mobj->d.data[handle + 1] & EnumIsFlag;
}

bool QMetaEnum::isScoped() const
{
    return mobj && mobj->d.data[handle + 1] & EnumIsScoped;
}

const char *QMetaEnum::scope() const
{
    return mobj ? objectClassName(mobj) : 0;
}

int QMetaEnum::keyToValue(const char *key, bool *ok) const
{
    if (ok != 0)
        *ok = false;
    if (!mobj || !key)
        return -1;
    uint scope = 0;
    const char *qualified_key = key;
    const char *s = key + qstrlen(key);
    while (s > key && *s != ':')
        --s;
    if (s > key && *(s-1)==':') {
        scope = s - key - 1;
        key += scope + 2;
    }
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    for (int i = 0; i < count; ++i) {
        const QByteArray className = stringData(mobj, priv(mobj->d.data)->className);
        if ((!scope || (className.size() == int(scope) && strncmp(qualified_key, className.constData(), scope) == 0))
             && strcmp(key, rawStringData(mobj, mobj->d.data[data + 2*i])) == 0) {
            if (ok != 0)
                *ok = true;
            return mobj->d.data[data + 2*i + 1];
        }
    }
    return -1;
}

/*!
    Returns the string that is used as the name of the given
    enumeration \a value, or 0 if \a value is not defined.

    For flag types, use valueToKeys().

    \sa isFlag(), valueToKeys()
*/
const char* QMetaEnum::valueToKey(int value) const
{
    if (!mobj)
        return 0;
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    for (int i = 0; i < count; ++i)
        if (value == (int)mobj->d.data[data + 2*i + 1])
            return rawStringData(mobj, mobj->d.data[data + 2*i]);
    return 0;
}

/*!
    Returns the value derived from combining together the values of
    the \a keys using the OR operator, or -1 if \a keys is not
    defined. Note that the strings in \a keys must be '|'-separated.

    If \a keys is not defined, *\a{ok} is set to false; otherwise
    *\a{ok} is set to true.

    \sa isFlag(), valueToKey(), valueToKeys()
*/
int QMetaEnum::keysToValue(const char *keys, bool *ok) const
{
    if (ok != 0)
        *ok = false;
    if (!mobj || !keys)
        return -1;
    if (ok != 0)
        *ok = true;
    const QString keysString = QString::fromLatin1(keys);
    const QVector<QStringRef> splitKeys = keysString.splitRef(QLatin1Char('|'));
    if (splitKeys.isEmpty())
        return 0;
    // ### TODO write proper code: do not allocate memory, so we can go nothrow
    int value = 0;
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    for (const QStringRef &untrimmed : splitKeys) {
        const QStringRef trimmed = untrimmed.trimmed();
        QByteArray qualified_key = trimmed.toLatin1();
        const char *key = qualified_key.constData();
        uint scope = 0;
        const char *s = key + qstrlen(key);
        while (s > key && *s != ':')
            --s;
        if (s > key && *(s-1)==':') {
            scope = s - key - 1;
            key += scope + 2;
        }
        int i;
        for (i = count-1; i >= 0; --i) {
            const QByteArray className = stringData(mobj, priv(mobj->d.data)->className);
            if ((!scope || (className.size() == int(scope) && strncmp(qualified_key.constData(), className.constData(), scope) == 0))
                 && strcmp(key, rawStringData(mobj, mobj->d.data[data + 2*i])) == 0) {
                value |= mobj->d.data[data + 2*i + 1];
                break;
            }
        }
        if (i < 0) {
            if (ok != 0)
                *ok = false;
            value |= -1;
        }
    }
    return value;
}

/*!
    Returns a byte array of '|'-separated keys that represents the
    given \a value.

    \sa isFlag(), valueToKey(), keysToValue()
*/
QByteArray QMetaEnum::valueToKeys(int value) const
{
    QByteArray keys;
    if (!mobj)
        return keys;
    int count = mobj->d.data[handle + 2];
    int data = mobj->d.data[handle + 3];
    int v = value;
    // reverse iterate to ensure values like Qt::Dialog=0x2|Qt::Window are processed first.
    for (int i = count - 1; i >= 0; --i) {
        int k = mobj->d.data[data + 2*i + 1];
        if ((k != 0 && (v & k) == k ) ||  (k == value))  {
            v = v & ~k;
            if (!keys.isEmpty())
                keys.prepend('|');
            keys.prepend(stringData(mobj, mobj->d.data[data + 2*i]));
        }
    }
    return keys;
}

/*!
    \fn QMetaEnum QMetaEnum::fromType()
    \since 5.5

    Returns the QMetaEnum corresponding to the type in the template parameter.
    The enum needs to be declared with Q_ENUM.
*/

static QByteArray qualifiedName(const QMetaEnum &e)
{
    return QByteArray(e.scope()) + "::" + e.name();
}

QMetaProperty::QMetaProperty()
    : mobj(0), handle(0), idx(0)
{
}


/*!
    Returns this property's name.

    \sa type(), typeName()
*/
const char *QMetaProperty::name() const
{
    if (!mobj)
        return 0;
    int handle = priv(mobj->d.data)->propertyData + 3*idx;
    return rawStringData(mobj, mobj->d.data[handle]);
}

/*!
    Returns the name of this property's type.

    \sa type(), name()
*/
const char *QMetaProperty::typeName() const
{
    if (!mobj)
        return 0;
    int handle = priv(mobj->d.data)->propertyData + 3*idx;
    return rawTypeNameFromTypeInfo(mobj, mobj->d.data[handle + 1]);
}

/*!
    Returns this property's type. The return value is one
    of the values of the QVariant::Type enumeration.

    \sa userType(), typeName(), name()
*/
QVariant::Type QMetaProperty::type() const
{
    if (!mobj)
        return QVariant::Invalid;
    int handle = priv(mobj->d.data)->propertyData + 3*idx;

    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    uint type = typeFromTypeInfo(mobj, mobj->d.data[handle + 1]);
    if (type >= QMetaType::User)
        return QVariant::UserType;
    if (type != QMetaType::UnknownType)
        return QVariant::Type(type);
    if (isEnumType()) {
        int enumMetaTypeId = QMetaType::type(qualifiedName(menum));
        if (enumMetaTypeId == QMetaType::UnknownType)
            return QVariant::Int;
    }
#ifdef QT_COORD_TYPE
    // qreal metatype must be resolved at runtime.
    if (strcmp(typeName(), "qreal") == 0)
        return QVariant::Type(qMetaTypeId<qreal>());
#endif

    return QVariant::UserType;
}

/*!
    \since 4.2

    Returns this property's user type. The return value is one
    of the values that are registered with QMetaType, or QMetaType::UnknownType if
    the type is not registered.

    \sa type(), QMetaType, typeName()
 */
int QMetaProperty::userType() const
{
    if (!mobj)
        return QMetaType::UnknownType;
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    int handle = priv(mobj->d.data)->propertyData + 3*idx;
    int type = typeFromTypeInfo(mobj, mobj->d.data[handle + 1]);
    if (type != QMetaType::UnknownType)
        return type;
    if (isEnumType()) {
        type = QMetaType::type(qualifiedName(menum));
        if (type == QMetaType::UnknownType) {
            type = registerPropertyType();
            if (type == QMetaType::UnknownType)
                return QVariant::Int; // Match behavior of QMetaType::type()
        }
        return type;
    }
    type = QMetaType::type(typeName());
    if (type != QMetaType::UnknownType)
        return type;
    return registerPropertyType();
}

/*!
  \since 4.6

  Returns this property's index.
*/
int QMetaProperty::propertyIndex() const
{
    if (!mobj)
        return -1;
    return idx + mobj->propertyOffset();
}

/*!
    Returns \c true if the property's type is an enumeration value that
    is used as a flag; otherwise returns \c false.

    Flags can be combined using the OR operator. A flag type is
    implicitly also an enum type.

    \sa isEnumType(), enumerator(), QMetaEnum::isFlag()
*/

bool QMetaProperty::isFlagType() const
{
    return isEnumType() && menum.isFlag();
}

/*!
    Returns \c true if the property's type is an enumeration value;
    otherwise returns \c false.

    \sa enumerator(), isFlagType()
*/
bool QMetaProperty::isEnumType() const
{
    if (!mobj)
        return false;
    int handle = priv(mobj->d.data)->propertyData + 3*idx;
    int flags = mobj->d.data[handle + 2];
    return (flags & EnumOrFlag) && menum.name();
}

/*!
    \internal

    Returns \c true if the property has a C++ setter function that
    follows Qt's standard "name" / "setName" pattern. Designer and uic
    query hasStdCppSet() in order to avoid expensive
    QObject::setProperty() calls. All properties in Qt [should] follow
    this pattern.
*/
bool QMetaProperty::hasStdCppSet() const
{
    if (!mobj)
        return false;
    int handle = priv(mobj->d.data)->propertyData + 3*idx;
    int flags = mobj->d.data[handle + 2];
    return (flags & StdCppSet);
}

/*!
    \internal
    Executes metacall with QMetaObject::RegisterPropertyMetaType flag.
    Returns id of registered type or QMetaType::UnknownType if a type
    could not be registered for any reason.
*/
int QMetaProperty::registerPropertyType() const
{
    int registerResult = -1;
    void *argv[] = { &registerResult };
    mobj->static_metacall(QMetaObject::RegisterPropertyMetaType, idx, argv);
    return registerResult == -1 ? QMetaType::UnknownType : registerResult;
}

/*!
    Returns the enumerator if this property's type is an enumerator
    type; otherwise the returned value is undefined.

    \sa isEnumType(), isFlagType()
*/
QMetaEnum QMetaProperty::enumerator() const
{
    return menum;
}

QVariant QMetaProperty::read(const QObject *object) const
{
    if (!object || !mobj)
        return QVariant();

    uint t = QVariant::Int;
    if (isEnumType()) {
        int enumMetaTypeId = QMetaType::type(qualifiedName(menum));
        if (enumMetaTypeId != QMetaType::UnknownType)
            t = enumMetaTypeId;
    } else {
        int handle = priv(mobj->d.data)->propertyData + 3*idx;
        const char *typeName = 0;
        Q_ASSERT(priv(mobj->d.data)->revision >= 7);
        uint typeInfo = mobj->d.data[handle + 1];
        if (!(typeInfo & IsUnresolvedType))
            t = typeInfo;
        else {
            typeName = rawStringData(mobj, typeInfo & TypeNameIndexMask);
            t = QMetaType::type(typeName);
        }
        if (t == QMetaType::UnknownType) {
            // Try to register the type and try again before reporting an error.
            t = registerPropertyType();
            if (t == QMetaType::UnknownType) {
                qWarning("QMetaProperty::read: Unable to handle unregistered datatype '%s' for property '%s::%s'", typeName, mobj->className(), name());
                return QVariant();
            }
        }
    }

    // the status variable is changed by qt_metacall to indicate what it did
    // this feature is currently only used by Qt D-Bus and should not be depended
    // upon. Don't change it without looking into QDBusAbstractInterface first
    // -1 (unchanged): normal qt_metacall, result stored in argv[0]
    // changed: result stored directly in value
    int status = -1;
    QVariant value;
    void *argv[] = { 0, &value, &status };
    if (t == QMetaType::QVariant) {
        argv[0] = &value;
    } else {
        value = QVariant(t, (void*)0);
        argv[0] = value.data();
    }
    // 最终, Property 的 get, 是要到 static_metacall 中执行.
    if (priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall) {
        mobj->d.static_metacall(const_cast<QObject*>(object), QMetaObject::ReadProperty, idx, argv);
    } else {
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::ReadProperty,
                              idx + mobj->propertyOffset(), argv);
    }

    if (status != -1)
        return value;
    if (t != QMetaType::QVariant && argv[0] != value.data())
        // pointer or reference
        return QVariant((QVariant::Type)t, argv[0]);
    return value;
}

/*!
    Writes \a value as the property's value to the given \a object. Returns
    true if the write succeeded; otherwise returns \c false.

    If \a value is not of the same type type as the property, a conversion
    is attempted. An empty QVariant() is equivalent to a call to reset()
    if this property is resetable, or setting a default-constructed object
    otherwise.

    \sa read(), reset(), isWritable()
*/
bool QMetaProperty::write(QObject *object, const QVariant &value) const
{
    if (!object || !isWritable())
        return false;

    QVariant v = value;
    uint t = QVariant::Invalid;
    if (isEnumType()) {
        if (v.type() == QVariant::String) {
            bool ok;
            if (isFlagType())
                v = QVariant(menum.keysToValue(value.toByteArray(), &ok));
            else
                v = QVariant(menum.keyToValue(value.toByteArray(), &ok));
            if (!ok)
                return false;
        } else if (v.type() != QVariant::Int && v.type() != QVariant::UInt) {
            int enumMetaTypeId = QMetaType::type(qualifiedName(menum));
            if ((enumMetaTypeId == QMetaType::UnknownType) || (v.userType() != enumMetaTypeId) || !v.constData())
                return false;
            v = QVariant(*reinterpret_cast<const int *>(v.constData()));
        }
        v.convert(QVariant::Int);
    } else {
        int handle = priv(mobj->d.data)->propertyData + 3*idx;
        const char *typeName = 0;
        Q_ASSERT(priv(mobj->d.data)->revision >= 7);
        uint typeInfo = mobj->d.data[handle + 1];
        if (!(typeInfo & IsUnresolvedType))
            t = typeInfo;
        else {
            typeName = rawStringData(mobj, typeInfo & TypeNameIndexMask);
            t = QMetaType::type(typeName);
            if (t == QMetaType::UnknownType)
                t = registerPropertyType();
            if (t == QMetaType::UnknownType)
                return false;
        }
        if (t != QMetaType::QVariant && int(t) != value.userType()) {
            if (!value.isValid()) {
                if (isResettable())
                    return reset(object);
                v = QVariant(t, 0);
            } else if (!v.convert(t)) {
                return false;
            }
        }
    }

    // the status variable is changed by qt_metacall to indicate what it did
    // this feature is currently only used by Qt D-Bus and should not be depended
    // upon. Don't change it without looking into QDBusAbstractInterface first
    // -1 (unchanged): normal qt_metacall, result stored in argv[0]
    // changed: result stored directly in value, return the value of status
    int status = -1;
    // the flags variable is used by the declarative module to implement
    // interception of property writes.
    int flags = 0;
    void *argv[] = { 0, &v, &status, &flags };
    if (t == QMetaType::QVariant)
        argv[0] = &v;
    else
        argv[0] = v.data();
    if (priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall)
        mobj->d.static_metacall(object, QMetaObject::WriteProperty, idx, argv);
    else
        QMetaObject::metacall(object, QMetaObject::WriteProperty, idx + mobj->propertyOffset(), argv);

    return status;
}

/*!
    Resets the property for the given \a object with a reset method.
    Returns \c true if the reset worked; otherwise returns \c false.

    Reset methods are optional; only a few properties support them.

    \sa read(), write()
*/
bool QMetaProperty::reset(QObject *object) const
{
    if (!object || !mobj || !isResettable())
        return false;
    void *argv[] = { 0 };
    if (priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall)
        mobj->d.static_metacall(object, QMetaObject::ResetProperty, idx, argv);
    else
        QMetaObject::metacall(object, QMetaObject::ResetProperty, idx + mobj->propertyOffset(), argv);
    return true;
}
/*!
    \since 5.5

    Reads the property's value from the given \a gadget. Returns the value
    if it was able to read it; otherwise returns an invalid variant.

    This function should only be used if this is a property of a Q_GADGET
*/
QVariant QMetaProperty::readOnGadget(const void *gadget) const
{
    Q_ASSERT(priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall);
    return read(reinterpret_cast<const QObject*>(gadget));
}

/*!
    \since 5.5

    Writes \a value as the property's value to the given \a gadget. Returns
    true if the write succeeded; otherwise returns \c false.

    This function should only be used if this is a property of a Q_GADGET
*/
bool QMetaProperty::writeOnGadget(void *gadget, const QVariant &value) const
{
    Q_ASSERT(priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall);
    return write(reinterpret_cast<QObject*>(gadget), value);
}

/*!
    \since 5.5

    Resets the property for the given \a gadget with a reset method.
    Returns \c true if the reset worked; otherwise returns \c false.

    Reset methods are optional; only a few properties support them.

    This function should only be used if this is a property of a Q_GADGET
*/
bool QMetaProperty::resetOnGadget(void *gadget) const
{
    Q_ASSERT(priv(mobj->d.data)->flags & PropertyAccessInStaticMetaCall && mobj->d.static_metacall);
    return reset(reinterpret_cast<QObject*>(gadget));
}

/*!
    Returns \c true if this property can be reset to a default value; otherwise
    returns \c false.

    \sa reset()
*/
bool QMetaProperty::isResettable() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Resettable;
}

/*!
    Returns \c true if this property is readable; otherwise returns \c false.

    \sa isWritable(), read(), isValid()
 */
bool QMetaProperty::isReadable() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Readable;
}

/*!
    Returns \c true if this property has a corresponding change notify signal;
    otherwise returns \c false.

    \sa notifySignal()
 */
bool QMetaProperty::hasNotifySignal() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Notify;
}

/*!
    \since 4.5

    Returns the QMetaMethod instance of the property change notifying signal if
    one was specified, otherwise returns an invalid QMetaMethod.

    \sa hasNotifySignal()
 */
QMetaMethod QMetaProperty::notifySignal() const
{
    int id = notifySignalIndex();
    if (id != -1)
        return mobj->method(id);
    else
        return QMetaMethod();
}

/*!
    \since 4.6

    Returns the index of the property change notifying signal if one was
    specified, otherwise returns -1.

    \sa hasNotifySignal()
 */
int QMetaProperty::notifySignalIndex() const
{
    if (hasNotifySignal()) {
        int offset = priv(mobj->d.data)->propertyData +
                     priv(mobj->d.data)->propertyCount * 3 + idx;
        return mobj->d.data[offset] + mobj->methodOffset();
    } else {
        return -1;
    }
}

// This method has been around for a while, but the documentation was marked \internal until 5.1
/*!
    \since 5.1

    Returns the property revision if one was
    specified by REVISION, otherwise returns 0.
 */
int QMetaProperty::revision() const
{
    if (!mobj)
        return 0;
    int flags = mobj->d.data[handle + 2];
    if (flags & Revisioned) {
        int offset = priv(mobj->d.data)->propertyData +
                     priv(mobj->d.data)->propertyCount * 3 + idx;
        // Revision data is placed after NOTIFY data, if present.
        // Iterate through properties to discover whether we have NOTIFY signals.
        for (int i = 0; i < priv(mobj->d.data)->propertyCount; ++i) {
            int handle = priv(mobj->d.data)->propertyData + 3*i;
            if (mobj->d.data[handle + 2] & Notify) {
                offset += priv(mobj->d.data)->propertyCount;
                break;
            }
        }
        return mobj->d.data[offset];
    } else {
        return 0;
    }
}

/*!
    Returns \c true if this property is writable; otherwise returns
    false.

    \sa isReadable(), write()
 */
bool QMetaProperty::isWritable() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Writable;
}


/*!
    Returns \c true if this property is designable for the given \a object;
    otherwise returns \c false.

    If no \a object is given, the function returns \c false if the
    \c{Q_PROPERTY()}'s \c DESIGNABLE attribute is false; otherwise
    returns \c true (if the attribute is true or is a function or expression).

    \sa isScriptable(), isStored()
*/
bool QMetaProperty::isDesignable(const QObject *object) const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    bool b = flags & Designable;
    if (object) {
        void *argv[] = { &b };
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::QueryPropertyDesignable,
                              idx + mobj->propertyOffset(), argv);
    }
    return b;


}

/*!
    Returns \c true if the property is scriptable for the given \a object;
    otherwise returns \c false.

    If no \a object is given, the function returns \c false if the
    \c{Q_PROPERTY()}'s \c SCRIPTABLE attribute is false; otherwise returns
    true (if the attribute is true or is a function or expression).

    \sa isDesignable(), isStored()
*/
bool QMetaProperty::isScriptable(const QObject *object) const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    bool b = flags & Scriptable;
    if (object) {
        void *argv[] = { &b };
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::QueryPropertyScriptable,
                              idx + mobj->propertyOffset(), argv);
    }
    return b;
}

/*!
    Returns \c true if the property is stored for \a object; otherwise returns
    false.

    If no \a object is given, the function returns \c false if the
    \c{Q_PROPERTY()}'s \c STORED attribute is false; otherwise returns
    true (if the attribute is true or is a function or expression).

    \sa isDesignable(), isScriptable()
*/
bool QMetaProperty::isStored(const QObject *object) const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    bool b = flags & Stored;
    if (object) {
        void *argv[] = { &b };
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::QueryPropertyStored,
                              idx + mobj->propertyOffset(), argv);
    }
    return b;
}

/*!
    Returns \c true if this property is designated as the \c USER
    property, i.e., the one that the user can edit for \a object or
    that is significant in some other way.  Otherwise it returns
    false. e.g., the \c text property is the \c USER editable property
    of a QLineEdit.

    If \a object is null, the function returns \c false if the \c
    {Q_PROPERTY()}'s \c USER attribute is false. Otherwise it returns
    true.

    \sa QMetaObject::userProperty(), isDesignable(), isScriptable()
*/
bool QMetaProperty::isUser(const QObject *object) const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    bool b = flags & User;
    if (object) {
        void *argv[] = { &b };
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::QueryPropertyUser,
                              idx + mobj->propertyOffset(), argv);
    }
    return b;
}

/*!
    \since 4.6
    Returns \c true if the property is constant; otherwise returns \c false.

    A property is constant if the \c{Q_PROPERTY()}'s \c CONSTANT attribute
    is set.
*/
bool QMetaProperty::isConstant() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Constant;
}

/*!
    \since 4.6
    Returns \c true if the property is final; otherwise returns \c false.

    A property is final if the \c{Q_PROPERTY()}'s \c FINAL attribute
    is set.
*/
bool QMetaProperty::isFinal() const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    return flags & Final;
}

/*!
    \obsolete

    Returns \c true if the property is editable for the given \a object;
    otherwise returns \c false.

    If no \a object is given, the function returns \c false if the
    \c{Q_PROPERTY()}'s \c EDITABLE attribute is false; otherwise returns
    true (if the attribute is true or is a function or expression).

    \sa isDesignable(), isScriptable(), isStored()
*/
bool QMetaProperty::isEditable(const QObject *object) const
{
    if (!mobj)
        return false;
    int flags = mobj->d.data[handle + 2];
    bool b = flags & Editable;
    if (object) {
        void *argv[] = { &b };
        QMetaObject::metacall(const_cast<QObject*>(object), QMetaObject::QueryPropertyEditable,
                              idx + mobj->propertyOffset(), argv);
    }
    return b;
}

/*!
    \class QMetaClassInfo
    \inmodule QtCore

    \brief The QMetaClassInfo class provides additional information
    about a class.

    \ingroup objectmodel

    Class information items are simple \e{name}--\e{value} pairs that
    are specified using Q_CLASSINFO() in the source code. The
    information can be retrieved using name() and value(). For example:

    \snippet code/src_corelib_kernel_qmetaobject.cpp 5

    This mechanism is free for you to use in your Qt applications. Qt
    doesn't use it for any of its classes.

    \sa QMetaObject
*/


/*!
    \fn QMetaClassInfo::QMetaClassInfo()
    \internal
*/

/*!
    \fn const QMetaObject *QMetaClassInfo::enclosingMetaObject() const
    \internal
*/

/*!
    Returns the name of this item.

    \sa value()
*/
const char *QMetaClassInfo::name() const
{
    if (!mobj)
        return 0;
    return rawStringData(mobj, mobj->d.data[handle]);
}

/*!
    Returns the value of this item.

    \sa name()
*/
const char* QMetaClassInfo::value() const
{
    if (!mobj)
        return 0;
    return rawStringData(mobj, mobj->d.data[handle + 1]);
}

/*!
    \macro QGenericArgument Q_ARG(Type, const Type &value)
    \relates QMetaObject

    This macro takes a \a Type and a \a value of that type and
    returns a \l QGenericArgument object that can be passed to
    QMetaObject::invokeMethod().

    \sa Q_RETURN_ARG()
*/

/*!
    \macro QGenericReturnArgument Q_RETURN_ARG(Type, Type &value)
    \relates QMetaObject

    This macro takes a \a Type and a non-const reference to a \a
    value of that type and returns a QGenericReturnArgument object
    that can be passed to QMetaObject::invokeMethod().

    \sa Q_ARG()
*/

/*!
    \class QGenericArgument
    \inmodule QtCore

    \brief The QGenericArgument class is an internal helper class for
    marshalling arguments.

    This class should never be used directly. Please use the \l Q_ARG()
    macro instead.

    \sa Q_ARG(), QMetaObject::invokeMethod(), QGenericReturnArgument
*/

/*!
    \fn QGenericArgument::QGenericArgument(const char *name, const void *data)

    Constructs a QGenericArgument object with the given \a name and \a data.
*/

/*!
    \fn QGenericArgument::data () const

    Returns the data set in the constructor.
*/

/*!
    \fn QGenericArgument::name () const

    Returns the name set in the constructor.
*/

/*!
    \class QGenericReturnArgument
    \inmodule QtCore

    \brief The QGenericReturnArgument class is an internal helper class for
    marshalling arguments.

    This class should never be used directly. Please use the
    Q_RETURN_ARG() macro instead.

    \sa Q_RETURN_ARG(), QMetaObject::invokeMethod(), QGenericArgument
*/

/*!
    \fn QGenericReturnArgument::QGenericReturnArgument(const char *name, void *data)

    Constructs a QGenericReturnArgument object with the given \a name
    and \a data.
*/

/*!
    \internal
    If the local_method_index is a cloned method, return the index of the original.

    Example: if the index of "destroyed()" is passed, the index of "destroyed(QObject*)" is returned
 */
int QMetaObjectPrivate::originalClone(const QMetaObject *mobj, int local_method_index)
{
    Q_ASSERT(local_method_index < get(mobj)->methodCount);
    int handle = get(mobj)->methodData + 5 * local_method_index;
    while (mobj->d.data[handle + 4] & MethodCloned) {
        Q_ASSERT(local_method_index > 0);
        handle -= 5;
        local_method_index--;
    }
    return local_method_index;
}

/*!
    \internal

    Returns the parameter type names extracted from the given \a signature.
*/
QList<QByteArray> QMetaObjectPrivate::parameterTypeNamesFromSignature(const char *signature)
{
    QList<QByteArray> list;
    while (*signature && *signature != '(')
        ++signature;
    while (*signature && *signature != ')' && *++signature != ')') {
        const char *begin = signature;
        int level = 0;
        while (*signature && (level > 0 || *signature != ',') && *signature != ')') {
            if (*signature == '<')
                ++level;
            else if (*signature == '>')
                --level;
            ++signature;
        }
        list += QByteArray(begin, signature - begin);
    }
    return list;
}

QT_END_NAMESPACE
