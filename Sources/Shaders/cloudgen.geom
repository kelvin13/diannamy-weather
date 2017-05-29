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

void main()
{
    vec3 normal    = gl_in[0].gl_Position.xyz;
    vec3 tangent   = gs_in[0].velocity;
    vec3 bitangent = 0.005*normalize(cross(normal, tangent));
    gl_Position = projection * view * model * vec4(normal - bitangent - 5*tangent, 1);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal - bitangent + 5*tangent, 1);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + bitangent - 5*tangent, 1);
    EmitVertex();

    gl_Position = projection * view * model * vec4(normal + bitangent + 5*tangent, 1);
    EmitVertex();
    EndPrimitive();
}
