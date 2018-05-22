attribute highp vec4 posAttr;
attribute lowp vec4 colAttr;
varying lowp vec4 color;
uniform highp mat4 matrix;
void main() {
   color = colAttr;
   gl_Position = matrix * posAttr;
}
