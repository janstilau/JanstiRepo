#include "qrunnable.h"

QT_BEGIN_NAMESPACE

QRunnable::~QRunnable()
{
    // Must be empty until ### Qt 6
}

// 增加了一层, 对于 Std::funcation 的包装, 在构造的时候, 使用 move 语义, 转移实现.
// 然后在 run 方法里面, 调用存储的 std::funcaiton.
class FunctionRunnable : public QRunnable
{
    std::function<void()> m_functionToRun;
public:
    FunctionRunnable(std::function<void()> functionToRun) : m_functionToRun(std::move(functionToRun))
    {
    }
    void run() override
    {
        m_functionToRun();
    }
};

QRunnable *QRunnable::create(std::function<void()> functionToRun)
{
    return new FunctionRunnable(std::move(functionToRun));
}

QT_END_NAMESPACE
