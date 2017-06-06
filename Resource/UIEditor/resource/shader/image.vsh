attribute highp vec4 posAttr;
attribute lowp vec4 colAttr;
attribute lowp vec2 textCoordAttr;
varying lowp vec4 color;
varying lowp vec2 textCoord;
uniform highp mat4 matrix;
void main() {
   color = colAttr;
   gl_Position = matrix * posAttr;
   textCoord = textCoordAttr;
}
