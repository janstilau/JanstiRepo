import QtQuick.Controls 1.2

// Slider 是一个原生的类型.
// 这里有点问题啊, 既然是原生的类型, 凭什么 Applicaiton.qml 里面, 是使用了这个 Slider 作为 Slider 而不是原生的.
Slider {
    maximumValue : 100
    minimumValue : 0

    onValueChanged: print(value)
}
