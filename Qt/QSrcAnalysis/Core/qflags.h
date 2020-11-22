#include <QtCore/qglobal.h>


#ifdef Q_COMPILER_INITIALIZER_LISTS
#include <initializer_list>
#endif

QT_BEGIN_NAMESPACE

class QDataStream;

class QFlag
{
    int i; // 存储的值
public:
    Q_DECL_CONSTEXPR inline QFlag(int value) Q_DECL_NOTHROW : i(value) {}
    Q_DECL_CONSTEXPR inline operator int() const Q_DECL_NOTHROW { return i; }
};
Q_DECLARE_TYPEINFO(QFlag, Q_PRIMITIVE_TYPE);

class QIncompatibleFlag
{
    int i;
public:
    Q_DECL_CONSTEXPR inline explicit QIncompatibleFlag(int i) Q_DECL_NOTHROW;
    Q_DECL_CONSTEXPR inline operator int() const Q_DECL_NOTHROW { return i; }
};
Q_DECLARE_TYPEINFO(QIncompatibleFlag, Q_PRIMITIVE_TYPE);

Q_DECL_CONSTEXPR inline QIncompatibleFlag::QIncompatibleFlag(int value) Q_DECL_NOTHROW : i(value) {}


#ifndef Q_NO_TYPESAFE_FLAGS

template<typename Enum>
class QFlags
{
    struct Private;
    typedef int (Private::*Zero);
    template <typename E> friend QDataStream &operator>>(QDataStream &, QFlags<E> &);
    template <typename E> friend QDataStream &operator<<(QDataStream &, QFlags<E>);
public:
#if defined(Q_CC_MSVC) || defined(Q_CLANG_QDOC)
    // see above for MSVC
    // the definition below is too complex for qdoc
    typedef int Int;
#else
    typedef typename std::conditional<
            std::is_unsigned<typename std::underlying_type<Enum>::type>::value,
            unsigned int,
            signed int
        >::type Int;
#endif
    typedef Enum enum_type;
    // compiler-generated copy/move ctor/assignment operators are fine!
#ifdef Q_CLANG_QDOC
    Q_DECL_CONSTEXPR inline QFlags(const QFlags &other);
    Q_DECL_CONSTEXPR inline QFlags &operator=(const QFlags &other);
#endif
    Q_DECL_CONSTEXPR inline QFlags(Enum flags) Q_DECL_NOTHROW : i(Int(flags)) {}
    Q_DECL_CONSTEXPR inline QFlags(Zero = Q_NULLPTR) Q_DECL_NOTHROW : i(0) {}
    Q_DECL_CONSTEXPR inline QFlags(QFlag flag) Q_DECL_NOTHROW : i(flag) {}

#ifdef Q_COMPILER_INITIALIZER_LISTS
    Q_DECL_CONSTEXPR inline QFlags(std::initializer_list<Enum> flags) Q_DECL_NOTHROW
        : i(initializer_list_helper(flags.begin(), flags.end())) {}
#endif

    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator&=(int mask) Q_DECL_NOTHROW { i &= mask; return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator&=(uint mask) Q_DECL_NOTHROW { i &= mask; return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator&=(Enum mask) Q_DECL_NOTHROW { i &= Int(mask); return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator|=(QFlags other) Q_DECL_NOTHROW { i |= other.i; return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator|=(Enum other) Q_DECL_NOTHROW { i |= Int(other); return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator^=(QFlags other) Q_DECL_NOTHROW { i ^= other.i; return *this; }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &operator^=(Enum other) Q_DECL_NOTHROW { i ^= Int(other); return *this; }

    Q_DECL_CONSTEXPR inline operator Int() const Q_DECL_NOTHROW { return i; }

    Q_DECL_CONSTEXPR inline QFlags operator|(QFlags other) const Q_DECL_NOTHROW { return QFlags(QFlag(i | other.i)); }
    Q_DECL_CONSTEXPR inline QFlags operator|(Enum other) const Q_DECL_NOTHROW { return QFlags(QFlag(i | Int(other))); }
    Q_DECL_CONSTEXPR inline QFlags operator^(QFlags other) const Q_DECL_NOTHROW { return QFlags(QFlag(i ^ other.i)); }
    Q_DECL_CONSTEXPR inline QFlags operator^(Enum other) const Q_DECL_NOTHROW { return QFlags(QFlag(i ^ Int(other))); }
    Q_DECL_CONSTEXPR inline QFlags operator&(int mask) const Q_DECL_NOTHROW { return QFlags(QFlag(i & mask)); }
    Q_DECL_CONSTEXPR inline QFlags operator&(uint mask) const Q_DECL_NOTHROW { return QFlags(QFlag(i & mask)); }
    Q_DECL_CONSTEXPR inline QFlags operator&(Enum other) const Q_DECL_NOTHROW { return QFlags(QFlag(i & Int(other))); }
    Q_DECL_CONSTEXPR inline QFlags operator~() const Q_DECL_NOTHROW { return QFlags(QFlag(~i)); }

    Q_DECL_CONSTEXPR inline bool operator!() const Q_DECL_NOTHROW { return !i; }

    Q_DECL_CONSTEXPR inline bool testFlag(Enum flag) const Q_DECL_NOTHROW { return (i & Int(flag)) == Int(flag) && (Int(flag) != 0 || i == Int(flag) ); }
    Q_DECL_RELAXED_CONSTEXPR inline QFlags &setFlag(Enum flag, bool on = true) Q_DECL_NOTHROW
    {
        return on ? (*this |= flag) : (*this &= ~Int(flag));
    }

private:
#ifdef Q_COMPILER_INITIALIZER_LISTS
    Q_DECL_CONSTEXPR static inline Int initializer_list_helper(typename std::initializer_list<Enum>::const_iterator it,
                                                               typename std::initializer_list<Enum>::const_iterator end)
    Q_DECL_NOTHROW
    {
        return (it == end ? Int(0) : (Int(*it) | initializer_list_helper(it + 1, end)));
    }
#endif

    Int i;
};

#ifndef Q_MOC_RUN
#define Q_DECLARE_FLAGS(Flags, Enum)\
typedef QFlags<Enum> Flags;
#endif

#define Q_DECLARE_INCOMPATIBLE_FLAGS(Flags) \
Q_DECL_CONSTEXPR inline QIncompatibleFlag operator|(Flags::enum_type f1, int f2) Q_DECL_NOTHROW \
{ return QIncompatibleFlag(int(f1) | f2); }

#define Q_DECLARE_OPERATORS_FOR_FLAGS(Flags) \
Q_DECL_CONSTEXPR inline QFlags<Flags::enum_type> operator|(Flags::enum_type f1, Flags::enum_type f2) Q_DECL_NOTHROW \
{ return QFlags<Flags::enum_type>(f1) | f2; } \
Q_DECL_CONSTEXPR inline QFlags<Flags::enum_type> operator|(Flags::enum_type f1, QFlags<Flags::enum_type> f2) Q_DECL_NOTHROW \
{ return f2 | f1; } Q_DECLARE_INCOMPATIBLE_FLAGS(Flags)


#else /* Q_NO_TYPESAFE_FLAGS */

#ifndef Q_MOC_RUN
#define Q_DECLARE_FLAGS(Flags, Enum)\
typedef uint Flags;
#endif

#define Q_DECLARE_OPERATORS_FOR_FLAGS(Flags)

#endif /* Q_NO_TYPESAFE_FLAGS */

QT_END_NAMESPACE

