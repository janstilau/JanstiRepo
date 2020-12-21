import QtQuick 2.0

Myproperty {
    onNextColorChanged: {
        console.log("onNextColorChanged in users")
    }
    Text {
        text: "Top"
    }
}
