const path = require('path')
const fs = require('fs')
const PSDParser = require('psd-parser')
const XMLBuilder = require('xmlbuilder')
const Level = require('./level')
const ViewTreeCreator = require('./view-tree-creator')


// ------------------ fs -----------------------
function findFiles(dir, filter) {
  if (!fs.existsSync(dir)) { return }

  let result = []
  let files = fs.readdirSync(dir)
  for (let f of files) {
    let file = path.join(dir, f)
    let stat = fs.lstatSync(file)
    if (stat.isDirectory()) {
      result = result.concat(findFiles(file, filter)) //recurse
    } else if (file.endsWith(filter)) {
      result.push(file)
    }
  }
  return result
}

function handleLayer(layer) {
  if (!layer) { return }

  if (Level.isFolder(layer)) { return handleFolderLayer(layer) }
  if (Level.isText(layer)) { return handleTextLayer(layer) }
  return handleImageLayer(layer)
}

function handleTextLayer(layer) {
  if (!layer) { return }

  let text = new Level(layer)
  text.convertToText()

  return text
}

function handleFolderLayer(layer) {
  if (!layer) { return }

  let folder = new Level(layer)
  folder.convertToFolder()
  let children = folder.attributes.children
  for (let child of layer.children) {
    let childObject = handleLayer(child)
    if (childObject) {
      children.push(childObject)
    }
  }
  return folder
}

function handleImageLayer(layer) {
  if (!layer) { return}

  let image = new Level(layer)
  image.convertToImage()

  return image
}

// ------------------ app -----------------------
let files = findFiles('./psd', '.psd')

for (let f of files) {
  let psd = PSDParser.parse(f)

  // 把psd导出的图片直接放在psd目录
  // let outputDir = f.substr(0, f.length - 4)
  // if (!fs.existsSync(outputDir)) {
  //   fs.mkdirSync(outputDir)
  // }

  let roots = psd.getTree()
  let levels = []
  for (let root of roots) {
    levels.push(handleLayer(root))
  }
  let creator = new ViewTreeCreator(levels)
  let rootView = creator.getTree()
  console.log(rootView)
}