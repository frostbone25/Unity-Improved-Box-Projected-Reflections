/*
* https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl
* https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonLighting.hlsl
* https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
* https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl
*/

#define FLT_EPS  5.960464478e-8

uint BitFieldInsert(uint mask, uint src, uint dst)
{
    return (src & mask) | (dst & ~mask);
}

float CopySign(float x, float s, bool ignoreNegZero = true)
{
    if (ignoreNegZero)
    {
        return (s >= 0) ? abs(x) : -abs(x);
    }
    else
    {
        uint negZero = 0x80000000u;
        uint signBit = negZero & asuint(s);
        return asfloat(BitFieldInsert(negZero, signBit, asuint(x)));
    }
}

float FastSign(float s, bool ignoreNegZero = true)
{
    return CopySign(1.0, s, ignoreNegZero);
}

float3x3 GetLocalFrame(float3 localZ)
{
    float x = localZ.x;
    float y = localZ.y;
    float z = localZ.z;
    float sz = FastSign(z);
    float a = 1 / (sz + z);
    float ya = y * a;
    float b = x * ya;
    float c = x * sz;

    float3 localX = float3(c * x * a - 1, sz * b, c);
    float3 localY = float3(b, y * ya - sz, y);

    return float3x3(localX, localY, localZ);
}

void SampleAnisoGGXVisibleNormal(float2 u,
    float3 V,
    float3x3 localToWorld,
    float roughnessX,
    float roughnessY,
    out float3 localV,
    out float3 localH,
    out float  VdotH)
{
    localV = mul(V, transpose(localToWorld));

    // Construct an orthonormal basis around the stretched view direction
    float3 N = normalize(float3(roughnessX * localV.x, roughnessY * localV.y, localV.z));
    float3 T = (N.z < 0.9999) ? normalize(cross(float3(0, 0, 1), N)) : float3(1, 0, 0);
    float3 B = cross(N, T);

    // Compute a sample point with polar coordinates (r, phi)
    float r = sqrt(u.x);
    float phi = 2.0 * UNITY_PI * u.y;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + N.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

    // Reproject onto hemisphere
    localH = t1 * T + t2 * B + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * N;

    // Transform the normal back to the ellipsoid configuration
    localH = normalize(float3(roughnessX * localH.x, roughnessY * localH.y, max(0.0, localH.z)));

    VdotH = saturate(dot(localV, localH));
}

// GGX VNDF via importance sampling
half3 ImportanceSampleGGX_VNDF(float2 random, half3 normalWS, half3 viewDirWS, half roughness, out bool valid)
{
    half3x3 localToWorld = GetLocalFrame(normalWS);

    half VdotH;
    half3 localV, localH;
    SampleAnisoGGXVisibleNormal(random, viewDirWS, localToWorld, roughness, roughness, localV, localH, VdotH);

    // Compute the reflection direction
    half3 localL = 2.0 * VdotH * localH - localV;
    half3 outgoingDir = mul(localL, localToWorld);

    half NdotL = dot(normalWS, outgoingDir);

    valid = (NdotL >= 0.001);

    return outgoingDir;
}

// A single iteration of Bob Jenkins' One-At-A-Time hashing algorithm.
uint JenkinsHash(uint x)
{
    x += (x << 10u);
    x ^= (x >> 6u);
    x += (x << 3u);
    x ^= (x >> 11u);
    x += (x << 15u);
    return x;
}

uint JenkinsHash(uint2 v)
{
    return JenkinsHash(v.x ^ JenkinsHash(v.y));
}

uint JenkinsHash(uint3 v)
{
    return JenkinsHash(v.x ^ JenkinsHash(v.yz));
}

uint JenkinsHash(uint4 v)
{
    return JenkinsHash(v.x ^ JenkinsHash(v.yzw));
}

float ConstructFloat(int m) {
    const int ieeeMantissa = 0x007FFFFF; // Binary FP32 mantissa bitmask
    const int ieeeOne = 0x3F800000; // 1.0 in FP32 IEEE

    m &= ieeeMantissa;                   // Keep only mantissa bits (fractional part)
    m |= ieeeOne;                        // Add fractional part to 1.0

    float  f = asfloat(m);               // Range [1, 2)
    return f - 1;                        // Range [0, 1)
}

float ConstructFloat(uint m)
{
    return ConstructFloat(asint(m));
}

float GenerateHashedRandomFloat(uint x)
{
    return ConstructFloat(JenkinsHash(x));
}

float GenerateHashedRandomFloat(uint2 v)
{
    return ConstructFloat(JenkinsHash(v));
}

float GenerateHashedRandomFloat(uint3 v)
{
    return ConstructFloat(JenkinsHash(v));
}

float GenerateHashedRandomFloat(uint4 v)
{
    return ConstructFloat(JenkinsHash(v));
}

float GenerateRandomFloat(float2 screenUV)
{
    _Seed += 1.0;
    return GenerateHashedRandomFloat(uint3(screenUV * _ScreenParams.xy, _Seed));
}