#version 330 core

in vec2 uv_coord;

out vec4 color;

uniform sampler2D img;

void main()
{
    color = texture(img, uv_coord);
}
