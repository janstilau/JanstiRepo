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

#include "private/qobject_p.h"
#include "private/qmetaobject_p.h"

// for normalizeTypeInternal
#include "private/qmetaobject_moc_p.h"

#include <ctype.h>

QT_BEGIN_NAMESPACE

// 使用这个函数, 将一个不透明函数, 转化成为固定的类型.
static inline const QMetaObjectPrivate *priv(const uint* data)
{ return reinterpret_cast<const QMetaObjectPrivate*>(data); }

static inline const QByteArray stringData(const QMetaObject *mo, int index)
{
    Q_ASSERT(priv(mo->d.data)->revision >= 7);
    const QByteArrayDataPtr data = { const_cast<QByteArrayData*>(&mo->d.stringdata[index]) };
    Q_ASSERT(data.ptr->ref.isStatic());
    Q_ASSERT(data.ptr->alloc == 0);
    Q_ASSERT(data.ptr->capacityReserved == 0);
    Q_ASSERT(data.ptr->size >= 0);
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
            constructorName.remove(0, idx+1); // remove qualified part
    }
    // 首选, 根据 className, 得到构造函数的信息.

    QVarLengthArray<char, 512> sig;
    sig.append(constructorName.constData(), constructorName.length());
    sig.append('(');
    enum { MaximumParamCount = 10 };
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

    // 拿到构造函数的签名之后, 去获取注册的构造函数的信息.
    int idx = indexOfConstructor(sig.constData());
    if (idx < 0) {
        QByteArray norm = QMetaObject::normalizedSignature(sig.constData());
        idx = indexOfConstructor(norm.constData());
    }
    if (idx < 0)
        return 0;

    QObject *returnValue = 0;
    void *param[] = {&returnValue, val0.data(), val1.data(), val2.data(), val3.data(), val4.data(),
                     val5.data(), val6.data(), val7.data(), val8.data(), val9.data()};

    // 可以看到, 最终还是调用到了 qt_static_metacall, 这个方法, 这个方法会到各个类自己的 qt_static_metacall 中,
    // 作为 c++ 的构造方法, 会使用一个 placeHolder init 的方式. 也就是在指定的地方, 进行对象的初始化, 也即是, 调用者应该保证传入的 returnPointer 指向一个合法的值.
    if (static_metacall(CreateInstance, idx, param) >= 0)
        return 0;
    return returnValue;
}
/*
MyProcesser 生成的 MOC 文件里面, 对于构造方法的实现.
void MyProcesser::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::CreateInstance) {
        switch (_id) {
        case 0: { MyProcesser *_r = new MyProcesser((*reinterpret_cast< int(*)>(_a[1])));
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = _r; } break;
        default: break;
        }
    } else if (_c == QMetaObject::InvokeMetaMethod) {
}
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
        // 这里, 不太明白, 对象级别上的 qt_metacall 的意义在哪里.
        return object->qt_metacall(cl, idx, argv);
}

static inline const char *objectClassName(const QMetaObject *m)
{
    return rawStringData(m, priv(m->d.data)->className);
}

// 在 Moc 编译之后, 已经硬编码在了 Moc.cpp 文件里面.
const char *QMetaObject::className() const
{

    return objectClassName(this);
}

// 可以看到, 这里, 和 iOS 里面很类似, 都是由一个 super 指针, 进行相应的判断.
bool QMetaObject::inherits(const QMetaObject *metaObject) const Q_DECL_NOEXCEPT
{
    const QMetaObject *m = this;
    do {
        if (metaObject == m)
            return true;
    } while ((m = m->d.superdata));
    return false;
}

// 这里, 没有使用 dynamicCast, 而是使用了 qt 的逻辑.
const QObject *QMetaObject::cast(const QObject *obj) const
{
    return (obj && obj->metaObject()->inherits(this)) ? obj : nullptr;
}

#ifndef QT_NO_TRANSLATION
/*!
    \internal
*/
QString QMetaObject::tr(const char *s, const char *c, int n) const
{
    // 这里就是为什么类里面翻译, 会直接到相应的 scope 的原因.
    return QCoreApplication::translate(objectClassName(this), s, c, n);
}
#endif // QT_NO_TRANSLATION

// 这个值是计算出来的.
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

/*!
    Returns the number of enumerators in this class.

    \sa enumerator(), enumeratorOffset(), indexOfEnumerator()
*/
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

