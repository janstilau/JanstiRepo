# isa


// 位域不管你左边是什么类型. 先写的东西, 在右边. 也就是 nonpointer 在最右边一位.
这里, 位域的作用是增加了代码的可读性.
union isa_t
{
    Class cls;
    uintptr_t bits;
    struct {
        uintptr_t nonpointer        : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 33; // MACH_VM_MAX_ADDRESS 0x1000000000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1; // 有没有被弱引用指向过, 如果有, 析构的时候, 要去弱引用表进行清理
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1; // 如果下面的19位不够引用计数, 那么这里就为1, 引用计数存放到一个全局的表中
        uintptr_t extra_rc          : 19; // 引用计数
    };
};

在64位的架构下, isa 进行了优化, 使得它除了简单地指针, 变成了由位域标记的不同位置代表不同含义的结构体.
位域这种技术, 平时不要用, 因为自己定义的数据结构, 没有必要进行优化.
如果真的要用位域, 那么就要编写对应的取值设值方法, 因为在用到数据的时候, 再去用位运算就太麻烦了. 所以, 用位域会让代码变得复杂.  iOS 系统用到这个技术, 是因为所有的类都是 objc_object. 多用一点空间, 就意味着所有的对象都浪费一点空间. 所以, 在系统层面上做这种优化是很有必要的.


## 位运算

& 0000 1000 用来取出特定的位, 它将其他位的数值变为0, 只留下特定位的数值    ~~~~ & 掩码
| 0000 1000 用来设置特定位的数值为1. 其他位的数值不变, 而特定的位固定变成1 ~~~~ | 掩码
& 1111 0111 用来设置特定位的数值为0. 其他位的数值不变, 而特定的位固定变成0 ~~~~ & 掩码取反
掩码
#define AMask (1<<0)
#define BMask (1<<1)
#define CMask (1<<2)



