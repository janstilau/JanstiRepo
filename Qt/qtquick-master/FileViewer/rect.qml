import QtQuick 2.12
import QtQuick.Controls 1.1
import an.qt.ColorMaker 1.0

ApplicationWindow{
    id: root;
    width: 360
    height: 240
    visible: true

    ColorMaker {
        id: handler
    }



    Rectangle {
        id: rootItem;
        width: 360;
        height: 300;
        property var count: 0;
        property Component component: null;

        Text {
            id: coloredText;
            text: "Hello World!";
            anchors.centerIn: parent;
            font.pixelSize: 24;
        }

        function changeTextColor(clr){
            coloredText.color = clr;
        }

        function createColorPicker(clr){
            if(rootItem.component == null){
                rootItem.component = Qt.createComponent("ColorPicker.qml");
            }
            var colorPicker;
            if(rootItem.component.status == Component.Ready) {
                colorPicker = rootItem.component.createObject(rootItem, {"color" : clr, "x" : rootItem.count *55, "y" : 10});
                colorPicker.colorPicked.connect(rootItem.changeTextColor);
                //[1] add 3 lines to delete some obejcts
                if(rootItem.count % 2 == 1) {
                    colorPicker.destroy(1000);
                }
            }

            rootItem.count++;
        }

        Button {
            id: add;
            text: "add";
            anchors.left: parent.left;
            anchors.leftMargin: 4;
            anchors.bottom: parent.bottom;
            anchors.bottomMargin: 4;
            onClicked: {
                rootItem.createColorPicker(Qt.rgba(Math.random(), Math.random(), Math.random(), 1));
            }
        }


//    Rectangle {
//        id: rootItem;
//        width: 320;
//        height: 240;
//        color: "#EEEEEE";

//        Text {
//            id: coloredText;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            text: "Hello World!";
//            font.pixelSize: 32;
//        }

//        MouseArea {
//            anchors.fill: parent
//            onClicked: {
//                colorComponent.createObject(rootItem,
//                                            {"color" : "red", "x" : 2 *55, "y" : 10})
//            }
//        }

//        Component {
//            id: colorComponent;
//            Rectangle {
//                id: colorPicker;
//                width: 50;
//                height: 30;
//                signal colorPicked(color clr);
//                property Item loader;
//                border.width: focus ? 2 : 0;
//                border.color: focus ? "#90D750" : "#808080";
//                MouseArea {
//                    anchors.fill: parent
//                    onClicked: {
//                        colorPicker.colorPicked(colorPicker.color);
//                        loader.focus = true;
//                    }
//                }
//                Keys.onReturnPressed: {
//                    colorPicker.colorPicked(colorPicker.color);
//                    event.accepted = true;
//                }
//                Keys.onSpacePressed: {
//                    colorPicker.colorPicked(colorPicker.color);
//                    event.accepted = true;
//                }
//            }
//        }

//        Loader{
//            id: redLoader;
//            width: 80;
//            height: 60;
//            focus: true;
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            sourceComponent: colorComponent;
//            KeyNavigation.right: blueLoader;
//            KeyNavigation.tab: blueLoader;

//            onLoaded:{
//                item.color = "red";
//                item.focus = true;
//                item.loader = redLoader;
//            }
//            onFocusChanged:{
//                item.focus = focus;
//            }
//        }

//        Loader{
//            id: blueLoader;
//            anchors.left: redLoader.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            sourceComponent: colorComponent;
//            KeyNavigation.left: redLoader;
//            KeyNavigation.tab: redLoader;

//            onLoaded:{
//                item.color = "blue";
//                item.loader = blueLoader;
//            }
//            onFocusChanged:{
//                item.focus = focus;
//            }
//        }

//        Connections {
//            target: redLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }

//        Connections {
//            target: blueLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }
    }


//    Rectangle {
//        width: 320;
//        height: 240;
//        color: "#EEEEEE";
//        id: rootItem;
//        property var colorPickerShow : false;

//        Text {
//            id: coloredText;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            text: "Hello World!";
//            font.pixelSize: 32;
//        }

//        Button {
//            id: ctrlButton;
//            text: "Show";
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;

//            onClicked:{
//                // 根据一个属性, 控制显示.
//                // 这里, 根据 loadeer 的 source, 来控制加载和消亡.
//               if(rootItem.colorPickerShow){
//                   redLoader.source = "";
//                   blueLoader.source = "";
//                   rootItem.colorPickerShow = false;
//                   ctrlButton.text = "Show";
//               }else{
//                   // 因为每一次, 都是新的对象生成, 所以每一次都要进行一次连接.
//                   redLoader.source = "ColorPicker.qml";
//                   redLoader.item.colorPicked.connect(rootItem.onPickedRed);

//                   blueLoader.source = "ColorPicker.qml";
//                   blueLoader.item.colorPicked.connect(rootItem.onPickedBlue);

//                   redLoader.focus = true;
//                   rootItem.colorPickerShow = true;
//                   ctrlButton.text = "Hide";
//               }
//            }
//        }

//        // Loader 本身就是一个可见的元素
//        Loader{
//            id: redLoader;
//            anchors.left: ctrlButton.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: ctrlButton.bottom;

//            KeyNavigation.right: blueLoader;
//            KeyNavigation.tab: blueLoader;

//            onLoaded:{
//                if(item != null){
//                    item.color = "red";
//                    item.focus = true;
//                }
//            }

//            onFocusChanged:{
//                if(item != null){
//                    item.focus = focus;
//                }
//            }
//        }

//        Loader{
//            id: blueLoader;
//            anchors.left: redLoader.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: redLoader.bottom;

//            KeyNavigation.left: redLoader;
//            KeyNavigation.tab: redLoader;

//            onLoaded:{
//                if(item != null){
//                    item.color = "blue";
//                }
//            }

//            onFocusChanged:{
//                if(item != null){
//                    item.focus = focus;
//                }
//            }
//        }

//        function onPickedBlue(clr){
//            coloredText.color = clr;
//            if(!blueLoader.focus){
//               blueLoader.focus = true;
//               redLoader.focus = false;
//            }
//        }

//        function onPickedRed(clr){
//            coloredText.color = clr;
//            if(!redLoader.focus){
//               redLoader.focus = true;
//               blueLoader.focus = false;
//            }
//        }
//    }
//    }

//    Rectangle {

//        width: 320;
//        height: 240;
//        color: "#C0C0C0";

//        Text {
//            id: coloredText;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            text: "Hello World!";
//            font.pixelSize: 32;
//        }

//        // 在 QML 里面内嵌的一个类, 可以用来复用.
//        // 只能包含一个顶级的 Item, 除了 id 不能定义其他的任何属性
//        // Component 是一个不可变对象, 所以这里不会有可见的元素添加, 必须进行 load 之后, 才会生成对应的视图.
//        // Component 不是 Item 的派生类，而是从 QQmlComponent 继承而来
//        Component {
//            id: colorComponent; // 这个东西, 可以当做类名来进行理解.
//            Rectangle {
//                id: colorPicker;
//                width: 50;
//                height: 30;
//                signal colorPicked(color clr);
//                MouseArea {
//                    anchors.fill: parent
//                    onPressed: colorPicker.colorPicked(colorPicker.color);
//                }
//            }
//        }

//        Loader{
//            id: redLoader;
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            sourceComponent: colorComponent; // 加载 colorComponent 所代表的 Component
//            onLoaded:{
//                item.color = "red";
//            }
//        }

//        Loader{
//            id: blueLoader;
//            anchors.left: redLoader.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            sourceComponent: colorComponent;
//            onLoaded:{
//                item.color = "blue";
//            }
//        }

//        Connections {
//            target: redLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }

//        Connections {
//            target: blueLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }
//    }

//    Rectangle {
//        width: 320;
//        height: 240;
//        color: "gray";
//        QtObject{
//            id: attrs;
//            property int counter;
//            Component.onCompleted:{
//                attrs.counter = 10;
//            }
//        }

//        Text {
//            id: countShow;
//            anchors.centerIn: parent;
//            color: "blue";
//            font.pixelSize: 40;
//        }

//        Timer {
//            id: countDown;
//            interval: 1000;
//            repeat: true;
//            triggeredOnStart: true;
//            onTriggered:{
//                countShow.text = attrs.counter;
//                attrs.counter -= 1;
//                if(attrs.counter < 0)
//                {
//                    countDown.stop();
//                    countShow.text = "Clap Now!";
//                }
//            }
//        }

//        Button {
//            id: startButton;
//            anchors.top: countShow.bottom;
//            anchors.topMargin: 20;
//            anchors.horizontalCenter: countShow.horizontalCenter;
//            text: "Start";
//            onClicked: {
//                countDown.start();
//                handler.onSingaleHandlerd(attrs)
//            }
//        }
//    }

//    Rectangle {
//        width: 320;
//        height: 480;
//        color: "gray";

//        focus: true;
//        Keys.enabled: true;
//        Keys.onEscapePressed: {
//            Qt.quit();
//        }
//        // 想要传递按钮事件给列表内的对象, 按照列表的顺序来.
//        Keys.forwardTo: [moveText, likeQt];

//        Text {
//            id: moveText;
//            x: 20;
//            y: 20;
//            width: 200;
//            height: 30;
//            text: "Moving Text";
//            color: "blue";
//            //focus: true;
//            font { bold: true; pixelSize: 24;}

//            Keys.enabled: true;
//            Keys.onPressed: {
//                switch(event.key){
//                case Qt.Key_Left:
//                    x -= 10;
//                    break;
//                case Qt.Key_Right:
//                    x += 10;
//                    break;
//                case Qt.Key_Down:
//                    y += 10;
//                    break;
//                case Qt.Key_Up:
//                    y -= 10;
//                    break;
//                default:
//                    return;
//                }
//                event.accepted = true; // 不往上传递了
//            }
//        }

//        CheckBox {
//            id: likeQt;
//            text: "Like Qt Quick";
//            anchors.left: parent.left;
//            anchors.leftMargin: 10;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 10;
//            z: 1;
//            Keys.onSpacePressed: {
//                console.log("onSpacePressed handled in CheckBox")
//            }
//        }
//    }



//    Rectangle {
//        width: 320;
//        height: 240;
//        color: "#C0C0C0";

//        Text {
//            id: coloredText;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            text: "Hello World!";
//            font.pixelSize: 32;
//        }

//        // 在这里定义了一个组件
//        Component {
//            id: colorComponent;
//            Rectangle {
//                id: colorPicker;
//                width: 50;
//                height: 30;
//                signal colorPicked(color clr);
//                MouseArea {
//                    anchors.fill: parent
//                    onPressed: colorPicker.colorPicked(colorPicker.color);
//                }
//            }
//        }

//        Loader{
//            id: redLoader;
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;

//            sourceComponent: colorComponent;
//            onLoaded:{
//                item.color = "red";
//            }
//        }

//        Loader{
//            id: blueLoader;
//            anchors.left: redLoader.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            sourceComponent: colorComponent;
//            onLoaded:{
//                item.color = "blue";
//            }
//        }

//        Connections {
//            target: redLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }

//        Connections {
//            target: blueLoader.item;
//            onColorPicked:{
//                coloredText.color = clr;
//            }
//        }
//    }

//    Rectangle {

//        width: 360;
//        height: 240;
//        color: "#EEEEEE";
//        id: rootItem;
//        visible: true;

//        Text {
//            id: centerText;
//            text: "A Single Text.";
//            anchors.centerIn: parent;
//            font.pixelSize: 24;
//            font.bold: true;
//        }

//        function setTextColor(clr){
//            centerText.color = clr;
//        }

//        //color pickers look at parent's top
//        ColorPicker {
//            id: topColor1;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: topColor2;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.left: topColor1.right;
//            anchors.leftMargin: 4;
//            anchors.top: topColor1.top;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: topColor3;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.right: parent.right;
//            anchors.rightMargin: 4;
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: topColor4;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.right: topColor3.left;
//            anchors.rightMargin: 4;
//            anchors.top: topColor3.top;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        //color pickers sit on parent's bottom
//        ColorPicker {
//            id: bottomColor1;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: bottomColor2;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.left: bottomColor1.right;
//            anchors.leftMargin: 4;
//            anchors.bottom: bottomColor1.bottom;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: bottomColor3;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.right: parent.right;
//            anchors.rightMargin: 4;
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        ColorPicker {
//            id: bottomColor4;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.right: bottomColor3.left;
//            anchors.rightMargin: 4;
//            anchors.bottom: bottomColor3.bottom;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        //align to parent's left && vertical center
//        ColorPicker {
//            id: leftVCenterColor;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.left: parent.left;
//            anchors.leftMargin: 4;
//            anchors.verticalCenter: parent.verticalCenter;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        //align to parent's right && vertical center
//        ColorPicker {
//            id: rightVCenterColor;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.right: parent.right;
//            anchors.rightMargin: 4;
//            anchors.verticalCenter: parent.verticalCenter;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        //align to parent's top && horizontal center
//        ColorPicker {
//            id: topHCenterColor;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.top: parent.top;
//            anchors.topMargin: 4;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            onColorPicked: rootItem.setTextColor(clr);
//        }

//        //align to parent's bottom && horizontal center
//        ColorPicker {
//            id: bottomHCenterColor;
//            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0);
//            anchors.bottom: parent.bottom;
//            anchors.bottomMargin: 4;
//            anchors.horizontalCenter: parent.horizontalCenter;
//            onColorPicked: rootItem.setTextColor(clr);
//        }
//    }

}