// Returns \c true if the method defined by the given meta-object&handle
// matches the given name, argument count and argument types, otherwise
// returns \c false.
static bool methodMatch(const QMetaObject *m, int handle,
                        const QByteArray &name, int argc,
                        const QArgumentType *types)
{
    Q_ASSERT(priv(m->d.data)->revision >= 7);
    if (int(m->d.data[handle + 1]) != argc)
        return false;

    if (stringData(m, m->d.data[handle]) != name)
        return false;

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

/**
* \internal
* helper function for indexOf{Method,Slot,Signal}, returns the relative index of the method within
* the baseObject
* \a MethodType might be MethodSignal or MethodSlot, or 0 to match everything.
*/
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

int QMetaObject::indexOfConstructor(const char *constructor) const
{
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(constructor, types);
    return QMetaObjectPrivate::indexOfConstructor(this, name, types.size(), types.constData());
}

int QMetaObject::indexOfMethod(const char *method) const
{
    const QMetaObject *m = this;
    int i;
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(method, types);
    i = indexOfMethodRelative<0>(&m, name, types.size(), types.constData());
    if (i >= 0)
        i += m->methodOffset();
    return i;
}

// Parses a string of comma-separated types into QArgumentTypes.
// No normalization of the type names is performed.
static void argumentTypesFromString(const char *str, const char *end,
                                    QArgumentTypeArray &types)
{
    Q_ASSERT(str <= end);
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

// Given a method \a signature (e.g. "foo(int,double)"), this function
// populates the argument \a types array and returns the method name.
QByteArray QMetaObjectPrivate::decodeMethodSignature(
        const char *signature, QArgumentTypeArray &types)
{
    Q_ASSERT(signature != 0);
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

/*!
    Finds \a signal and returns its index; otherwise returns -1.

    This is the same as indexOfMethod(), except that it will return
    -1 if the method exists but isn't a signal.

    Note that the \a signal has to be in normalized form, as returned
    by normalizedSignature().

    \sa indexOfMethod(), normalizedSignature(), method(), methodCount(), methodOffset()
*/
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
        if (conflict >= 0) {
            QMetaMethod conflictMethod = m->d.superdata->method(conflict);
        }
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

// same as indexOfSignalRelative but for slots.
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
    for (int i = priv(m->d.data)->constructorCount-1; i >= 0; --i) {
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

/*!
    \internal
    \since 5.0

    Returns the number of signals for the class \a m, including the signals
    for the base class.

    Similar to QMetaObject::methodCount(), but non-signal methods are
    excluded.
*/
int QMetaObjectPrivate::absoluteSignalCount(const QMetaObject *m)
{
    Q_ASSERT(m != 0);
    int n = priv(m->d.data)->signalCount;
    for (m = m->d.superdata; m; m = m->d.superdata)
        n += priv(m->d.data)->signalCount;
    return n;
}

/*!
    \internal
    \since 5.0

    Returns the index of the signal method \a m.

    Similar to QMetaMethod::methodIndex(), but non-signal methods are
    excluded.
*/
int QMetaObjectPrivate::signalIndex(const QMetaMethod &m)
{
    if (!m.mobj)
        return -1;
    return QMetaMethodPrivate::get(&m)->ownMethodIndex() + signalOffset(m.mobj);
}

/*!
    \internal
    \since 5.0

    Returns the signal for the given meta-object \a m at \a signal_index.

    It it different from QMetaObject::method(); the index should not include
    non-signal methods.
*/
QMetaMethod QMetaObjectPrivate::signal(const QMetaObject *m, int signal_index)
{
    QMetaMethod result;
    if (signal_index < 0)
        return result;
    Q_ASSERT(m != 0);
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

/*!
    \internal

    Returns \c true if the \a signalTypes and \a methodTypes are
    compatible; otherwise returns \c false.
*/
bool QMetaObjectPrivate::checkConnectArgs(int signalArgc, const QArgumentType *signalTypes,
                                          int methodArgc, const QArgumentType *methodTypes)
{
    if (signalArgc < methodArgc)
        return false;
    for (int i = 0; i < methodArgc; ++i) {
        if (signalTypes[i] != methodTypes[i])
            return false;
    }
    return true;
}

/*!
    \internal

    Returns \c true if the \a signal and \a method arguments are
    compatible; otherwise returns \c false.
*/
bool QMetaObjectPrivate::checkConnectArgs(const QMetaMethodPrivate *signal,
                                          const QMetaMethodPrivate *method)
{
    if (signal->methodType() != QMetaMethod::Signal)
        return false;
    if (signal->parameterCount() < method->parameterCount())
        return false;
    const QMetaObject *smeta = signal->enclosingMetaObject();
    const QMetaObject *rmeta = method->enclosingMetaObject();
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

/*!
    Finds enumerator \a name and returns its index; otherwise returns
    -1.

    \sa enumerator(), enumeratorCount(), enumeratorOffset()
*/
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

/*!
    Finds property \a name and returns its index; otherwise returns
    -1.

    \sa property(), propertyCount(), propertyOffset()
*/
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

/*!
    Finds class information item \a name and returns its index;
    otherwise returns -1.

    \sa classInfo(), classInfoCount(), classInfoOffset()
*/
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

/*!
    \since 4.5

    Returns the meta-data for the constructor with the given \a index.

    \sa constructorCount(), newInstance()
*/
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

/*!
    Returns the meta-data for the method with the given \a index.

    \sa methodCount(), methodOffset(), indexOfMethod()
*/
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

/*!
    Returns the meta-data for the enumerator with the given \a index.

    \sa enumeratorCount(), enumeratorOffset(), indexOfEnumerator()
*/
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

/*!
    Returns the meta-data for the property with the given \a index.
    If no such property exists, a null QMetaProperty is returned.

    \sa propertyCount(), propertyOffset(), indexOfProperty()
*/
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

/*!
    \since 4.2

    Returns the property that has the \c USER flag set to true.

    \sa QMetaProperty::isUser()
*/
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

/*!
    Returns the meta-data for the item of class information with the
    given \a index.

    Example:

    \snippet code/src_corelib_kernel_qmetaobject.cpp 0

    \sa classInfoCount(), classInfoOffset(), indexOfClassInfo()
 */
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

/*!
    Returns \c true if the \a signal and \a method arguments are
    compatible; otherwise returns \c false.

    Both \a signal and \a method are expected to be normalized.

    \sa normalizedSignature()
*/
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

/*!
    \since 5.0
    \overload

    Returns \c true if the \a signal and \a method arguments are
    compatible; otherwise returns \c false.
*/
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


/*!
    \since 4.2

    Normalizes a \a type.

    See QMetaObject::normalizedSignature() for a description on how
    Qt normalizes.

    Example:

    \snippet code/src_corelib_kernel_qmetaobject.cpp 1

    \sa normalizedSignature()
 */
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

/*!
    Normalizes the signature of the given \a method.

    Qt uses normalized signatures to decide whether two given signals
    and slots are compatible. Normalization reduces whitespace to a
    minimum, moves 'const' to the front where appropriate, removes
    'const' from value types and replaces const references with
    values.

    \sa checkConnectArgs(), normalizedType()
 */
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

    // 首先, 根据参数, 生成要调用方法的签名出来.

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
    // 根据函数和参数的签名, 就可以从元信息对象里面, 获得对应的 QMetaMethod 对象.
    QMetaMethod method = meta->method(idx);
    return method.invoke(obj, type, ret,
                         val0, val1, val2, val3, val4, val5, val6, val7, val8, val9);
}

QByteArray QMetaMethodPrivate::signature() const
{
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
    return stringData(mobj, mobj->d.data[handle]);
}

int QMetaMethodPrivate::typesDataIndex() const
{
    Q_ASSERT(priv(mobj->d.data)->revision >= 7);
    return mobj->d.data[handle + 2];
}

const char *QMetaMethodPrivate::rawReturnTypeName() const
{
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

/*!
    \since 5.0

    Returns the name of this method.

    \sa methodSignature(), parameterCount()
*/
QByteArray QMetaMethod::name() const
{
    if (!mobj)
        return QByteArray();
    return QMetaMethodPrivate::get(this)->name();
}

/*!
    \since 5.0

    Returns the return type of this method.

    The return value is one of the types that are registered
    with QMetaType, or QMetaType::UnknownType if the type is not registered.

    \sa parameterType(), QMetaType, typeName()
*/
int QMetaMethod::returnType() const
 {
     if (!mobj)
         return QMetaType::UnknownType;
    return QMetaMethodPrivate::get(this)->returnType();
}

/*!
    \since 5.0

    Returns the number of parameters of this method.

    \sa parameterType(), parameterNames()
*/
int QMetaMethod::parameterCount() const
{
    if (!mobj)
        return 0;
    return QMetaMethodPrivate::get(this)->parameterCount();
}

/*!
    \since 5.0

    Returns the type of the parameter at the given \a index.

    The return value is one of the types that are registered
    with QMetaType, or QMetaType::UnknownType if the type is not registered.

    \sa parameterCount(), returnType(), QMetaType
*/
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

/*!
    \since 5.0
    \internal

    Gets the parameter \a types of this method. The storage
    for \a types must be able to hold parameterCount() items.

    \sa parameterCount(), returnType(), parameterType()
*/
void QMetaMethod::getParameterTypes(int *types) const
{
    if (!mobj)
        return;
    QMetaMethodPrivate::get(this)->getParameterTypes(types);
}

/*!
    Returns a list of parameter types.

    \sa parameterNames(), methodSignature()
*/
QList<QByteArray> QMetaMethod::parameterTypes() const
{
    if (!mobj)
        return QList<QByteArray>();
    return QMetaMethodPrivate::get(this)->parameterTypes();
}

/*!
    Returns a list of parameter names.

    \sa parameterTypes(), methodSignature()
*/
QList<QByteArray> QMetaMethod::parameterNames() const
{
    QList<QByteArray> list;
    if (!mobj)
        return list;
    return QMetaMethodPrivate::get(this)->parameterNames();
}


/*!
    Returns the return type name of this method.

    \sa returnType(), QMetaType::type()
*/
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


/*!
    \internal
 */
int QMetaMethod::attributes() const
{
    if (!mobj)
        return false;
    return ((mobj->d.data[handle + 4])>>4);
}

/*!
  \since 4.6

  Returns this method's index.
*/
int QMetaMethod::methodIndex() const
{
    if (!mobj)
        return -1;
    return QMetaMethodPrivate::get(this)->ownMethodIndex() + mobj->methodOffset();
}

// This method has been around for a while, but the documentation was marked \internal until 5.1
/*!
    \since 5.1
    Returns the method revision if one was
    specified by Q_REVISION, otherwise returns 0.
 */
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

// MethodType, Access 的原理不太清楚. 不过, 都是从 data 里面, 也就是元信息系统里面读取的值. 也就是应该在 MOC 过程中生成.
QMetaMethod::Access QMetaMethod::access() const
{
    if (!mobj)
        return Private;
    return (QMetaMethod::Access)(mobj->d.data[handle + 4] & AccessMask);
}

/*!
    Returns the type of this method (signal, slot, or method).

    \sa access()
*/
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
        // 如果, 可以在一个 metaobjet 里面找到, 那么这就是 method 所在的元信息.
        if (i >= 0) {
            result.mobj = m;
            result.handle = priv(m->d.data)->methodData + 5*i;
            break;
        }
    }
    return result;
}

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

    // check return type
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

    // 根据 Object 的线程信息, 和当前的线程信息, 判断 Invoke 是不是需要 queued
    QThread *currentThread = QThread::currentThread();
    QThread *objectThread = object->thread();
    if (connectionType == Qt::AutoConnection) {
        connectionType = currentThread == objectThread
                         ? Qt::DirectConnection
                         : Qt::QueuedConnection;
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

//  首先获取, 元信息对象里面的 static_metacall 的这个值, 这是一个函数指针, 直接将所有的东西传递给他就可以.
    QObjectPrivate::StaticMetaCallFunction callFunction = mobj->d.static_metacall;
    //
    if (connectionType == Qt::DirectConnection) {
        if (callFunction) {
            callFunction(object, QMetaObject::InvokeMetaMethod, idx_relative, param);
            return true;
        } else {
            return QMetaObject::metacall(object, QMetaObject::InvokeMetaMethod, idx_relative + idx_offset, param) < 0;
        }
    } else if (connectionType == Qt::QueuedConnection) {
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

        /*
         这里, 会把参数复制一遍.
         */
        for (int i = 1; i < paramCount; ++i) {
            types[i] = QMetaType::type(typeNames[i]);
            if (types[i] == QMetaType::UnknownType && param[i]) {
                // Try to register the type and try again before reporting an error.
                int index = nargs - 1;
                void *argv[] = { &types[i], &index };
                QMetaObject::metacall(object, QMetaObject::RegisterMethodArgumentMetaType,
                                      idx_relative + idx_offset, argv);
                if (types[i] == -1) {
                    qWarning("QMetaMethod::invoke: Unable to handle unregistered datatype '%s'",
                            typeNames[i]);
                    for (int x = 1; x < i; ++x) {
                        if (types[x] && args[x])
                            QMetaType::destroy(types[x], args[x]);
                    }
                    free(types);
                    free(args);
                    return false;
                }
            }
            if (types[i] != QMetaType::UnknownType) {
                args[i] = QMetaType::create(types[i], param[i]);
                ++nargs;
            }
        }
        // 然后直接交给了 PostEvent 函数. 而传递的 event, 是一个特殊类型的 event.
        QCoreApplication::postEvent(object, new QMetaCallEvent(idx_offset, idx_relative, callFunction,
                                                        0, -1, nargs, types, args));
    } else { // blocking queued connection
#ifndef QT_NO_THREAD
        if (currentThread == objectThread) {
            qWarning("QMetaMethod::invoke: Dead lock detected in "
                        "BlockingQueuedConnection: Receiver is %s(%p)",
                        mobj->className(), object);
        }
        // 这里, 直接进行了当前线程的阻塞.
        QSemaphore semaphore;
        QCoreApplication::postEvent(object, new QMetaCallEvent(idx_offset, idx_relative, callFunction,
                                                        0, -1, 0, 0, param, &semaphore));
        semaphore.acquire();
#endif // QT_NO_THREAD
    }
    return true;
}

/*!
    \since 5.5

    Invokes this method on a Q_GADGET. Returns \c true if the member could be invoked.
    Returns \c false if there is no such member or the parameters did not match.

    The pointer \a gadget must point to an instance of the gadget class.

    The invocation is always synchronous.

    The return value of this method call is placed in \a
    returnValue. You can pass up to ten arguments (\a val0, \a val1,
    \a val2, \a val3, \a val4, \a val5, \a val6, \a val7, \a val8,
    and \a val9) to this method call.

    \warning this method will not test the validity of the arguments: \a gadget
    must be an instance of the class of the QMetaObject of which this QMetaMethod
    has been constructed with.  The arguments must have the same type as the ones
    expected by the method, else, the behavior is undefined.

    \sa Q_ARG(), Q_RETURN_ARG(), qRegisterMetaType(), QMetaObject::invokeMethod()
*/
bool QMetaMethod::invokeOnGadget(void* gadget, QGenericReturnArgument returnValue, QGenericArgument val0, QGenericArgument val1, QGenericArgument val2, QGenericArgument val3, QGenericArgument val4, QGenericArgument val5, QGenericArgument val6, QGenericArgument val7, QGenericArgument val8, QGenericArgument val9) const
{
   if (!gadget || !mobj)
        return false;

    // check return type
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
    Q_ASSERT(QMetaObjectPrivate::get(mobj)->revision >= 6);
    QObjectPrivate::StaticMetaCallFunction callFunction = mobj->d.static_metacall;
    if (!callFunction)
        return false;
    callFunction(reinterpret_cast<QObject*>(gadget), QMetaObject::InvokeMetaMethod, idx_relative, param);
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

// isFlag 指的是, 可不可以用 | 进行多个值同时传输.
bool QMetaEnum::isFlag() const
{
    return mobj && mobj->d.data[handle + 1] & EnumIsFlag;
}

/*!
    \since 5.8

    Returns \c true if this enumerator is declared as a C++11 enum class;
    otherwise returns false.
*/
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


static QByteArray qualifiedName(const QMetaEnum &e)
{
    return QByteArray(e.scope()) + "::" + e.name();
}

/*!
    \class QMetaProperty
    \inmodule QtCore
    \brief The QMetaProperty class provides meta-data about a property.

    \ingroup objectmodel

    Property meta-data is obtained from an object's meta-object. See
    QMetaObject::property() and QMetaObject::propertyCount() for
    details.

    \section1 Property Meta-Data

    A property has a name() and a type(), as well as various
    attributes that specify its behavior: isReadable(), isWritable(),
    isDesignable(), isScriptable(), revision(), and isStored().

    If the property is an enumeration, isEnumType() returns \c true; if the
    property is an enumeration that is also a flag (i.e. its values
    can be combined using the OR operator), isEnumType() and
    isFlagType() both return true. The enumerator for these types is
    available from enumerator().

    The property's values are set and retrieved with read(), write(),
    and reset(); they can also be changed through QObject's set and get
    functions. See QObject::setProperty() and QObject::property() for
    details.

    \section1 Copying and Assignment

    QMetaProperty objects can be copied by value. However, each copy will
    refer to the same underlying property meta-data.

    \sa QMetaObject, QMetaEnum, QMetaMethod, {Qt's Property System}
*/

/*!
    \fn bool QMetaProperty::isValid() const

    Returns \c true if this property is valid (readable); otherwise
    returns \c false.

    \sa isReadable()
*/

/*!
    \fn const QMetaObject *QMetaProperty::enclosingMetaObject() const
    \internal
*/

/*!
    \internal
*/
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

/*!
    Reads the property's value from the given \a object. Returns the value
    if it was able to read it; otherwise returns an invalid variant.

    \sa write(), reset(), isReadable()
*/
QVariant QMetaProperty::read(const QObject *object) const
{
    if (!object || !mobj)
        return QVariant();

    uint t = QVariant::Int;
    if (isEnumType()) {
        /*
          try to create a QVariant that can be converted to this enum
          type (only works if the enum has already been registered
          with QMetaType)
        */
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
