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
    return normalize(vec3(-0.07735027, 0.10, -0.57735027));
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
// MAIN SKY FUNCTION //
///////////////////////
void sky() {
    Ray ray;
    ray.origin = POSITION;
    ray.dir = EYEDIR;

    if (ray.dir.y >= 0.0) {
        vec3 atmosphere = extra_cheap_atmosphere(ray.dir, getSunDirection()) * 0.5;
        float sun = pow(max(0.0, dot(ray.dir, getSunDirection())), 720.0) * 210.0;
        COLOR = mix(atmosphere + sun, vec3(0.0), 0.5); // Remove clouds and make sky simpler
        ALPHA = 1.0;
    } else {
        float dist = getWater(ray.origin, ray.dir);
        vec3 hit = ray.origin + ray.dir * dist;
        vec3 n = normal_func(hit.xz, 0.01, WATER_DEPTH);
        n = mix(n, vec3(0.0, 1.0, 0.0), 0.7 * min(1.0, sqrt(dist * 0.01) * 1.1));
        vec3 r = normalize(reflect(ray.dir, n));
        r.y = abs(r.y);
        vec3 reflection = extra_cheap_atmosphere(r, getSunDirection()) * 0.5;
        float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - max(0.0, dot(-n, ray.dir)), 5.0);
        fresnel = round(fresnel * 5.0) / 5.0;
        vec3 col = mix(vec3(0.06, 0.1, 0.3), reflection, fresnel);
        COLOR = col;
        ALPHA = 1.0;
    }
}
