#version 330 core

in GS_OUT
{
    vec2 uv;
    float speed;
} fs_in;

out vec4 color;

uniform sampler2D tex_cloud;

void main()
{

    color = vec4(1, 1, 1, 80*fs_in.speed * texture(tex_cloud, fs_in.uv).r);
}
