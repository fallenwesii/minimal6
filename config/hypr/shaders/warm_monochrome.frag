#version 300 es

precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;

out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);

    float grayscale = dot(pixColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 warmTint = vec3(1.0, 0.80, 0.60);

    fragColor = vec4(vec3(grayscale) * warmTint, pixColor.a);
}
