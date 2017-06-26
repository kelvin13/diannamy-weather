#version 330 core

layout (location = 0) in vec3 local_position;
layout (location = 1) in vec3 velocity;
layout (location = 2) in vec2 age_curvature;

out VS_OUT
{
    vec3 velocity;
    float age;
    float curvature;
} vs_out;

void main()
{
    gl_Position = vec4(local_position, 1);
    vs_out.velocity = velocity;
    vs_out.age = age_curvature.x;
    vs_out.curvature = age_curvature.y;
}
