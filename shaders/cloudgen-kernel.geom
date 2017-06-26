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
    float age;
    float curvature;
} gs_in[];

out GS_OUT
{
    vec2 uv;
    float speed;
    float fade;
} gs_out;

void main()
{
    vec3 normal    = gl_in[0].gl_Position.xyz;
    vec3 tangent   = normalize(gs_in[0].velocity);
    float size     = min(0.5 * (gs_in[0].age) + 1, 4 * gs_in[0].age);
    gs_out.speed   = length(gs_in[0].velocity);
    gs_out.fade    = min(1, 5 - gs_in[0].age);
    //vec3 w = 2 * (0.0015 + 0.5*gs_out.speed) * cross(normal, tangent); // tangent and normal are always perpendicular

    vec3 w = (0.004 + 0.001 * gs_out.speed) * size * cross(normal, tangent);
    vec3 l = (0.004 + 0.005 * gs_out.speed) * size * tangent;
    //vec3 w = 0.05*min(1, gs_in[0].age) * cross(normal, tangent);
    //vec3 l = 0.1*min(1, gs_in[0].age) * tangent;
    //vec3 l = 5*gs_in[0].age * (0.0005 + gs_out.speed) * tangent;
    gl_Position = projection * view * model * vec4(normal - w - l, 1);
    gs_out.uv = vec2(0, 0);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal - w + l, 1);
    gs_out.uv = vec2(1, 0);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + w - l, 1);
    gs_out.uv = vec2(0, 1);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + w + l, 1);
    gs_out.uv = vec2(1, 1);
    EmitVertex();
    EndPrimitive();
}
