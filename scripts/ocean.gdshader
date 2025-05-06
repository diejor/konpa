shader_type sky;

// ————— Uniforms —————
uniform vec2 iMouse = vec2(0.0);
uniform vec2 iResolution = vec2(1152.0, 648.0);
uniform vec3 CLOUD_SPEED = vec3(0.1, 0.0, 0.05);

// ————— Constants —————
const float DRAG_MULT           = 0.8;
const float WATER_DEPTH         = 0.6;
const int   ITER_RAYMARCH       = 3;
const int   ITER_NORMAL         = 6;

// Precomputed sun direction (normalize(vec3(-0.07735027,0.25,-0.57735027)))
const vec3  SUN_DIR             = vec3(-0.122052, 0.394384, -0.911438);

// Base sky color after all atmosphere math and a 1.5× boost
const vec3  BASE_SKY            = vec3(0.3516, 0.7761, 1.2191);



// ————— Ocean functions —————
vec2 wavedx(vec2 pos, vec2 dir, float freq, float ts) {
    float x = dot(dir, pos)*freq + ts;
    float w = exp(sin(x)-1.0);
    return vec2(w, -w*cos(x));
}

float getWaves(vec2 p, int iters) {
    float phase = length(p)*0.1;
    float freq=1.0, tm=2.0, w=1.0;
    float sumV=0.0, sumW=0.0;
    for(int i=0;i<iters;i++){
        vec2 d = vec2(sin(float(i)), cos(float(i)));
        vec2 r = wavedx(p, d, freq, TIME*tm + phase);
        p += d * r.y * w * DRAG_MULT;
        sumV += r.x * w;
        sumW += w;
        w = mix(w,0.0,0.2);
        freq *= 1.18;
        tm   *= 1.07;
    }
    return sumV/sumW;
}

float raymarchWater(vec3 cam, vec3 start, vec3 end, float depth){
    vec3 pos=start, dir=normalize(end-start);
    for(int i=0;i<64;i++){
        float h = getWaves(pos.xz, ITER_RAYMARCH)*depth - depth;
        if(h + 0.01 > pos.y)
            return distance(pos, cam);
        pos += dir*(pos.y - h);
    }
    return distance(start, cam);
}

vec3 getNormal(vec2 p, float e, float depth){
    float H = getWaves(p, ITER_NORMAL)*depth;
    vec3 a = vec3(p.x, H, p.y);
    vec3 nx = vec3(p.x-e, getWaves(p - vec2(e,0), ITER_NORMAL)*depth, p.y);
    vec3 nz = vec3(p.x, getWaves(p + vec2(0,e), ITER_NORMAL)*depth, p.y+e);
    return normalize(cross(a - nx, a - nz));
}

float intersectPlane(vec3 o, vec3 d, vec3 pt, vec3 n){
    return clamp(dot(pt-o,n)/dot(d,n), -1.0, 1e6);
}

float getWaterDistance(vec3 o, vec3 d){
    // y = 1 plane
    float hi = intersectPlane(o,d, vec3(0,1,0), vec3(0,1,0));
    float lo = intersectPlane(o,d, vec3(0,1.0-WATER_DEPTH,0), vec3(0,1,0));
    return raymarchWater(o, o + d*hi, o + d*lo, WATER_DEPTH);
}

// ————— Cloud functions —————
const float NUDGE = 0.739513;
const float NORM  = 1.0 / sqrt(1.0 + NUDGE*NUDGE);

float spiralNoise(vec3 p){
    float n=0.0, it=1.0;
    for(int i=0;i<6;i++){
        vec3 s = sin(p*it);
        n += -abs(s.x + s.y + s.z)/it;
        p.xy = (p.xy + vec2(p.y,-p.x)*NUDGE)*NORM;
        p.xz = (p.xz + vec2(p.z,-p.x)*NUDGE)*NORM;
        it *= 1.733733;
    }
    return n;
}

float getCloudVal(vec3 p, float h){
    float c = spiralNoise(p*0.5);
    float fall = max(pow(p.y - h,0.8),0.0)*0.1;
    float cov = (iMouse.x + iMouse.y == 0.0) 
              ? 0.4 
              : 0.2*(iMouse.y/iResolution.y);
    return max(c*0.05 + cov + fall + sin(TIME*0.0005)*0.1,
               -p.y + h + 1.0);
}

vec3 cloudNormal(vec3 p, float h){
    float e=0.01;
    return normalize(vec3(
        getCloudVal(p+vec3(e,0,0),h) - getCloudVal(p-vec3(e,0,0),h),
        getCloudVal(p+vec3(0,e,0),h) - getCloudVal(p-vec3(0,e,0),h),
        getCloudVal(p+vec3(0,0,e),h) - getCloudVal(p-vec3(0,0,e),h)
    ));
}

vec4 marchClouds(vec3 o, vec3 dir){
    // drift clouds over time
    vec3 shift = CLOUD_SPEED * TIME;
    float d = (1.0 + 2.0)/dir.y; // cloudHeight = 2.0
    for(int i=0;i<256;i++){
        if(d>50.0) break;
        vec3 p = o + dir*d + shift;
        float g = getCloudVal(p, o.y + 2.0);
        if(g < 0.0){
            vec3 n = cloudNormal(p - shift, o.y + 2.0);
            float diff = smoothstep(0.69,0.71, max(0.0,dot(n,SUN_DIR)));
            return vec4(vec3(float(i)*0.001 + diff*0.5 + 0.75),1.0);
        }
        d += max(g,0.01);
    }
    return vec4(0.0);
}

// ————— Sky & main —————
vec3 getSkyColor(vec3 dir){
    // simplified atmosphere
    return BASE_SKY * (1.0 + 0.5 * pow(1.0 - dir.y, 2.0));
}

void sky(){
    vec3 o = POSITION;
    vec3 d = EYEDIR;

    if(d.y >= 0.0){
        // sky
        float sun = pow(max(dot(d, SUN_DIR), 0.0), 720.0) * 210.0;
        vec4 cl = marchClouds(o, d);
        vec3 skyCol = mix(min(getSkyColor(d) + sun, vec3(1.0)), cl.xyz, pow(cl.a,3.0));
        COLOR = skyCol;
    } else {
        // water
        float dist = getWaterDistance(o, d);
        vec3 hit = o + d * dist;
        vec3 n   = getNormal(hit.xz, 0.01, WATER_DEPTH);
        n = mix(n, vec3(0,1,0), 0.7 * min(1.0, sqrt(dist*0.01) * 1.1));
        vec3 refl = normalize(reflect(d, n));
        refl.y = abs(refl.y);
        vec3 R = getSkyColor(refl);
        float F = round((0.04 + (1.0 - 0.04) * pow(1.0 - max(dot(-n,d),0.0),5.0))*5.0)/5.0;
        vec3 scatter = vec3(0.0293,0.0698,0.1717)*0.5*(0.5 + (hit.y+WATER_DEPTH)/WATER_DEPTH);
        COLOR = mix(vec3(0.06,0.1,0.3), R, F) + scatter;
    }
    ALPHA = 1.0;
}
