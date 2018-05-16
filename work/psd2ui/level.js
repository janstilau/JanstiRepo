class Level {
  constructor(layer) {
    this.name = this.levelName(layer)
    this.layer = layer
    this.type = ''
    this.positon = {
      left: layer.left,
      top: layer.top,
      width: layer.width,
      height: layer.height
    }
    this.attributes = {}
  }

  levelName(layer) {
    if (!layer) {
      return ""
    }
    return layer.get('layerName')
  }

  saveAsPng(path) {
    this.layer.saveAsPng(path)
  }

  convertToText() {
    let layer = this.layer
    this.type = 'text'
    this.text = layer.get('text')
    this.attributes = {}
    let style = layer.get('wordSnippets')[0]
    this.attributes.fontSize = style['font-size']
    this.attributes.fontWeight = style['font-weight']
    this.attributes.color = style['color']
  }

  convertToFolder() {
    this.type = 'folder'
    this.attributes = {}
    this.attributes.children = []
  }

  convertToImage() {
    this.type = 'image'
    this.attributes = {}
  }

  static isText(layer) {
    return layer && layer.additional['TySh']
  }

  static isFolder(layer) {
    return layer && layer.children
  }
}

module.exports = Level