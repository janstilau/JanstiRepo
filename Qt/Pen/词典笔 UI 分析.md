# UI 分析

整个 Pen 项目, 命名使用了原来的匈牙利命名法, 变量的开头, 会有表示变量类型的前缀.
s_ 开头, 表示这是一个常量.

* QToastWindow 
简单的底部 Toast 控件, 会自动销毁.

* QPenFrameWindow
主界面. 几个重要的入口都在这里进行配置.
这个类还有很多无关界面的代码业务处理的逻辑.

m_pageList 管理着其他 Page.
s_qsIntroduction -> QIntroductionPage 引导页
s_qsHome -> QHomePage 词典首页, 有着各种入口.
s_qsReadingWordResult -> QReadingWordResultPage
m_pageList -> QSettingPage 设置页
s_qsDictHome -> QFirstPage 查词翻译的首页.
s_qsResult ->  QResultPage : 创建查词、翻译结果页面
s_qsReadingWordResult -> 
s_qsScan -> QScanPage: 实时扫描页
s_qsSpeechFirst -> QSpeechFirstPage 语音助手页, 请说, 我在听
s_qsSpeechQuery -> QSpeechQueryPage 语音助手结果也
s_qsBookReadingHome -> QReadingHomePage 图书点读页
s_qsDialog -> QCommonDialog 命令对话框

s_qsHistory -> QHistoryPage 历史记录页
s_qsLogin -> QLoginPage 登录页
s_qsFavorite -> 收藏夹页

s_qsFollowSpeech -> QFollowSpeechInterface 跟读页面
s_qsSpellSpeech -> QSpellSpeechPage 拼读页面
s_qsLowPower -> 低电量页面.
s_qsKeyboard -> QKeyboardWindow 软键盘页面

s_qsAudioPlayer -> QAudioPage 听力页面

s_qsPowerOff -> 关机页面.

m_qsCurPage 记录当前正在显示的 page 名称

在 QPenFrameWindow::onScanStart 的时候, 会切换到 s_qsScan 所在的扫描页.
在 QPenFrameWindow::onScanning 的时候, 会不断更新 s_qsScan 对应的内容.
在 QPenFrameWindow::onScanFinish 的时候, 
{
    如果是图书阅读进入, 则专门把扫描结果, 传递进去, 结束. showPage.
    如果没有结果, 那么显示 s_qsDictHome, 查词翻译的首页, 并且 toast 提示.
    将结果放到 s_qsResult 中, 然后展示结果页.
}


void QPenFrameWindow::showPage(const QString& qsPage) 函数
{
    这个函数, 会根据 qsPage 的名字, 进行相应的 page 的显示工作.
    如果 m_qsCurPage 有值的话, 就添加到历史记录中, 并且把当前的 page 进行隐藏.
    然后更新 m_qsCurPage 名称, 然后显示相应的 page
    因为有着原来的 page 隐藏的操作. 所以很多时候, 都是找到相应的 page, 更新内容之后, 调用 showPage.
}
.

* HomePage 页面
在这个页面, 会创建首页的按钮, 这些按钮点击之后, 会发送一个信号出去 showPage
这个信号, 会把需要展示的页面的名字传出去, QString
这个信号, 会在 QPenFrameWindow::onShowPage 进行接收.

查词翻译 s_qsDictHome
语音助手 s_qsSpeechQuery, s_qsSpeechHome
图书点读 s_qsBookReadingHome
单词本 s_qsFavorite
听力练习 s_qsAudioPlayer
查词历史 s_qsHistory
更多设置. s_qsSetting,s_qsStFirst

* 页面的弹出关系.
各个页面之间, 没有父子关系.
如果一个页面, 要从另一个页面跳转过来, 就是在这个页面上, 新建一个新的页面而已, 然后将这个页面 show.


{
    创建一个新的页面的流程.
    首先创建一个 pWrapper, 这个 Wrapper 的尺寸, 设置为屏幕大小.
}


## 重点分析查词翻译页面.


