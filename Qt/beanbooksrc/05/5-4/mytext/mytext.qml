import QtQuick 2.2

Column {
    Text {
        text: "Hello World!";
        font.family: "Helvetica";
        font.pointSize: 50;
        color: "green"
    }
    Text {
        // text 属性, 自动判断, 是否是富文本显示.
        // 这个控件, 有着自动大小计算的功能
        text: "<p>　　12月6日，北京国安、天津泰达、河南建业、上海申花、浙江绿城等5支老牌俱乐部下的球迷协会联合发表声明，反对中国足协中性名称政策一刀切的做法。，反对中国足协中性名称政策一刀切的做法，反对中国足协中性名称政策一刀切的做法，反对中国足协中性名称政策一刀切的做法</p><p class=\"f_center\">　　<img src=\"https://nimg.ws.126.net/?url=http%3A%2F%2Fdingyue.ws.126.net%2F2020%2F1210%2Feab26ce6j00ql3vti001zc000u000jzm.jpg&thumbnail=650x2147483647&quality=80&type=jpg\"/><br/></p>"
        width: parent.width
        wrapMode: Text.WrapAnywhere

        Rectangle {
            color: "red"
            anchors.fill: parent
            z: -1
        }
    }
}
