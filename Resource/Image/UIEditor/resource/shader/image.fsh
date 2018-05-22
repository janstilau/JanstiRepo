varying lowp vec2 textCoord;
varying lowp vec4 color;
uniform sampler2D ourTexture;
void main() {
   gl_FragColor = texture2D(ourTexture, textCoord) * color;
}
