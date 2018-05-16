class View {
  constructor(level = null) {
    this.level = level
    this.name = this.nameFromLevel(level)
    this.type = this.typeFromLevel(level)
    this.parent = null
    this.subViews = []
    this.position = level? level.positon : null
    this.attributes = getAttributes(level)
  }

  nameFromLevel(level) {
    if (!level) { return ''}
    let reg = /^(\w*)@?/
    let match = reg.exec(level.name)
    if (match !== null) {
      return match[1]
    } else {
      return ''
    }
  }

  typeFromLevel(level) {
    if (!level) { return ''}
    let reg = /@(\w*)\??/
    let match = reg.exec(level.name)
    let declaredType
    if (match !== null) {
      declaredType = match[1]
    } else {
      declaredType = ''
    }
    let type = ''
    switch (level.type) {
      case 'folder':
        type = declaredType ? declaredType : 'view'
        break;
      case 'image':
        type = 'imageView'
        break;
      case 'text':
        type = declaredType ? declaredType : 'label'
        break;
      default:
        throw 'level type error'
        break;
    }

    return type
  }

  getAttributes(level) {
    let attributes = {}
    if (!level) { return attributes }
    if (this.type === 'button') {
      
    } else {
      attributes = level.attributes
    }
  }

}

module.exports = View