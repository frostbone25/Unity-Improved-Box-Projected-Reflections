//||||||||||||||||||||||||||||| UNITY HDRP BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| UNITY HDRP BOX PROJECTION |||||||||||||||||||||||||||||
//||||||||||||||||||||||||||||| UNITY HDRP BOX PROJECTION |||||||||||||||||||||||||||||

//SOURCE - https://github.com/Unity-Technologies/Graphics/blob/504e639c4e07492f74716f36acf7aad0294af16e/Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightEvaluation.hlsl  
//From Moving Frostbite to PBR document
//This function fakes the roughness based integration of reflection probes by adjusting the roughness value
//NOTE: Untouched from HDRP
float ComputeDistanceBaseRoughness(float distanceIntersectionToShadedPoint, float distanceIntersectionToProbeCenter, float perceptualRoughness)
{
    float newPerceptualRoughness = clamp(distanceIntersectionToShadedPoint / distanceIntersectionToProbeCenter * perceptualRoughness, 0, perceptualRoughness);
    return lerp(newPerceptualRoughness, perceptualRoughness, perceptualRoughness);
}

//SOURCE - https://github.com/Unity-Technologies/Graphics/blob/504e639c4e07492f74716f36acf7aad0294af16e/Packages/com.unity.render-pipelines.core/ShaderLibrary/GeometricTools.hlsl#L78
//This simplified version assume that we care about the result only when we are inside the box
//NOTE: Untouched from HDRP
float IntersectRayAABBSimple(float3 start, float3 dir, float3 boxMin, float3 boxMax)
{
    float3 invDir = rcp(dir);

    // Find the ray intersection with box plane
    float3 rbmin = (boxMin - start) * invDir;
    float3 rbmax = (boxMax - start) * invDir;

    float3 rbminmax = float3((dir.x > 0.0) ? rbmax.x : rbmin.x, (dir.y > 0.0) ? rbmax.y : rbmin.y, (dir.z > 0.0) ? rbmax.z : rbmin.z);

    return min(min(rbminmax.x, rbminmax.y), rbminmax.z);
}

//SOURCE - https://github.com/Unity-Technologies/Graphics/blob/504e639c4e07492f74716f36acf7aad0294af16e/Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightEvaluation.hlsl  
//return projectionDistance, can be used in ComputeDistanceBaseRoughness formula
//return in R the unormalized corrected direction which is used to fetch cubemap but also its length represent the distance of the capture point to the intersection
//Length R can be reuse as a parameter of ComputeDistanceBaseRoughness for distIntersectionToProbeCenter
//NOTE: Modified to be much simpler, and to work with the Built-In Render Pipeline (BIRP)
float EvaluateLight_EnvIntersection(float3 worldSpacePosition, inout float3 R)
{
    float projectionDistance = IntersectRayAABBSimple(worldSpacePosition, R, unity_SpecCube0_BoxMin.xyz, unity_SpecCube0_BoxMax.xyz);

    R = (worldSpacePosition + projectionDistance * R) - unity_SpecCube0_ProbePosition.xyz;

    return projectionDistance;
}