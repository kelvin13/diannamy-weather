#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

layout (std140) uniform camera // total: 168
{
    mat4 projection;        // 0
    mat4 view;              // 64
    vec3 camera_position;   // 128
    vec4 camera_frustum;    // 144 , layout <h/2, k/2, 2*size, z>
    vec2 camera_shift;      // 160 , layout <sx, sy>
};

uniform mat4 model;

in VS_OUT
{
    vec3 velocity;
} gs_in[];

out GS_OUT
{
    vec2 uv;
    float speed;
} gs_out;

void main()
{
    vec3 normal    = gl_in[0].gl_Position.xyz;
    vec3 tangent   = normalize(gs_in[0].velocity);
    gs_out.speed   = length(gs_in[0].velocity);
    vec3 w = 0.005*cross(normal, tangent); // tangent and normal are always perpendicular
    vec3 l = 10 * (0.0005 + gs_out.speed) * tangent;
    gl_Position = projection * view * model * vec4(normal - w - l, 1);
    gs_out.uv = vec2(0, 0);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal - w + l, 1);
    gs_out.uv = vec2(0, 1);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + w - l, 1);
    gs_out.uv = vec2(1, 0);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + w + l, 1);
    gs_out.uv = vec2(1, 1);
    EmitVertex();
    EndPrimitive();
}
