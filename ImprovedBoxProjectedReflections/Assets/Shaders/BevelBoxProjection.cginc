//||||||||||||||||||||||||||||| BEVELED BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| BEVELED BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| BEVELED BOX PROJECTION |||||||||||||||||||||||||||||
// stolen from - https://iquilezles.org/articles/intersectors/
// axis aligned box centered at the origin, with dimensions "size" and extruded by "rad"
// NOTE: This is a modified version meant to be tracing inside of the box.
float roundedboxIntersectFlipped(float3 ro, float3 rd, float3 size, float rad)
{
    // bounding box
    float3 m = 1.0 / rd;
    float3 n = m * ro;
    float3 k = abs(m) * (size + rad);
    float3 t1 = -n - k;
    float3 t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);

    if (tN > tF || tF < 0.0)
        return -1.0;

    float t = tF;

    // convert to first octant
    float3 pos = ro + t * rd;
    float3 s = sign(pos);
    ro *= s;
    rd *= s;
    pos *= s;

    // faces
    pos -= size;
    pos = max(pos.xyz, pos.yzx);

    if (min(min(pos.x, pos.y), pos.z) < 0.0)
        return t;

    // some precomputation
    float3 oc = ro - size;
    float3 dd = rd * rd;
    float3 oo = oc * oc;
    float3 od = oc * rd;
    float ra2 = rad * rad;

    t = 1e20;

    // edge X
    {
        float a = dd.y + dd.z;
        float b = od.y + od.z;
        float c = oo.y + oo.z - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b + sqrt(h)) / a;

            if (h > 0.0 && h < t && abs(ro.x + rd.x * h) < size.x)
                t = h;
        }
    }
    // edge Y
    {
        float a = dd.z + dd.x;
        float b = od.z + od.x;
        float c = oo.z + oo.x - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b + sqrt(h)) / a;

            if (h > 0.0 && h < t && abs(ro.y + rd.y * h) < size.y)
                t = h;
        }
    }
    // Edge Z
    {
        float a = dd.x + dd.y;
        float b = od.x + od.y;
        float c = oo.x + oo.y - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b + sqrt(h)) / a;

            if (h > 0.0 && h < t && abs(ro.z + rd.z * h) < size.z)
                t = h;
        }
    }
    // corner
    {
        float b = od.x + od.y + od.z;
        float c = oo.x + oo.y + oo.z - ra2;
        float h = b * b - c;

        if (h > 0.0)
            t = -b + sqrt(h);
    }

    if (t > 1e19)
        t = -1.0;

    return t;
}

inline float3 ModifiedBoxProjectedCubemapDirection(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax, out float fa, float factor)
{
    #if defined (_EXPERIMENTAL_BEVELED_BOX_OFFSET)
        boxMax.xyz = boxMax.xyz - float3(factor, factor, factor);
        boxMin.xyz = boxMin.xyz + float3(factor, factor, factor);
    #endif

    worldPos -= cubemapCenter.xyz;

    float intersectionTest = roundedboxIntersectFlipped(worldPos, worldRefl, (boxMax - boxMin) * 0.5, factor);
    fa = intersectionTest;

    float3 nrdir = normalize(worldRefl);
    float3 modifiedWorldRefl = worldPos + nrdir * intersectionTest;

    return modifiedWorldRefl;
}