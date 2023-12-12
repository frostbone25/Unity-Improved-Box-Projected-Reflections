Shader "ImprovedBoxProjectedReflections"
{
    Properties
    {
        [HideInInspector] _Seed("_Seed", Float) = 0

        [Header(Rendering)]
        [KeywordEnum(None, Approximated, Traced)] _ContactHardeningType("Contact Hardening Type", Float) = 1
        _TraceSamples("Tracing Samples", Float) = 16

        [Header(Material)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.75
        _BumpScale("Normal Strength", Float) = 1
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        [Header(Experimental)]
        [Toggle(_EXPERIMENTAL_BEVELED_BOX_PROJECTION)] _EnableBevelBoxProjection("Use Beveled Box Projection", Float) = 0
        [Toggle(_EXPERIMENTAL_BEVELED_BOX_OFFSET)] _BevelBoxOffset("Use Bevel Factor Offset", Float) = 0
        _BevelFactor("Bevel Factor", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Name "ImprovedBoxProjectedReflections_ForwardBase"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY3D INCLUDES |||||||||||||||||||||||||||||

            #pragma vertex vert
            #pragma fragment frag

            //BUILT IN RENDER PIPELINE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShadowLibrary.cginc"
            #include "UnityLightingCommon.cginc"
            #include "UnityStandardBRDF.cginc"

            // -------------------------------------
            // Unity defined keywords
            #pragma fragmentoption ARB_precision_hint_fastest

            #pragma multi_compile_fwdbase

            #pragma multi_compile _ UNITY_SPECCUBE_BOX_PROJECTION

            // -------------------------------------
            // Custom keywords
            #pragma multi_compile _CONTACTHARDENINGTYPE_NONE _CONTACTHARDENINGTYPE_APPROXIMATED _CONTACTHARDENINGTYPE_TRACED

            #pragma shader_feature_local _EXPERIMENTAL_BEVELED_BOX_PROJECTION
            #pragma shader_feature_local _EXPERIMENTAL_BEVELED_BOX_OFFSET

            sampler2D _BumpMap;
            float4 _BumpMap_ST;

            float _BumpScale;
            float _Smoothness;

            float _BevelFactor;
            float _Seed;
            float _TraceSamples;

            #include "BevelBoxProjection.cginc"
            #include "ReflectionTracing.cginc"

            //||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||
            //||||||||||||||||||||||||||||| UNITY BOX PROJECTION |||||||||||||||||||||||||||||
            // Slightly modified version of unity's original box projected function to output the hit distance

            inline float3 UnityBoxProjectedCubemapDirection(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax, out float distanceToHitPoint)
            {
                // Do we have a valid reflection probe?
                UNITY_BRANCH
                if (cubemapCenter.w > 0.0)
                {
                    float3 nrdir = normalize(worldRefl);

                    #if 1
                        float3 rbmax = (boxMax.xyz - worldPos) / nrdir;
                        float3 rbmin = (boxMin.xyz - worldPos) / nrdir;

                        float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;

                    #else // Optimized version
                        float3 rbmax = (boxMax.xyz - worldPos);
                        float3 rbmin = (boxMin.xyz - worldPos);

                        float3 select = step(float3(0, 0, 0), nrdir);
                        float3 rbminmax = lerp(rbmax, rbmin, select);
                        rbminmax /= nrdir;
                    #endif

                    distanceToHitPoint = min(min(rbminmax.x, rbminmax.y), rbminmax.z);

                    worldPos -= cubemapCenter.xyz;
                    worldRefl = worldPos + nrdir * distanceToHitPoint;
                }

                return worldRefl;
            }

            struct appdata
            {
                //the most important trio for shading
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;

                //instancing
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertexToFragment
            {
                float4 pos : SV_POSITION;
                float2 uvTexture : TEXCOORD0;
                float4 posWorld : TEXCOORD1; //world space position 
                float3 tangentSpace0 : TEXCOORD2; //tangent space 0
                float3 tangentSpace1 : TEXCOORD3; //tangent space 1
                float3 tangentSpace2 : TEXCOORD4; //tangent space 2
                float4 screenPos : TEXCOORD5;

                //instancing
                UNITY_VERTEX_OUTPUT_STEREO
            };

            vertexToFragment vert (appdata v)
            {
                vertexToFragment o;

                //instancing
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uvTexture = TRANSFORM_TEX(v.texcoord, _BumpMap);

                //define our world position vector
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);

                //compute the world normal
                float3 worldNormal = UnityObjectToWorldNormal(normalize(v.normal));

                //the tangents of the mesh
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);

                //compute the tangent sign
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;

                //compute bitangent from cross product of normal and tangent
                float3 worldBiTangent = cross(worldNormal, worldTangent) * tangentSign;

                //output the tangent space matrix
                o.tangentSpace0 = float3(worldTangent.x, worldBiTangent.x, worldNormal.x);
                o.tangentSpace1 = float3(worldTangent.y, worldBiTangent.y, worldNormal.y);
                o.tangentSpace2 = float3(worldTangent.z, worldBiTangent.z, worldNormal.z);

                o.screenPos = UnityStereoTransformScreenSpaceTex(ComputeScreenPos(o.pos));

                return o;
            }

            fixed4 frag (vertexToFragment i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float2 vector_uv = i.uvTexture; //uvs for sampling regular textures (texcoord0)
                float3 vector_worldPosition = i.posWorld.xyz; //world position vector
                float3 vector_viewPosition = _WorldSpaceCameraPos.xyz - vector_worldPosition; //camera world position
                float3 vector_viewDirection = normalize(vector_viewPosition); //camera world position direction

                float3 vector_tangent = float3(i.tangentSpace0.x, i.tangentSpace1.x, i.tangentSpace2.x);
                float3 vector_biTangent = float3(i.tangentSpace0.y, i.tangentSpace1.y, i.tangentSpace2.y);
                float3 vector_worldNormal = float3(i.tangentSpace0.z, i.tangentSpace1.z, i.tangentSpace2.z);

                //sample our normal map texture
                float3 texture_normalMap = UnpackNormalWithScale(tex2D(_BumpMap, vector_uv), _BumpScale);

                //calculate our normals with the normal map into consideration
                float3 vector_normalDirection = float3(dot(i.tangentSpace0, texture_normalMap.xyz), dot(i.tangentSpace1, texture_normalMap.xyz), dot(i.tangentSpace2, texture_normalMap.xyz));

                //normalize the vector so it stays in a -1..1 range
                vector_normalDirection = normalize(vector_normalDirection);

                #if defined (_CONTACTHARDENINGTYPE_NONE)
                    float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    float mipOffset = 0;

                    //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                    //#if defined (UNITY_SPECCUBE_BOX_PROJECTION)
                        #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                            vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset, _BevelFactor);
                        #else
                            vector_reflectionDirection = UnityBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset);
                        #endif
                    //#endif

                    float smoothness = _Smoothness;
                    float perceptualRoughness = 1.0 - smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);

                    float4 enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                    enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);
                #elif defined (_CONTACTHARDENINGTYPE_APPROXIMATED)
                    float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    float smoothness = _Smoothness;
                    float perceptualRoughness = 1.0 - smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading
                
                    float mipOffset = 0;

                    //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                    //#if defined (UNITY_SPECCUBE_BOX_PROJECTION)
                        #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                            vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset, _BevelFactor);
                        #else
                            vector_reflectionDirection = UnityBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset);
                        #endif
                    //#endif

                    //used for sampling blurry/sharp glossy reflections.
                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
                    mip *= (mipOffset / UNITY_SPECCUBE_LOD_STEPS) + roughness;

                    //sample the provided reflection probe at the given mip level
                    float4 enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);

                    //decode the reflection if it's HDR
                    enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);
                #elif defined (_CONTACTHARDENINGTYPE_TRACED)
                    float4 enviormentReflection = float4(0, 0, 0, 0);

                    float smoothness = _Smoothness;
                    float perceptualRoughness = 1.0 - smoothness;
                    float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading

                    int samples = int(_TraceSamples);
                    int accumulatedSamples = 0;

                    for (int i = 0; i < samples; i++)
                    {
                        float2 random = float2(GenerateRandomFloat(screenUV), -GenerateRandomFloat(screenUV));

                        bool valid;

                        half3 vector_reflectionDirection = ImportanceSampleGGX_VNDF(random, vector_normalDirection, vector_viewDirection, roughness, valid);

                        if (!valid)
                            break;

                        float mipOffset;

                        //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                        //#if defined (UNITY_SPECCUBE_BOX_PROJECTION)
                            #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                                vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset, _BevelFactor);
                            #else
                                vector_reflectionDirection = UnityBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset);
                            #endif
                        //#endif

                        float4 enviormentReflectionSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, 0);
                        enviormentReflectionSample.rgb = DecodeHDR(enviormentReflectionSample, unity_SpecCube0_HDR);

                        enviormentReflection += enviormentReflectionSample;
                        accumulatedSamples++;
                    }

                    enviormentReflection /= accumulatedSamples;
                #endif

                return float4(enviormentReflection.rgb, 1);
            }
            ENDCG
        }
    }
}
