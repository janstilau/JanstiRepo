/****************************************************************************
** Meta object code from reading C++ file 'myprocesser.h'
**
** Created by: The Qt Meta Object Compiler version 67 (Qt 5.12.10)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../QtStudy/myprocesser.h"
#include <QtCore/qbytearray.h>
#include <QtCore/qmetatype.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'myprocesser.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 67
#error "This file was generated using the moc from 5.12.10. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

QT_BEGIN_MOC_NAMESPACE
QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
struct qt_meta_stringdata_MyProcesser_t {
    QByteArrayData data[21];
    char stringdata0[229];
};
#define QT_MOC_LITERAL(idx, ofs, len) \
    Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(len, \
    qptrdiff(offsetof(qt_meta_stringdata_MyProcesser_t, stringdata0) + ofs \
        - idx * sizeof(QByteArrayData)) \
    )
static const qt_meta_stringdata_MyProcesser_t qt_meta_stringdata_MyProcesser = {
    {
QT_MOC_LITERAL(0, 0, 11), // "MyProcesser"
QT_MOC_LITERAL(1, 12, 6), // "author"
QT_MOC_LITERAL(2, 19, 22), // "Sabrina Schweinsteiger"
QT_MOC_LITERAL(3, 42, 3), // "url"
QT_MOC_LITERAL(4, 46, 31), // "http://doc.moosesoft.co.uk/1.0/"
QT_MOC_LITERAL(5, 78, 8), // "location"
QT_MOC_LITERAL(6, 87, 15), // "LosAngel, Chine"
QT_MOC_LITERAL(7, 103, 15), // "valueDidChanged"
QT_MOC_LITERAL(8, 119, 0), // ""
QT_MOC_LITERAL(9, 120, 12), // "currentValue"
QT_MOC_LITERAL(10, 133, 15), // "priorityChanged"
QT_MOC_LITERAL(11, 149, 8), // "Priority"
QT_MOC_LITERAL(12, 158, 16), // "onValueNeedReset"
QT_MOC_LITERAL(13, 175, 5), // "value"
QT_MOC_LITERAL(14, 181, 6), // "_reset"
QT_MOC_LITERAL(15, 188, 5), // "dummy"
QT_MOC_LITERAL(16, 194, 8), // "priority"
QT_MOC_LITERAL(17, 203, 4), // "High"
QT_MOC_LITERAL(18, 208, 3), // "Low"
QT_MOC_LITERAL(19, 212, 8), // "VeryHigh"
QT_MOC_LITERAL(20, 221, 7) // "VeryLow"

    },
    "MyProcesser\0author\0Sabrina Schweinsteiger\0"
    "url\0http://doc.moosesoft.co.uk/1.0/\0"
    "location\0LosAngel, Chine\0valueDidChanged\0"
    "\0currentValue\0priorityChanged\0Priority\0"
    "onValueNeedReset\0value\0_reset\0dummy\0"
    "priority\0High\0Low\0VeryHigh\0VeryLow"
};
#undef QT_MOC_LITERAL

static const uint qt_meta_data_MyProcesser[] = {

 // content:
       8,       // revision
       0,       // classname
       3,   14, // classinfo
       6,   20, // methods
       1,   65, // properties
       1,   69, // enums/sets
       1,   82, // constructors
       0,       // flags
       2,       // signalCount

 // classinfo: key, value
       1,    2,
       3,    4,
       5,    6,

 // signals: name, argc, parameters, tag, flags
       7,    1,   50,    8, 0x06 /* Public */,
      10,    1,   53,    8, 0x06 /* Public */,

 // slots: name, argc, parameters, tag, flags
      12,    1,   56,    8, 0x0a /* Public */,
      12,    0,   59,    8, 0x2a /* Public | MethodCloned */,
      14,    0,   60,    8, 0x08 /* Private */,

 // methods: name, argc, parameters, tag, flags
      15,    0,   61,    8, 0x02 /* Public */,

 // signals: parameters
    QMetaType::Void, QMetaType::Int,    9,
    QMetaType::Void, 0x80000000 | 11,    8,

 // slots: parameters
    QMetaType::Void, QMetaType::Int,   13,
    QMetaType::Void,
    QMetaType::Void,

 // methods: parameters
    QMetaType::Void,

 // constructors: parameters
    0x80000000 | 8, QMetaType::Int,   13,

 // properties: name, type, flags
      16, 0x80000000 | 11, 0x0049510b,

 // properties: notify_signal_id
       1,

 // enums: name, alias, flags, count, data
      11,   11, 0x0,    4,   74,

 // enum data: key, value
      17, uint(MyProcesser::High),
      18, uint(MyProcesser::Low),
      19, uint(MyProcesser::VeryHigh),
      20, uint(MyProcesser::VeryLow),

 // constructors: name, argc, parameters, tag, flags
       0,    1,   62,    8, 0x0e /* Public */,

       0        // eod
};

