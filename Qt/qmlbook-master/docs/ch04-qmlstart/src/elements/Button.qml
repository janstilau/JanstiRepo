/*
 * Copyright (c) 2013, Juergen Bocklage-Ryannel, Johan Thelin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the editors nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// M1>>
// Button.qml

import QtQuick 2.5

Rectangle {
    id: root
    // export button properties
    // 其他的属性, 这里的设置都是默认参数的意思, 因为其他的都可以在使用的时候重新设置, 但是子 view, 必须通过 alias 才能修改.
    // 实验证明, id 只能是在定义的 QML 文件里面使用. 所以, 除了从 Rect 继承的属性, 只有自己定义的属性, 在外界使用的时候, 才能自定义.
    property alias text: label.text // 给了用户自定义的机会.
    signal clicked

    width: 116; height: 26 // 继承的属性, 外界还可以改变.
    color: "lightsteelblue"
    border.color: "slategrey"

    Text { // 子控件, 外界无法改变.
        id: label
        anchors.centerIn: parent
        text: "Start"
    }
    MouseArea { // 子控件, 外界无法改变.
        anchors.fill: parent
        onClicked: {
            root.clicked()
        }
    }
}

// <<M1
