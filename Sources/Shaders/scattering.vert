#version 330 core

layout (location = 0) in vec3 local_position;
layout (location = 1) in vec3 normal;

out vec3 sphere_center;
out vec3 lamp_hat;

layout (std140) uniform camera // total: 168
{
    mat4 projection;        // 0
    mat4 view;              // 64
    vec3 camera_position;   // 128
    vec4 camera_frustum;    // 144 , layout <h/2, k/2, 2*size, z>
    vec2 camera_shift;      // 160 , layout <sx, sy>
};

uniform mat4 model;

void main()
{
    gl_Position = projection * view * model * vec4(local_position, 1);
    vec4 sphere_c = view * model * vec4(0, 0, 0, 1);
    sphere_center = vec3(sphere_c.xy, -sphere_c.z);
    vec4 lamp = view * vec4(30, 0, 0, 1); // needs to be unified
    lamp_hat = normalize(vec3(lamp.xy, -lamp.z) - sphere_center);
}
