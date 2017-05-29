#version 330 core

layout (location = 0) in vec3 local_position;
layout (location = 1) in vec3 velocity;

out VS_OUT
{
    vec3 velocity;
} vs_out;

void main()
{
    gl_Position = vec4(local_position, 1);
    vs_out.velocity = velocity;
}
