import ViewController = require("hoolai/ViewController");

type Constructable = new (...args: any[]) => object;
export function generateBaseClass<T extends Constructable>(baseClass: T) {
    abstract class CustomClass extends baseClass {
        closeBtn: hoolai.gui.Button;
        Roleanimation: hoolai.gui.ImageView;
        ebitBoxName: hoolai.gui.EditBox;
        randName: hoolai.gui.Button;
        roleDec: hoolai.gui.Label;
        manBtn: hoolai.gui.Button;
        chosedManLab: hoolai.gui.Label;
        noChosedManLab: hoolai.gui.Label;
        girlBtn: hoolai.gui.Button;
        chosedGirlLab: hoolai.gui.Label;
        noChosedGirlLab: hoolai.gui.Label;
        enterGameBtn: hoolai.gui.Button;
        enterGameLab: hoolai.gui.Label;
        abstract closechoseRoleAction(btn: hoolai.gui.Button);
        abstract randNameAction(btn: hoolai.gui.Button);
        abstract choseManAction(btn: hoolai.gui.Button);
        abstract choseWoManAction(btn: hoolai.gui.Button);
        abstract EnterGameAction(btn: hoolai.gui.Button);
    }
    return CustomClass;
}

export abstract class  create_role {
    closeBtn: hoolai.gui.Button;
    Roleanimation: hoolai.gui.ImageView;
    ebitBoxName: hoolai.gui.EditBox;
    randName: hoolai.gui.Button;
    roleDec: hoolai.gui.Label;
    manBtn: hoolai.gui.Button;
    chosedManLab: hoolai.gui.Label;
    noChosedManLab: hoolai.gui.Label;
    girlBtn: hoolai.gui.Button;
    chosedGirlLab: hoolai.gui.Label;
    noChosedGirlLab: hoolai.gui.Label;
    enterGameBtn: hoolai.gui.Button;
    enterGameLab: hoolai.gui.Label;
    abstract closechoseRoleAction(btn: hoolai.gui.Button);
    abstract randNameAction(btn: hoolai.gui.Button);
    abstract choseManAction(btn: hoolai.gui.Button);
    abstract choseWoManAction(btn: hoolai.gui.Button);
    abstract EnterGameAction(btn: hoolai.gui.Button);
}

export abstract class  create_roleViewController extends ViewController {
    closeBtn: hoolai.gui.Button;
    Roleanimation: hoolai.gui.ImageView;
    ebitBoxName: hoolai.gui.EditBox;
    randName: hoolai.gui.Button;
    roleDec: hoolai.gui.Label;
    manBtn: hoolai.gui.Button;
    chosedManLab: hoolai.gui.Label;
    noChosedManLab: hoolai.gui.Label;
    girlBtn: hoolai.gui.Button;
    chosedGirlLab: hoolai.gui.Label;
    noChosedGirlLab: hoolai.gui.Label;
    enterGameBtn: hoolai.gui.Button;
    enterGameLab: hoolai.gui.Label;
    abstract closechoseRoleAction(btn: hoolai.gui.Button);
    abstract randNameAction(btn: hoolai.gui.Button);
    abstract choseManAction(btn: hoolai.gui.Button);
    abstract choseWoManAction(btn: hoolai.gui.Button);
    abstract EnterGameAction(btn: hoolai.gui.Button);
}
export interface  create_roleInterface {
    closeBtn: hoolai.gui.Button;
    Roleanimation: hoolai.gui.ImageView;
    ebitBoxName: hoolai.gui.EditBox;
    randName: hoolai.gui.Button;
    roleDec: hoolai.gui.Label;
    manBtn: hoolai.gui.Button;
    chosedManLab: hoolai.gui.Label;
    noChosedManLab: hoolai.gui.Label;
    girlBtn: hoolai.gui.Button;
    chosedGirlLab: hoolai.gui.Label;
    noChosedGirlLab: hoolai.gui.Label;
    enterGameBtn: hoolai.gui.Button;
    enterGameLab: hoolai.gui.Label;
    closechoseRoleAction(btn: hoolai.gui.Button);
    randNameAction(btn: hoolai.gui.Button);
    choseManAction(btn: hoolai.gui.Button);
    choseWoManAction(btn: hoolai.gui.Button);
    EnterGameAction(btn: hoolai.gui.Button);
}
