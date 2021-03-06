#version 330 core

layout (location = 0) in vec3 local_position;
layout (location = 1) in vec3 local_normal;

layout (std140) uniform camera // total: 168
{
    mat4 projection;        // 0
    mat4 view;              // 64
    vec3 camera_position;   // 128
    vec4 camera_frustum;    // 144 , layout <h/2, k/2, 2*size, z>
    vec2 camera_shift;      // 160 , layout <sx, sy>
};

uniform mat4 model;

out VS_OUT
{
    vec3 local_normal;
} vs_out;

void main()
{
    gl_Position = projection * view * model * vec4(local_position, 1);
    vs_out.local_normal = local_normal;
}
