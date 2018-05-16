const View = require('./view')

class ViewTreeCreator {
  constructor(levelArray) {
    this.levels = levelArray
  }

  getTree() {
    let rootView = new View()
    let rootSubViews = rootView.subViews
    this.levels.forEach(level => {
      let subView = this.getView(level)
      rootSubViews.push(subView)
      subView.parent = rootView
    });
    return rootView
  }

  getView(level) {
    let view = new View(level)
    if (level.type === 'folder') {
      level.attributes.children.forEach(subLevel => {
        let subView = this.getView(subLevel)
        view.subViews.push(subView)
        subView.parent = view
      });
    }

    return view
  }
}

module.exports = ViewTreeCreator