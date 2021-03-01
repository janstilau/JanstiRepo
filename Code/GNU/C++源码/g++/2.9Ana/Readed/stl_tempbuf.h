#ifndef __SGI_STL_INTERNAL_TEMPBUF_H
#define __SGI_STL_INTERNAL_TEMPBUF_H


__STL_BEGIN_NAMESPACE
/*
 Allocates uninitialized contiguous storage, which should be sufficient to store up to count adjacent objects of type T.
 The request is non-binding and the implementation may allocate less or more than necessary to store count adjacent objects.
 */
template <class T>
pair<T*, ptrdiff_t> get_temporary_buffer(ptrdiff_t len, T) {
    if (len > ptrdiff_t(INT_MAX / sizeof(T)))
        len = INT_MAX / sizeof(T);
    
    while (len > 0) {
        T* tmp = (T*) malloc((size_t)len * sizeof(T));
        if (tmp != 0)
            return pair<T*, ptrdiff_t>(tmp, len);
        len /= 2;
    }
    
    return pair<T*, ptrdiff_t>((T*)0, 0);
}

/*
 虽然, 里面仅仅是一个 free 操作, 但是 get_temporary_buffer, 和 return_temporary_buffer 是一对操作, 明显的写出来, 让代码更加的有可读性.
 */
template <class T>
void return_temporary_buffer(T* p) {
    free(p);
}

template <class ForwardIterator, class T>
class temporary_buffer {
private:
    ptrdiff_t original_len;
    ptrdiff_t len;
    T* buffer;
    
    /*
     这里进行内存空间的开辟工作.
     */
    void allocate_buffer() {
        original_len = len;
        buffer = 0;
        
        if (len > (ptrdiff_t)(INT_MAX / sizeof(T)))
            len = INT_MAX / sizeof(T);
        
        while (len > 0) {
            buffer = (T*) malloc(len * sizeof(T));
            if (buffer)
                break;
            len /= 2;
        }
    }
    
    void initialize_buffer(const T&, __true_type) {}
    void initialize_buffer(const T& val, __false_type) {
        uninitialized_fill_n(buffer, len, val);
    }
    
public:
    ptrdiff_t size() const { return len; }
    ptrdiff_t requested_size() const { return original_len; }
    T* begin() { return buffer; }
    T* end() { return buffer + len; }
    
    temporary_buffer(ForwardIterator first, ForwardIterator last) {
        __STL_TRY {
            len = 0;
            distance(first, last, len);
            allocate_buffer();
            if (len > 0)
                initialize_buffer(*first,
                                  typename __type_traits<T>::has_trivial_default_constructor());
        }
        __STL_UNWIND(free(buffer); buffer = 0; len = 0);
    }
    
    ~temporary_buffer() {
        /*
         destroy 里面, 应该是调用析构函数吧.
         */
        destroy(buffer, buffer + len);
        free(buffer);
    }
    
private:
    temporary_buffer(const temporary_buffer&) {}
    void operator=(const temporary_buffer&) {}
};

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_TEMPBUF_H */

// Local Variables:
// mode:C++
// End:
