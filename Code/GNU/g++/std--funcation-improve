#include <functional>
#include <iostream>

int getOne(int a) {
    return 1;
}

class NumGenerator {
public:
    int num_;
    NumGenerator(int num) : num_(num) {
        std::cout << "generator constructed." << std::endl;
    }
    NumGenerator(const NumGenerator &another) {
        std::cout << "copy generator constructed." << std::endl;
        num_ = another.num_;
    }
    NumGenerator(NumGenerator &&another) {
        std::cout << "rvalue generator constructed." << std::endl;
        num_ = another.num_;
    }

    operator int() const {
        return num_;
    }
    int getNum() {
        return num_;
    }
    ~NumGenerator() {
        std::cout << "destruct now" << std::endl;
    }
};

struct getTwo {
    getTwo() {
        std::cout << "construct gettwo" << std::endl;
    }
    int operator()(int a, NumGenerator b) {
        return a + b.getNum();
    }
};

int getRef(int a, NumGenerator &b) {
    return a + b.getNum();
}

class getNumber {
public:
    int getThree(int a) {
        return 3;
    }
    static int getFour(int a) {
        return 4;
    }
};

// 默认特化不实现
template < typename T >
class Function;

template < typename Ret, typename... Args >
class Function< Ret(Args...) > {
    //构造虚基类以存储任意可调用对象的指针
    struct callable_base {
        virtual Ret operator()(Args &&... a) = 0;
        virtual struct callable_base *copy() const = 0;
        virtual ~callable_base(){};
    };
    struct callable_base *base;

    template < typename T >
    struct callable_derived : public callable_base {
        T f;
        callable_derived(T functor) : f(functor) {}
        Ret operator()(Args &&... a) {
            return f(std::forward< Args >(a)...);
        }

        struct callable_base *copy() const {
            return new callable_derived< T >(f);
        }
    };

public:
    template < typename T >
    Function(T functor) : base(new callable_derived< T >(functor)) {}
    Function() : base(nullptr) {}
    // 实际调用存储的函数
    Ret operator()(Args... arg) {
        return (*base)(std::forward< Args >(arg)...);
    }
    Function(const Function &f) {
        std::cout << "copy construct" << std::endl;
        base = f.base->copy();
    }
    Function &operator=(const Function &f) {
        std::cout << "assign construct" << std::endl;
        delete base;
        base = f.base->copy();
        return *this;
    }

    ~Function() {
        std::cout << "delete current base callable object" << std::endl;
        delete base;
    }
};

int main() {
    // basic function
    class Function< int(int) > getNumber(getOne);
    std::cout << getNumber(3) << std::endl;

    NumGenerator gen(8);
    // class which override operator()
    std::cout << "*** get number 2 start" << std::endl;
    class Function< int(int, NumGenerator) > getNumber2(getTwo{});
    int num2 = 2;
    std::cout << getNumber2(2, gen) << std::endl;
    std::cout << "*** get number 2 end" << std::endl;

    // compare with std::function
    std::cout << "*** get number2 std::function start" << std::endl;
    std::function< int(int, NumGenerator) > funGetNumber2(getTwo{});
    std::cout << funGetNumber2(2, gen) << std::endl;
    std::cout << "*** get number2 std::function end" << std::endl;

    // function with reference
    std::cout << "---get number 3 start" << std::endl;
    class Function< int(int, NumGenerator &) > getNumber3(getRef);
    std::cout << getNumber3(num2, gen) << std::endl;
    std::cout << getNumber3(2, gen) << std::endl;
    std::cout << "---get number 3 end" << std::endl;

    // compare with std::function
    std::cout << "---get number3 std::function start" << std::endl;
    std::function< int(int, NumGenerator &) > funGetNumber3(getRef);
    std::cout << funGetNumber3(2, gen) << std::endl;
    std::cout << "---number3 std::function end" << std::endl;

    // non static member function
    class getNumber n;
    Function< int(int) > getNumber4(std::bind(&getNumber::getThree, &n, 9));

    // static member function
    Function< int(int) > getNumber5(&getNumber::getFour);
    std::cout << getNumber5(5) << std::endl;

    // lambda
    Function< int(int) > getNumber6 = [](int one) -> int { return 5 + one; };
    std::cout << getNumber6(5) << std::endl;

    return 0;
}
