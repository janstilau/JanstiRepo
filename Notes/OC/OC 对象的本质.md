# 对象的本质

底层实现, 都是 C/C++ 代码.

重写 OC 代码到 cpp 文件的命令: clang -rewrite-objc 源文件 -o 目标文件.cpp
指定架构 : xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc 源文件 -o 目标文件.cpp



## NSObject

``` OC
struct NSObject_IMPL {
	Class isa; // 8个字节, 64位系统.
};
```
typedef struct object_class *Class;

获取一个类的实例对象大小: size_t class_getInstanceSize(Class cls)
也就是类的实例变量所占用搞的存储空间.

获取一个类的实例的占据空间大小:  malloc_size(const void*ptr)

一个 NSObject 的实例大小是 8, 但是占用的大小是 16. 

``` c
这里, 首先是调用 data()->ro 里面的instanceSize的大小, 这个大小是在 class_addIvar 的时候, 累加添加 Ivar 的 length 值记录的. 然后, 进行word_align, 这里其实就是保证, 最后这个值是8的倍数. word_align最后的操作, 就如同 +9 然后把个位数的值省略一样, 这样就能保证数值是10的倍数.
    size_t class_getInstanceSize(Class cls)
    {
        if (!cls) return 0;
        return cls->alignedInstanceSize();
    }
    uint32_t unalignedInstanceSize() {
        assert(isRealized());
        return data()->ro->instanceSize;
    }
    uint32_t alignedInstanceSize() {
        return word_align(unalignedInstanceSize());
    }
    #   define WORD_MASK 7UL
    static inline uint32_t word_align(uint32_t x) {
        return (x + WORD_MASK) & ~WORD_MASK;
    }

```

而在分配内存的时候, 会调用 instanceSize, 这个函数会用到上面的 class_getInstanceSize 的值(其实是alignedInstanceSize), 然后里面有个特殊的判断, 如果大小小于16, 就至少分配16个字节.

```OC
    size_t instanceSize(size_t extraBytes) {
        size_t size = alignedInstanceSize() + extraBytes;
        // CF requires all objects be at least 16 bytes.
        if (size < 16) size = 16;
        return size;
    }
```

结构体的内存对齐规定: 按照最大的成员变量的所占空间的倍数.