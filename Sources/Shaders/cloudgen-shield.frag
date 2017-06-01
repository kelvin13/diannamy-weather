#version 330 core

in GS_OUT
{
    vec2 uv;
    float speed;
    float fade;
} fs_in;

out vec4 color;

uniform sampler2D tex_cloud;

void main()
{

    color = vec4(1, 1, 1, 0.07 * fs_in.fade * fs_in.speed * texture(tex_cloud, fs_in.uv).r);
}
