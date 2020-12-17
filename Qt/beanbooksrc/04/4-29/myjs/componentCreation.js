var component;
var sprite;
// 在这里, 提前进行了变量的定义.

function createSpriteObjects() {
    component = Qt.createComponent("Sprite.qml"); // 可以认为, 这里是 loadnib
    if (component.status == Component.Ready)
        finishCreation();
    else
        component.statusChanged.connect(finishCreation);
}

function finishCreation() {
    if (component.status == Component.Ready) {
        // 然后这里是从 nib 生成对应的对象.
        // 然后这里设置了 父对象, 所以就添加到对应的父对象的 view 上.
        // 可以直接写 appWindow 吗, 这有关系吗.
        sprite = component.createObject(appWindow, {"x": 100, "y": 100});
        if (sprite == null) {
            // 错误处理
            console.log("Error creating object");
        }
    } else if (component.status == Component.Error) {
        // 错误处理
        console.log("Error loading component:", component.errorString());
    }
}