void MyProcesser::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::CreateInstance) {
        switch (_id) {
        case 0: { MyProcesser *_r = new MyProcesser((*reinterpret_cast< int(*)>(_a[1])));
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = _r; } break;
        default: break;
        }
    } else if (_c == QMetaObject::InvokeMetaMethod) {
        auto *_t = static_cast<MyProcesser *>(_o);
        Q_UNUSED(_t)
        switch (_id) {
        case 0: _t->valueDidChanged((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 1: _t->priorityChanged((*reinterpret_cast< Priority(*)>(_a[1]))); break;
        case 2: _t->onValueNeedReset((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 3: _t->onValueNeedReset(); break;
        case 4: _t->_reset(); break;
        case 5: _t->dummy(); break;
        default: ;
        }
    } else if (_c == QMetaObject::IndexOfMethod) {
        int *result = reinterpret_cast<int *>(_a[0]);
        {
            using _t = void (MyProcesser::*)(int );
            if (*reinterpret_cast<_t *>(_a[1]) == static_cast<_t>(&MyProcesser::valueDidChanged)) {
                *result = 0;
                return;
            }
        }
        {
            using _t = void (MyProcesser::*)(Priority );
            if (*reinterpret_cast<_t *>(_a[1]) == static_cast<_t>(&MyProcesser::priorityChanged)) {
                *result = 1;
                return;
            }
        }
    }
#ifndef QT_NO_PROPERTIES
    else if (_c == QMetaObject::ReadProperty) {
        auto *_t = static_cast<MyProcesser *>(_o);
        Q_UNUSED(_t)
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast< Priority*>(_v) = _t->priority(); break;
        default: break;
        }
    } else if (_c == QMetaObject::WriteProperty) {
        auto *_t = static_cast<MyProcesser *>(_o);
        Q_UNUSED(_t)
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setPriority(*reinterpret_cast< Priority*>(_v)); break;
        default: break;
        }
    } else if (_c == QMetaObject::ResetProperty) {
    }
#endif // QT_NO_PROPERTIES
}

QT_INIT_METAOBJECT const QMetaObject MyProcesser::staticMetaObject = { {
    &QObject::staticMetaObject,
    qt_meta_stringdata_MyProcesser.data,
    qt_meta_data_MyProcesser,
    qt_static_metacall,
    nullptr,
    nullptr
} };


const QMetaObject *MyProcesser::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MyProcesser::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_MyProcesser.stringdata0))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int MyProcesser::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 6)
            *reinterpret_cast<int*>(_a[0]) = -1;
        _id -= 6;
    }
#ifndef QT_NO_PROPERTIES
    else if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    } else if (_c == QMetaObject::QueryPropertyDesignable) {
        _id -= 1;
    } else if (_c == QMetaObject::QueryPropertyScriptable) {
        _id -= 1;
    } else if (_c == QMetaObject::QueryPropertyStored) {
        _id -= 1;
    } else if (_c == QMetaObject::QueryPropertyEditable) {
        _id -= 1;
    } else if (_c == QMetaObject::QueryPropertyUser) {
        _id -= 1;
    }
#endif // QT_NO_PROPERTIES
    return _id;
}

// SIGNAL 0
void MyProcesser::valueDidChanged(int _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}

// SIGNAL 1
void MyProcesser::priorityChanged(Priority _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}
QT_WARNING_POP
QT_END_MOC_NAMESPACE
