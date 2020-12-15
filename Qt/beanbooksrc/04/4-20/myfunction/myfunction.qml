import QtQuick 2.2

Rectangle {

    function calculateHeight() {
        return rect.width / 2;
    }

    width: 100; height: calculateHeight()
    // 将 id 放到后面, 也可以正常的识别出来.
    id: rect
}

