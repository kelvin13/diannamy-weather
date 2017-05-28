#version 330 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 uv_map;

out vec2 uv_coord;

void main()
{
    gl_Position = vec4(position.xy, -1.0, 1.0);
    uv_coord = uv_map;
}
