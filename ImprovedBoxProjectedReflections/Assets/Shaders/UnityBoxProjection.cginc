//||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||

//SOURCE - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardUtils.cginc
//Unity's Default Box Projection function
inline float3 UnityBoxProjectedCubemapDirectionDefault(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
    float3 nrdir = normalize(worldRefl);

    float3 rbmax = (boxMax.xyz - worldPos) / nrdir;
    float3 rbmin = (boxMin.xyz - worldPos) / nrdir;

    float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;

    worldPos -= cubemapCenter.xyz;
    worldRefl = worldPos + nrdir * min(min(rbminmax.x, rbminmax.y), rbminmax.z);

    return worldRefl;
}

//SOURCE - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardUtils.cginc
//Unity's Optimized Box Projection function
inline float3 UnityBoxProjectedCubemapDirectionOptimized(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
    float3 nrdir = normalize(worldRefl);

    float3 rbmax = (boxMax.xyz - worldPos);
    float3 rbmin = (boxMin.xyz - worldPos);

    float3 select = step(float3(0, 0, 0), nrdir);
    float3 rbminmax = lerp(rbmax, rbmin, select);
    rbminmax /= nrdir;

    worldPos -= cubemapCenter.xyz;
    worldRefl = worldPos + nrdir * min(min(rbminmax.x, rbminmax.y), rbminmax.z);

    return worldRefl;
}

//SOURCE - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardUtils.cginc
//Unity's Default Box Projection function, tweaked to output hit distance
inline float3 UnityBoxProjectedCubemapDirectionDefault(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax, out float distanceToHitPoint)
{
    float3 nrdir = normalize(worldRefl);

    float3 rbmax = (boxMax.xyz - worldPos) / nrdir;
    float3 rbmin = (boxMin.xyz - worldPos) / nrdir;

    float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;

    distanceToHitPoint = min(min(rbminmax.x, rbminmax.y), rbminmax.z);

    worldPos -= cubemapCenter.xyz;
    worldRefl = worldPos + nrdir * distanceToHitPoint;

    return worldRefl;
}

//SOURCE - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardUtils.cginc
//Unity's Optimized Box Projection function, tweaked to output hit distance
inline float3 UnityBoxProjectedCubemapDirectionOptimized(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax, out float distanceToHitPoint)
{
    float3 nrdir = normalize(worldRefl);

    float3 rbmax = (boxMax.xyz - worldPos);
    float3 rbmin = (boxMin.xyz - worldPos);

    float3 select = step(float3(0, 0, 0), nrdir);
    float3 rbminmax = lerp(rbmax, rbmin, select);
    rbminmax /= nrdir;

    distanceToHitPoint = min(min(rbminmax.x, rbminmax.y), rbminmax.z);

    worldPos -= cubemapCenter.xyz;
    worldRefl = worldPos + nrdir * distanceToHitPoint;

    return worldRefl;
}