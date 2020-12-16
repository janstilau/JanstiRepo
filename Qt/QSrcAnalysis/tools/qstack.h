#ifndef QSTACK_H
#define QSTACK_H

#include <QtCore/qvector.h>

QT_BEGIN_NAMESPACE


// 这里设计的有点问题啊, 作为适配器, 为什么要 public 继承呢.
// 这样的话, 不就有太多的机会, 去修改 stack 的数据了吗.
template<class T>
class QStack : public QVector<T>
{
public:
    // compiler-generated special member functions are fine!
    inline void swap(QStack<T> &other) Q_DECL_NOTHROW { QVector<T>::swap(other); } // prevent QVector<->QStack swaps
    inline void push(const T &t) { QVector<T>::append(t); }
    T pop();
    T &top();
    const T &top() const;
};

template<class T>
inline T QStack<T>::pop()
{ Q_ASSERT(!this->isEmpty()); T t = this->data()[this->size() -1];
  this->resize(this->size()-1); return t; }

template<class T>
inline T &QStack<T>::top()
{ Q_ASSERT(!this->isEmpty()); this->detach(); return this->data()[this->size()-1]; }

template<class T>
inline const T &QStack<T>::top() const
{ Q_ASSERT(!this->isEmpty()); return this->data()[this->size()-1]; }

QT_END_NAMESPACE

#endif // QSTACK_H
