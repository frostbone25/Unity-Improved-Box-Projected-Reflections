        Shader "ImprovedBoxProjectedReflections"
{
    Properties
    {
        [HideInInspector] _Seed("_Seed", Float) = 0

        [Header(Material)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.75
        _BumpScale("Normal Strength", Float) = 1
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        [Header(Cubemap Rendering Type)]
        [KeywordEnum(None, Approximated, ApproximatedHDRP, Raytracing)] _ReflectionRenderingType("Contact Hardening Type", Float) = 1

        [Header(Approximated)]
        [Toggle(_APPROXIMATED_CLAMP)] _ApproximationClamp("Clamp Mip Offset On Approximation", Float) = 1

        [Header(Raytracing)]
        [Toggle(_DETERMINISTIC_SAMPLING)] _UseDeterministicSampling("Use Deterministic Sampling", Float) = 0
        _Samples("Samples", Float) = 16

        //using precomputed blue noise 3D texture with different variations on each slice
        _BlueNoise("Blue Noise", 3D) = "white" {}
        _BlueNoiseMaxSlices("Blue Noise Max Slices", Float) = 64

        [Toggle(_WHITE_NOISE)] _WhiteNoise("Use White Noise", Float) = 1
        [Toggle(_ANIMATE_NOISE)] _AnimateNoise("Animate Noise", Float) = 0
        [Toggle(_RAYTRACE_MIP_OFFSET)] _EnableMipOffsetForRaytracing("Use Mip Offset During Raytracing", Float) = 0

        [Header(Experimental)]
        [Toggle(_EXPERIMENTAL_2X2_BLUR)] _Enable2x2Blur("Use Quad Intrinsics 2x2 Blur", Float) = 0
        [Toggle(_EXPERIMENTAL_BEVELED_BOX_PROJECTION)] _EnableBevelBoxProjection("Use Beveled Box Projection", Float) = 0
        [Toggle(_EXPERIMENTAL_BEVELED_BOX_OFFSET)] _BevelBoxOffset("Use Bevel Factor Offset", Float) = 0
        _BevelFactor("Bevel Factor", Float) = 0
        [Toggle(_EXPERIMENTAL_BOX_SPECULAR_OCCLUSION)] _EnableBoxSpecularOcclusion("Use Box Based Specular Occlusion", Float) = 0
        _ExperimentalSpecularOcclusionIntensity("Occlusion Intensity", Range(0, 1)) = 1
        _ExperimentalSpecularOcclusionMultiplier("Occlusion Multiplier", Float) = 1
        _ExperimentalSpecularOcclusionPower("Occlusion Power", Float) = 1
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
        }

        Pass
        {
            Name "ImprovedBoxProjectedReflections_ForwardBase"

            Tags
            { 
                "LightMode" = "ForwardBase" 
            }

            CGPROGRAM
            #pragma vertex vertex_forward_base
            #pragma fragment fragment_forward_base

            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D KEYWORDS |||||||||||||||||||||||||||||

            //NOTE: This is here only because of Quad Intrinsics
            #pragma target 5.0

            #pragma fragmentoption ARB_precision_hint_fastest

            #pragma multi_compile_fwdbase

            #pragma multi_compile _ UNITY_SPECCUBE_BOX_PROJECTION

            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM KEYWORDS |||||||||||||||||||||||||||||

            #pragma multi_compile _REFLECTIONRENDERINGTYPE_NONE _REFLECTIONRENDERINGTYPE_APPROXIMATED _REFLECTIONRENDERINGTYPE_APPROXIMATEDHDRP _REFLECTIONRENDERINGTYPE_RAYTRACING

            #pragma shader_feature_local _APPROXIMATED_CLAMP
            #pragma shader_feature_local _DETERMINISTIC_SAMPLING
            #pragma shader_feature_local _WHITE_NOISE
            #pragma shader_feature_local _ANIMATE_NOISE
            #pragma shader_feature_local _RAYTRACE_MIP_OFFSET
            #pragma shader_feature_local _EXPERIMENTAL_BEVELED_BOX_PROJECTION
            #pragma shader_feature_local _EXPERIMENTAL_BEVELED_BOX_OFFSET
            #pragma shader_feature_local _EXPERIMENTAL_2X2_BLUR
            #pragma shader_feature_local _EXPERIMENTAL_BOX_SPECULAR_OCCLUSION

            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||

            //BUILT IN RENDER PIPELINE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShadowLibrary.cginc"
            #include "UnityLightingCommon.cginc"
            #include "UnityStandardBRDF.cginc"

            //||||||||||||||||||||||||||||| CUSTOM INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM INCLUDES |||||||||||||||||||||||||||||

            #include "UnityBoxProjection.cginc"
            #include "BevelBoxProjection.cginc"
            #include "HDRPBoxProjection.cginc"
            #include "ReflectionTracing.cginc"
            #include "QuadIntrinsics.cginc"

            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| SHADER PARAMETERS |||||||||||||||||||||||||||||

            sampler2D _BumpMap;
            float4 _BumpMap_ST; //(X = Tiling X | Y = Tiling Y | Z = Offset X | W = Offset Y)

            float _BumpScale;

            float _Smoothness;

            float _BevelFactor;

            float _Samples;

            sampler3D _BlueNoise;
            int _BlueNoiseMaxSlices;
            float4 _BlueNoise_TexelSize; //(X = 1 / Width | Y = 1 / Height | Z = Width | W = Height)

            float _ExperimentalSpecularOcclusionIntensity;
            float _ExperimentalSpecularOcclusionMultiplier;
            float _ExperimentalSpecularOcclusionPower;

            //||||||||||||||||||||||||||||| CUSTOM FUNCTIONS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM FUNCTIONS |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| CUSTOM FUNCTIONS |||||||||||||||||||||||||||||

            //SOURCE - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityImageBasedLighting.cginc
            //Unity's function for mapping perceptual roughness to a cubemap mipmap level
            //UNITY_SPECCUBE_LOD_STEPS is located in UnityStandardConfig.cginc - https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityStandardConfig.cginc
            //UNITY_SPECCUBE_LOD_STEPS is defined as 6
            half UnityPerceptualRoughnessToMipmapLevel(half perceptualRoughness)
            {
                return perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;
            }

            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| MESH DATA STRUCT |||||||||||||||||||||||||||||

            struct meshData
            {
                float4 vertex : POSITION;   //Vertex Position (X = Position X | Y = Position Y | Z = Position Z | W = 1)
                float3 normal : NORMAL;     //Normal Direction [-1..1] (X = Direction X | Y = Direction Y | Z = Direction)
                float4 tangent : TANGENT;   //Tangent Direction [-1..1] (X = Direction X | Y = Direction Y | Z = Direction)
                float2 uv0 : TEXCOORD0;     //Mesh UVs [0..1] (X = U | Y = V)

                UNITY_VERTEX_INPUT_INSTANCE_ID //Instancing
            };

            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT DATA STRUCT |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX TO FRAGMENT DATA STRUCT |||||||||||||||||||||||||||||

            struct vertexToFragment
            {
                float4 vertexCameraClipPosition : SV_POSITION; //Vertex Position In Camera Clip Space
                float2 uv0 : TEXCOORD0;                        //UV0 Texture Coordinates
                float4 vertexWorldPosition : TEXCOORD1;        //Vertex World Space Position 
                float3 tangentSpace0 : TEXCOORD2; //tangent space 0
                float3 tangentSpace1 : TEXCOORD3; //tangent space 1
                float3 tangentSpace2 : TEXCOORD4; //tangent space 2
                float4 screenPos : TEXCOORD5;

                UNITY_VERTEX_OUTPUT_STEREO //Instancing
            };

            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| VERTEX FUNCTION |||||||||||||||||||||||||||||

            vertexToFragment vertex_forward_base(meshData data)
            {
                vertexToFragment vertex;

                //Instancing
                UNITY_SETUP_INSTANCE_ID(data);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, vertex);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(vertex);

                //transforms a point from object space to the camera's clip space
                vertex.vertexCameraClipPosition = UnityObjectToClipPos(data.vertex);

                //this is a common way of getting texture coordinates, and transforming them with tiling/offsets from _BumpMap.
                vertex.uv0 = TRANSFORM_TEX(data.uv0, _BumpMap);

                //define our world position vector
                vertex.vertexWorldPosition = mul(unity_ObjectToWorld, data.vertex);

                //compute the world normal
                float3 worldNormal = UnityObjectToWorldNormal(normalize(data.normal));

                //the tangents of the mesh
                float3 worldTangent = UnityObjectToWorldDir(data.tangent.xyz);

                //compute the tangent sign
                float tangentSign = data.tangent.w * unity_WorldTransformParams.w;

                //compute bitangent from cross product of normal and tangent
                float3 worldBiTangent = cross(worldNormal, worldTangent) * tangentSign;

                //output the tangent space matrix
                vertex.tangentSpace0 = float3(worldTangent.x, worldBiTangent.x, worldNormal.x);
                vertex.tangentSpace1 = float3(worldTangent.y, worldBiTangent.y, worldNormal.y);
                vertex.tangentSpace2 = float3(worldTangent.z, worldBiTangent.z, worldNormal.z);

                //compute screen position for sampling noise for the traced reflection variant
                vertex.screenPos = UnityStereoTransformScreenSpaceTex(ComputeScreenPos(vertex.vertexCameraClipPosition));

                return vertex;
            }

            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| FRAGMENT FUNCTION |||||||||||||||||||||||||||||

            fixed4 fragment_forward_base(vertexToFragment vertex) : SV_Target
            {
                //setup for a janky 2x2 quad intrinsics blur if desired
                #if defined (_EXPERIMENTAL_2X2_BLUR)
                    SETUP_QUAD_INTRINSICS(vertex.vertexCameraClipPosition)
                #endif

                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| VECTORS |||||||||||||||||||||||||||||||

                float2 vector_uv = vertex.uv0; //uvs for sampling regular textures (texcoord0)
                float3 vector_worldPosition = vertex.vertexWorldPosition.xyz; //world position vector
                float3 vector_viewPosition = _WorldSpaceCameraPos.xyz - vector_worldPosition; //camera world position
                float3 vector_viewDirection = normalize(vector_viewPosition); //camera world position direction

                //sample our normal map texture
                float3 texture_normalMap = UnpackNormalWithScale(tex2D(_BumpMap, vector_uv), _BumpScale);

                //calculate our normals with the normal map into consideration
                float3 vector_normalDirection = float3(dot(vertex.tangentSpace0, texture_normalMap.xyz), dot(vertex.tangentSpace1, texture_normalMap.xyz), dot(vertex.tangentSpace2, texture_normalMap.xyz));

                //normalize the vector so it stays in a -1..1 range
                vector_normalDirection = normalize(vector_normalDirection);

                //our final environment reflection, which will be assigned shortly...
                float4 enviormentReflection = float4(0, 0, 0, 0);

                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: NONE |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: NONE |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: NONE |||||||||||||||||||||||||||||||
                //This is the classic method of sampling box projected cubemap reflections.
                //The reflection cubemap is sampled at a given mip level, and projected against the bounding box of the reflection probe.
                #if defined (_REFLECTIONRENDERINGTYPE_NONE)
                    //compute reflection vector
                    float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                    #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                        vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, _BevelFactor);
                    #else
                        vector_reflectionDirection = UnityBoxProjectedCubemapDirectionDefault(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                    #endif

                    //remap our smoothness parameter to PBR roughness
                    float perceptualRoughness = 1.0 - _Smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    //compute the cubemap mip level based on perceptual roughness
                    float mip = UnityPerceptualRoughnessToMipmapLevel(perceptualRoughness);

                    //sample the environment reflection
                    enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                    //decode the environment reflection if it's HDR encoded
                    enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);

                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION |||||||||||||||||||||||||||||||
                //This is my old approximation method I stumbled upon.
                //It uses effectively the same box projected function as Unity does, except the intersection test between the current fragment and the bounds of the box is output.
                //This value is then used to arbitrarily offset the mip level when sampling the reflection cubemap.
                //The further the distance, the higher (and blurrier) the mip level of the reflection gets.
                #elif defined (_REFLECTIONRENDERINGTYPE_APPROXIMATED)
                    //compute reflection vector
                    float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    //remap our smoothness parameter to PBR roughness
                    float perceptualRoughness = 1.0 - _Smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    //compute the cubemap mip level based on perceptual roughness
                    float mipOriginal = UnityPerceptualRoughnessToMipmapLevel(perceptualRoughness);

                    //this will store the "intersectionDistance" result from the box projection
                    float mipOffset = 0;

                    //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                    #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                        vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset, _BevelFactor);
                    #else
                        vector_reflectionDirection = UnityBoxProjectedCubemapDirectionDefault(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset);
                    #endif

                    //NEW: Added a clamp to the mip offset, helps to make sure that when a fragment is far away the mip level doesn't climb to a high value and look wierd
                    #if defined (_APPROXIMATED_CLAMP)
                        mipOffset = clamp(mipOffset, 0.0f, UNITY_SPECCUBE_LOD_STEPS);
                    #endif

                    //compute new mip level based on the mipOffset value (this is mostly arbitrary)
                    float mip = lerp(0.0f, mipOriginal, mipOffset / UNITY_SPECCUBE_LOD_STEPS);

                    //sample the provided reflection probe at the given mip level
                    enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                    //decode the reflection if it's HDR
                    enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);

                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION HDRP |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION HDRP |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: APPROXIMATION HDRP |||||||||||||||||||||||||||||||
                //This is an approximation method found in HDRP I found out about.
                //It works in the same exact way conceptually as my old approximation.
                //However, the math in regard to choosing the correct mip level based on roughness/distance is much more accurate.
                #elif defined (_REFLECTIONRENDERINGTYPE_APPROXIMATEDHDRP)
                    //compute reflection vector
                    float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    //remap our smoothness parameter to PBR roughness
                    float perceptualRoughness = 1.0 - _Smoothness;

                    //use HDRP method to compute the intersection distance (and also box project vector_reflectionDirection)
                    float projectionDistance = EvaluateLight_EnvIntersection(vector_worldPosition, vector_reflectionDirection);

                    //use HDRP formula to calculate roughness based on distance
                    float distanceBasedRoughness = ComputeDistanceBaseRoughness(projectionDistance, length(vector_reflectionDirection), perceptualRoughness);

                    //the output of distanceBasedRoughness is the new perceptual roughness
                    perceptualRoughness = distanceBasedRoughness;

                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    //compute the cubemap mip level based on perceptual roughness
                    float mip = UnityPerceptualRoughnessToMipmapLevel(distanceBasedRoughness);

                    //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                    #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                        //NOTE TO SELF: In a proper bevel box projection implementation, there is alot of redudancy here that can be cut
                        //Recomputation of terms that don't have to be recomputed here... but this is just a test/example shader!

                        //recompute reflection vector again
                        vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);
                        
                        //bevel box project the reflection direction vector
                        vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, projectionDistance, _BevelFactor);
                    
                        //using HDRP's formula, and our output projection distance, compute the new perceptual roughness value based on the distance
                        distanceBasedRoughness = ComputeDistanceBaseRoughness(projectionDistance, length(vector_reflectionDirection), perceptualRoughness);

                        //the output of distanceBasedRoughness is the new perceptual roughness
                        perceptualRoughness = distanceBasedRoughness;

                        //recompute the roughness term
                        roughness = perceptualRoughness * perceptualRoughness;

                        //compute the cubemap mip level based on the new perceptual roughness
                        mip = UnityPerceptualRoughnessToMipmapLevel(distanceBasedRoughness);
                    #endif

                    //sample the provided reflection probe at the given mip level
                    enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                    //decode the reflection if it's HDR
                    enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);

                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: RAYTRACING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: RAYTRACING |||||||||||||||||||||||||||||||
                //||||||||||||||||||||||||||||||| REFLECTIONS TYPE: RAYTRACING |||||||||||||||||||||||||||||||
                //This is an accurate method of rendering rough reflections.
                //However, it introduces noise, and requires alot of samples to be cleaned up.
                //In addition the current implementation does not take advantage of importance sampling via luminance for the reflection cubemap
                #elif defined (_REFLECTIONRENDERINGTYPE_RAYTRACING)
                    float2 screenUV = vertex.screenPos.xy / vertex.screenPos.w;

                    //remap our smoothness parameter to PBR roughness
                    float perceptualRoughness = 1.0 - _Smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    int samples = int(_Samples);
                    int accumulatedSamples = 0;

                    //mip level for the reflection sampling, ideally it'd be the first mip level only since we are "convolving" the reflection.
                    //However later with _RAYTRACE_MIP_OFFSET, this is a cheat that's used as a way of getting usable results with fewer samples
                    float mip = 0.0f;

                    //use our prior approximation methods to offset the mip level the farther we are.
                    //this can help reduce noise at the cost of accuracy/quality
                    #if defined (_RAYTRACE_MIP_OFFSET)
                        //sample our own unique reflection direction for this method
                        float3 vector_mipOffsetReflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                        //compute the original mip level that we normally would be at with the classic/approximation methods...
                        float raytraceMipOriginal = UnityPerceptualRoughnessToMipmapLevel(perceptualRoughness);
                        float raytraceMipOffset = 0; //will contain the "projectionDistance" or "hit distance" to the edge of the box bounds
                        
                        //do our unique box projection
                        vector_mipOffsetReflectionDirection = UnityBoxProjectedCubemapDirectionDefault(vector_mipOffsetReflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, raytraceMipOffset);

                        //use clamp so mip level doesn't get offset so high and look funky
                        raytraceMipOffset = clamp(raytraceMipOffset, 0.0f, UNITY_SPECCUBE_LOD_STEPS);

                        //compute new mip level based on the raytraceMipOffset value (this is mostly arbitrary)
                        mip = lerp(0.0f, raytraceMipOriginal, raytraceMipOffset / UNITY_SPECCUBE_LOD_STEPS);
                    #endif

                    //start firing multiple samples!
                    for (int i = 0; i < samples; i++)
                    {
                        float2 sampling = float2(0, 0);

                        //use deterministic sampling if one does not like noise
                        #if defined (_DETERMINISTIC_SAMPLING)
                            sampling = Hammersley2d(i, samples);
                        #else //use noise to sample instead
                            #if defined(_WHITE_NOISE) //sample random white noise
                                sampling = float2(GenerateRandomFloat(screenUV), GenerateRandomFloat(screenUV));
                            #else //sample precomputed blue noise
                                float4 sampledBlueNoiseTexture = tex3Dlod(_BlueNoise, float4(screenUV * _ScreenParams.xy * _BlueNoise_TexelSize.xy, (1.0f / _BlueNoiseMaxSlices) * i, 0));
                                sampling = sampledBlueNoiseTexture.xy;
                            #endif
                        #endif

                        //output bool from GGX function if the current ray direction is valid
                        bool valid;

                        //sample a ray direction based on the random noise!
                        half3 vector_reflectionDirection = ImportanceSampleGGX_VNDF(sampling, vector_normalDirection, vector_viewDirection, roughness, valid);

                        //if (!valid)
                            //break;

                        //if the new computed ray direction sample valid...
                        if (valid)
                        {
                            //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                            #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                                vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, _BevelFactor);
                            #else
                                vector_reflectionDirection = UnityBoxProjectedCubemapDirectionDefault(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                            #endif

                            //sample the provided reflection cubemap using the current ray direction
                            float4 enviormentReflectionSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                            //decode the reflection if it's HDR
                            enviormentReflectionSample.rgb = DecodeHDR(enviormentReflectionSample, unity_SpecCube0_HDR);

                            //accumulate the reflection color
                            enviormentReflection += enviormentReflectionSample;
     
                            //accumulate sample count, so we can divide later
                            accumulatedSamples++;
                        }
                    }

                    //divide the accumlated reflection color by accumlated sample count to get the correct brightness
                    enviormentReflection /= accumulatedSamples;
                #endif

                //experimental feature for using the hit distance to do specular occlusion
                #if defined (_EXPERIMENTAL_BOX_SPECULAR_OCCLUSION)
                    //recompute reflection direction
                    float3 vector_specularOcclusionReflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    //This is the output hit distance, but we will use it as our specular occlusion factor
                    float specularOcclusionFactor = 0;

                    vector_specularOcclusionReflectionDirection = UnityBoxProjectedCubemapDirectionDefault(vector_specularOcclusionReflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, specularOcclusionFactor);

                    //artistic parameters for specular occlusion
                    specularOcclusionFactor = pow(specularOcclusionFactor, _ExperimentalSpecularOcclusionPower);
                    specularOcclusionFactor *= _ExperimentalSpecularOcclusionMultiplier;

                    //clamp so we stay within 0..1
                    specularOcclusionFactor = saturate(specularOcclusionFactor);

                    //apply to environment reflection
                    enviormentReflection *= lerp(1.0f, specularOcclusionFactor, _ExperimentalSpecularOcclusionIntensity);
                #endif

                //if enabled, here at the end of the function we do a janky 2x2 blur across the quads
                #if defined (_EXPERIMENTAL_2X2_BLUR)
                    enviormentReflection = (QuadReadLaneAt(enviormentReflection, uint2(0, 0)) +
                    QuadReadLaneAt(enviormentReflection, uint2(1, 0)) + 
                    QuadReadLaneAt(enviormentReflection, uint2(0, 1)) + 
                    QuadReadLaneAt(enviormentReflection, uint2(1, 1))) * 0.25;
                #endif

                return float4(enviormentReflection.rgb, 1);
            }
            ENDCG
        }
    }
}
