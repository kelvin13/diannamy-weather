#version 330 core

in vec3 sphere_center;
in vec3 lamp_hat;

out vec4 color;

layout (std140) uniform camera // total: 168
{
    mat4 projection;        // 0
    mat4 view;              // 64
    vec3 camera_position;   // 128
    vec4 camera_frustum;    // 144 , layout <h/2, k/2, 2*size, z>
    vec2 camera_shift;      // 160 , layout <sx, sy>
};

uniform float inner_radius;
uniform float outer_radius;

// constants
const float PI_4 = 4 * 3.14159265359;

// physical parameters
const float K_R = 0.166;
const float K_M = 0.0025;
const float E = 14.0; 						// light intensity
const vec3  C_R = vec3( 0.3, 0.7, 1.0 ); 	// 1 / wavelength ^ 4

const float G = -0.85;					// Mie g

float SCALE_H = 10.0 / ( outer_radius - inner_radius );
float SCALE_L = 1 / ( outer_radius - inner_radius );

const int SAMPLES_I = 11;
const float di = 1/float(SAMPLES_I);
const int SAMPLES_J = 5;
const float dj = 1/float(SAMPLES_J);

float mie(float cos_theta, float cos2_theta)
{
    float GG = G * G;
    float denominator = 1 + GG - 2*G*cos_theta;
    return 1.5 * (1 - GG) / (2 + GG) * (1 + cos2_theta)/(denominator*sqrt(denominator));
}

float rayleigh(float cos2_theta)
{
    return 0.75 * (1 + cos2_theta);
}

vec2 sphere_intersect(vec3 origin, const vec3 c_hat, const float radius)
{
    origin = sphere_center - origin;
    float midpoint_distance = dot(origin, c_hat);

    float d = radius*radius - dot(origin, origin) + midpoint_distance*midpoint_distance;
    if (d <= 0)
    {
        return vec2(1000000, 1000000); // we cannot discard here because this is a multipurpose function
    }
    else
    {
        float half_depth = sqrt(d);
        /* vec2(near, far) */
        return vec2(midpoint_distance - half_depth, midpoint_distance + half_depth);
    }
}

float rho(float height)
{
    return exp(-height * SCALE_H);
}

float line_integral(vec3 a, vec3 b)
{
    vec3 delta_j = (b - a) * dj;
    vec3 q = a + delta_j * 0.5; // MRAM

    float sum = 0;
    for (int j = 0; j < SAMPLES_J; ++j)
    {
        sum += rho(length(q - sphere_center) - inner_radius);
        q += delta_j;
    }
    return sum * length(delta_j) * SCALE_L;
}

vec3 in_scatter(vec3 c_hat, vec2 slice)
{
    float du = (slice.y - slice.x) * di;
    vec3 delta_i = c_hat * du;
    vec3 P = c_hat * slice.x;
    vec3 Q = P + c_hat * du * 0.5; // perform an MRAM, not an LRAM

    vec3 sum = vec3(0, 0, 0);
    for (int i = 0; i < SAMPLES_I; ++i)
    {
        vec3 X = Q + lamp_hat * sphere_intersect(Q, lamp_hat, outer_radius).y;

        float depth = (line_integral(P, Q) + line_integral(Q, X)) * PI_4;

        sum += rho(length(Q - sphere_center) - inner_radius) * exp( -depth * ( K_R * C_R + K_M));
        Q += delta_i;
    }
    sum *= SCALE_L * du * E;
    float cos_theta = dot(c_hat, -lamp_hat);
    float cos2_theta = cos_theta * cos_theta;
    return sum * (C_R * K_R * rayleigh(cos2_theta) + K_M * mie(cos_theta, cos2_theta));
}

/*********/

vec2 slice_sphere(const vec3 orig_to_sphere, const float radius, const vec3 c_ray)
{
    float midpoint = dot(orig_to_sphere, c_ray);

    float d = radius*radius - dot(orig_to_sphere, orig_to_sphere) + midpoint*midpoint;
    if (d <= 0)
    {
        return vec2(0, 0); // we cannot discard here because this is a multipurpose function
    }
    else
    {
        float half_depth = sqrt(d);
        /* vec2(near, far) */
        return vec2(midpoint - half_depth, midpoint + half_depth);
    }
}

vec3 model_scatter(vec3 c_ray, vec3 l_ray)
{
    vec2 slice_outer = slice_sphere(sphere_center, outer_radius, c_ray);
    vec2 slice_inner = slice_sphere(sphere_center, inner_radius, c_ray);

    float rim = min(exp(exp((slice_outer.y - slice_outer.x)*0.5) - 1) - 1, 1);
    return vec3(rim, rim, rim);
}


void main()
{
    vec3 camera_ray = normalize(vec3(camera_frustum.b * (gl_FragCoord.x - camera_shift.x) - camera_frustum.b * camera_frustum.r,
                                camera_frustum.b * (gl_FragCoord.y - camera_shift.y) - camera_frustum.b * camera_frustum.g,
                                1));

    vec2 slice = sphere_intersect(vec3(0, 0, 0), camera_ray, outer_radius);
    if (slice.x == slice.y)
    {
        discard;
    }
    slice.y = min(slice.y, sphere_intersect(vec3(0, 0, 0), camera_ray, inner_radius*0.999).x);

    if (true) //(gl_FragCoord.x > camera_frustum.x)
        color = vec4(in_scatter(camera_ray, slice), 1);
    else if (gl_FragCoord.y > camera_frustum.y)
        color = vec4(model_scatter(camera_ray, lamp_hat), 1);
    else
        color = vec4(0, 0, 0, 0);
}
