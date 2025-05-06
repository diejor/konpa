shader_type sky;

// Uniforms you can adjust (or set from your scene)
uniform vec2 iMouse = vec2(0.0); // You can use this to control clouds if desired.
uniform vec2 iResolution = vec2(1152.0, 648.0); // Set your desired resolution.

// Utility functions
mat2 rotate(float a) {
    float c = cos(a), s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

struct Ray {
    vec3 origin;
    vec3 dir;
};

///////////////////////
// OCEAN FUNCTIONS   //
// adapted from afl_ext (Shadertoy)
///////////////////////
#define DRAG_MULT 0.8 // how much waves pull on the water
#define WATER_DEPTH 0.6 // water depth
#define ITERATIONS_RAYMARCH 3 // iterations for raymarching waves
#define ITERATIONS_NORMAL 6 // iterations for normals

vec2 wavedx(vec2 position, vec2 direction, float frequency, float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float wave = exp(sin(x) - 1.0);
    float dx = wave * cos(x);
    return vec2(wave, -dx);
}

float getwaves(vec2 position, int iterations) {
    float wavePhaseShift = length(position) * 0.1; // avoid same phase everywhere
    float iter = 0.0;
    float frequency = 1.0;
    float timeMultiplier = 2.0;
    float weight = 1.0;
    float sumOfValues = 0.0;
    float sumOfWeights = 0.0;
    for (int i = 0; i < iterations; i++) {
        vec2 p = vec2(sin(iter), cos(iter));
        vec2 res = wavedx(position, p, frequency, TIME * timeMultiplier + wavePhaseShift);
        position += p * res.y * weight * DRAG_MULT;
        sumOfValues += res.x * weight;
        sumOfWeights += weight;
        weight = mix(weight, 0.0, 0.2);
        frequency *= 1.18;
        timeMultiplier *= 1.07;
        iter += 1232.399963;
    }
    return sumOfValues / sumOfWeights;
}

float watermarch(vec3 camera, vec3 start, vec3 end, float depth) {
    vec3 pos = start;
    vec3 dir = normalize(end - start);
    for (int i = 0; i < 64; i++) {
        float height = getwaves(pos.xz, ITERATIONS_RAYMARCH) * depth - depth;
        if(height + 0.01 > pos.y)
            return distance(pos, camera);
        pos += dir * (pos.y - height);
    }
    return distance(start, camera);
}

vec3 normal_func(vec2 pos, float e, float depth) {
    vec2 ex = vec2(e, 0.0);
    float H = getwaves(pos.xy, ITERATIONS_NORMAL) * depth;
    vec3 a = vec3(pos.x, H, pos.y);
    return normalize(
        cross(
            a - vec3(pos.x - e, getwaves(pos.xy - ex.xy, ITERATIONS_NORMAL) * depth, pos.y),
            a - vec3(pos.x, getwaves(pos.xy + ex.yx, ITERATIONS_NORMAL) * depth, pos.y + e)
        )
    );
}

float intersectPlane(vec3 origin, vec3 direction, vec3 point, vec3 norm) {
    return clamp(dot(point - origin, norm) / dot(direction, norm), -1.0, 9991999.0);
}

vec3 extra_cheap_atmosphere(vec3 raydir, vec3 sundir) {
    sundir.y = max(sundir.y, -0.07);
    float special_trick = 1.0 / (raydir.y + 0.1);
    float special_trick2 = 1.0 / (sundir.y * 11.0 + 1.0);
    float raysundt = pow(abs(dot(sundir, raydir)), 2.0);
    vec3 suncolor = mix(vec3(1.0), max(vec3(0.0), vec3(1.0) - vec3(5.5, 13.0, 22.4) / 22.4), special_trick2);
    vec3 bluesky = (vec3(5.5, 13.0, 22.4) / 22.4) * suncolor;
    vec3 bluesky2 = max(vec3(0.0), bluesky - vec3(5.5, 13.0, 22.4) * 0.000 * (special_trick - 6.0 * sundir.y * sundir.y));
    bluesky2 *= 1.5 + 0.0 * special_trick * (0.1 + raysundt * 0.1);
    return bluesky2 * (1.0 + 0.5 * pow(1.0 - raydir.y, 2.0));
}

vec3 getSunDirection() {
    return normalize(vec3(-0.07735027, 0.25, -0.57735027));
}

float getWater(vec3 origin, vec3 dir) {
    // Set water level to y = 1.
    vec3 waterPlaneHigh = vec3(0.0, 1.0, 0.0);
    vec3 waterPlaneLow  = vec3(0.0, 1.0 - WATER_DEPTH, 0.0);
    float highPlaneHit = intersectPlane(origin, dir, waterPlaneHigh, vec3(0.0, 1.0, 0.0));
    float lowPlaneHit  = intersectPlane(origin, dir, waterPlaneLow, vec3(0.0, 1.0, 0.0));
    vec3 highHitPos = origin + dir * highPlaneHit;
    vec3 lowHitPos  = origin + dir * lowPlaneHit;
    return watermarch(origin, highHitPos, lowHitPos, WATER_DEPTH);
}

///////////////////////
// CLOUD FUNCTIONS   //
///////////////////////
// Spiral noise from Shadertoy (modified for 3D)
const float nudge = 0.739513;
const float normalizer = 1.0 / sqrt(1.0 + nudge * nudge);
float SpiralNoiseC(vec3 p) {
    float n = 0.0;
    float iter = 1.0;
    for (int i = 0; i < 6; i++) {
        vec3 spin = sin(p * iter);
        n += -abs(spin.x + spin.y + spin.z) / iter;
        p.xy += vec2(p.y, -p.x) * nudge;
        p.xy *= normalizer;
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        iter *= 1.733733;
    }
    return n;
}

const float cloudHeight = 2.0;
float getCloud(vec3 pos, float height, vec2 resolution) {
    float cloudNoise = SpiralNoiseC(pos * 0.5);
    float heightFalloff = max(pow(pos.y - height, 0.8), 0.0) * 0.1;
    float coverage = 0.2 * (iMouse.y / resolution.y);
    if(iMouse.x + iMouse.y == 0.0)
        coverage = 0.4;
    cloudNoise = cloudNoise * 0.05 + coverage + heightFalloff + sin(TIME * 0.0005) * 0.1;
    return max(cloudNoise, -pos.y + height + 1.0);
}

vec3 cloudNormal(vec3 pos, float height, vec2 resolution) {
    float e = 0.01;
    return normalize(vec3(
        getCloud(pos + vec3(e, 0.0, 0.0), height, resolution) - getCloud(pos - vec3(e, 0.0, 0.0), height, resolution),
        getCloud(pos + vec3(0.0, e, 0.0), height, resolution) - getCloud(pos - vec3(0.0, e, 0.0), height, resolution),
        getCloud(pos + vec3(0.0, 0.0, e), height, resolution) - getCloud(pos - vec3(0.0, 0.0, e), height, resolution)
    ));
}

vec4 cloudmarch(Ray ray, vec2 resolution) {
    vec3 shift = vec3(TIME * 0.05, 0.0, TIME * 0.1);
    float dist = (1.0 + cloudHeight) / ray.dir.y;
    for (int i = 0; i < 256; i++) {
        if(dist > 50.0)
            break;
        vec3 pos = ray.origin + ray.dir * dist;
        float cloud = getCloud(pos + shift, ray.origin.y + cloudHeight, resolution);
        if(cloud < 0.0) {
            vec3 n = cloudNormal(pos + shift, ray.origin.y + cloudHeight, resolution);
            vec3 sundir = getSunDirection();
            float diffuse = smoothstep(0.69, 0.71, max(0.0, dot(n, sundir)));
            return vec4(vec3((float(i)/100.0)*0.1 + diffuse * 0.5 + 0.75), 1.0);
        }
        dist += max(cloud, 0.01);
    }
    return vec4(0.0);
}

vec3 getSky(Ray ray, vec2 resolution) {
    vec3 atmosphere = extra_cheap_atmosphere(ray.dir, getSunDirection()) * 0.5;
    float sun = pow(max(0.0, dot(ray.dir, getSunDirection())), 720.0) * 210.0;
    vec4 clouds = cloudmarch(ray, resolution);
    return mix(min(atmosphere + sun, 1.0), clouds.xyz, pow(clouds.a, 3.0));
}

///////////////////////
// MAIN SKY FUNCTION //
///////////////////////
// In a sky shader, the built-ins POSITION and EYEDIR give the camera's world position and the viewing direction.
// We construct a ray from these, then choose to render sky or water based on the ray direction.
void sky() {
    Ray ray;
    ray.origin = POSITION;
    ray.dir = EYEDIR;

    if (ray.dir.y >= 0.0) {
        COLOR = getSky(ray, iResolution);
        ALPHA = 1.0;
    } else {
        float dist = getWater(ray.origin, ray.dir);
        vec3 hit = ray.origin + ray.dir * dist;
        vec3 n = normal_func(hit.xz, 0.01, WATER_DEPTH);
        n = mix(n, vec3(0.0, 1.0, 0.0), 0.7 * min(1.0, sqrt(dist * 0.01) * 1.1));
        vec3 r = normalize(reflect(ray.dir, n));
        r.y = abs(r.y);
        vec3 reflection = getSky(Ray(hit, r), iResolution);
        float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - max(0.0, dot(-n, ray.dir)), 5.0);
        fresnel = round(fresnel * 5.0) / 5.0;
        vec3 scattering = vec3(0.0293, 0.0698, 0.1717) * 0.5 * (0.5 + (hit.y + WATER_DEPTH) / WATER_DEPTH);
        vec3 col = mix(vec3(0.06, 0.1, 0.3), reflection, fresnel) + scattering;
        COLOR = col;
        ALPHA = 1.0;
    }
}
