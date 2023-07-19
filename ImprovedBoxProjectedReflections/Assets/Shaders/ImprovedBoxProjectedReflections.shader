            Shader "ImprovedBoxProjectedReflections"
{
    Properties
    {
        [Header(Debugging)]
        [Toggle(_DEBUG_FORCE_ROUGH)] _DebugForceRough("Force Rough", Float) = 0
        [Toggle(_DEBUG_FORCE_SMOOTH)] _DebugForceSmooth("Force Smooth", Float) = 0

        [Header(Rendering)]
        [Toggle(_CONTACT_HARDENING)] _EnableContactHardening("Contact Hardening", Float) = 1

        [Header(Material)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.75
        _BumpScale("Normal Strength", Float) = 1
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        [Header(Experimental)]
        [Toggle(_EXPERIMENTAL_BEVELED_BOX_PROJECTION)] _EnableBevelBoxProjection("Use Beveled Box Projection", Float) = 0
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
            #pragma shader_feature_local _CONTACT_HARDENING
            #pragma shader_feature_local _DEBUG_FORCE_ROUGH
            #pragma shader_feature_local _DEBUG_FORCE_SMOOTH
            #pragma shader_feature_local _EXPERIMENTAL_BEVELED_BOX_PROJECTION

            sampler2D _BumpMap;
            float4 _BumpMap_ST;

            float _BumpScale;
            float _Smoothness;

            float _BevelFactor;

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
                //boxMax.xyz = boxMax.xyz - float3(factor, factor, factor);
                //boxMin.xyz = boxMin.xyz + float3(factor, factor, factor);
                worldPos -= cubemapCenter.xyz;

                float intersectionTest = roundedboxIntersectFlipped(worldPos, worldRefl, (boxMax - boxMin) * 0.5, factor);
                fa = intersectionTest;

                float3 nrdir = normalize(worldRefl);
                float3 modifiedWorldRefl = worldPos + nrdir * intersectionTest;

                return modifiedWorldRefl;
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
                float4 posWorld : TEXCOORD2; //world space position 
                float3 tangentSpace0_worldNormal : TEXCOORD3; //tangent space 0 OR world normal if normal maps are disabled
                float3 tangentSpace1 : TEXCOORD4; //tangent space 1
                float3 tangentSpace2 : TEXCOORD5; //tangent space 2

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
                o.tangentSpace0_worldNormal = float3(worldTangent.x, worldBiTangent.x, worldNormal.x);
                o.tangentSpace1 = float3(worldTangent.y, worldBiTangent.y, worldNormal.y);
                o.tangentSpace2 = float3(worldTangent.z, worldBiTangent.z, worldNormal.z);

                return o;
            }

            fixed4 frag (vertexToFragment i) : SV_Target
            {
                float2 vector_uv = i.uvTexture; //uvs for sampling regular textures (texcoord0)
                float3 vector_worldPosition = i.posWorld.xyz; //world position vector
                float3 vector_viewPosition = _WorldSpaceCameraPos.xyz - vector_worldPosition; //camera world position
                float3 vector_viewDirection = normalize(vector_viewPosition); //camera world position direction

                float3 vector_tangent = float3(i.tangentSpace0_worldNormal.x, i.tangentSpace1.x, i.tangentSpace2.x);
                float3 vector_biTangent = float3(i.tangentSpace0_worldNormal.y, i.tangentSpace1.y, i.tangentSpace2.y);
                float3 vector_worldNormal = float3(i.tangentSpace0_worldNormal.z, i.tangentSpace1.z, i.tangentSpace2.z);

                //sample our normal map texture
                float3 texture_normalMap = UnpackNormalWithScale(tex2D(_BumpMap, vector_uv), _BumpScale);

                //calculate our normals with the normal map into consideration
                float3 vector_normalDirection = float3(dot(i.tangentSpace0_worldNormal, texture_normalMap.xyz), dot(i.tangentSpace1, texture_normalMap.xyz), dot(i.tangentSpace2, texture_normalMap.xyz));

                //normalize the vector so it stays in a -1..1 range
                vector_normalDirection = normalize(vector_normalDirection);

                float3 vector_reflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                float smoothness = _Smoothness;
                float perceptualRoughness = 1.0 - smoothness;
                float roughness = perceptualRoughness * perceptualRoughness; //offical roughness term for pbr shading
                
                float mipOffset = 0;

                //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                //#if defined(UNITY_SPECCUBE_BOX_PROJECTION)
                    #if defined (_EXPERIMENTAL_BEVELED_BOX_PROJECTION)
                        vector_reflectionDirection = ModifiedBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset, _BevelFactor);
                    #else
                        vector_reflectionDirection = UnityBoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax, mipOffset);
                    #endif
                //#endif

                //used for sampling blurry/sharp glossy reflections.
                #if defined (_CONTACT_HARDENING)
                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);

                    mip *= (mipOffset / UNITY_SPECCUBE_LOD_STEPS);
                    //mip *= (mipOffset / UNITY_SPECCUBE_LOD_STEPS) + perceptualRoughness;

                #else
                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
                #endif

                #if defined (_DEBUG_FORCE_ROUGH)
                    mip = UNITY_SPECCUBE_LOD_STEPS;
                #elif defined (_DEBUG_FORCE_SMOOTH)
                    mip = 0;
                #endif

                //sample the provided reflection probe at the given mip level
                float4 enviormentReflection = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, vector_reflectionDirection.xyz, mip);
                //enviormentReflection *= saturate(pow(saturate(mipOffset * 0.25), 2.0));

                //decode the reflection if it's HDR
                enviormentReflection.rgb = DecodeHDR(enviormentReflection, unity_SpecCube0_HDR);

                return float4(enviormentReflection.rgb, 1);
            }
            ENDCG
        }
    }
}
