#version 330 core

in VS_OUT
{
    vec3 local_normal;
} fs_in;

out vec4 color;

uniform samplerCube tex_color_cube;

void main()
{

    color = texture(tex_color_cube, fs_in.local_normal);
}
