Shader "ImprovedBoxProjectedReflections"
{
    Properties
    {
        [Header(Rendering)]
        [Toggle(_CONTACT_HARDENING)] _EnableContactHardening("Contact Hardening", Float) = 0

        [Header(Material)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _BumpScale("Normal Strength", Float) = 1
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
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

            sampler2D _BumpMap;
            float4 _BumpMap_ST;

            float _BumpScale;
            float _Smoothness;

            float RayBoxDistance(float3 rayOrigin, float3 rayDirection, float3 boxMin, float3 boxMax)
            {
                float3 invRayDir = 1.0f / rayDirection;

                float3 tmin = (boxMin - rayOrigin) * invRayDir;
                float3 tmax = (boxMax - rayOrigin) * invRayDir;

                float3 tminSorted = min(tmin, tmax);
                float3 tmaxSorted = max(tmin, tmax);

                float maxTmin = max(max(tminSorted.x, tminSorted.y), tminSorted.z);
                float minTmax = min(min(tmaxSorted.x, tmaxSorted.y), tmaxSorted.z);

                if (maxTmin > minTmax)
                    return -1.0f; // No intersection

                float tHit = maxTmin > 0.0f ? maxTmin : minTmax;
                float3 hitPoint = rayOrigin + tHit * rayDirection;
                float distance = length(hitPoint - rayOrigin);

                return distance;
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

                float3x3 shading_tangentToWorld = float3x3(vector_tangent, vector_biTangent, vector_worldNormal);

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

                //if box projection is enabled, modify our vector to project reflections onto a world space box (defined by the reflection probe)
                #if defined(UNITY_SPECCUBE_BOX_PROJECTION)
                    vector_reflectionDirection = BoxProjectedCubemapDirection(vector_reflectionDirection, vector_worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                #endif

                //return float4(vector_reflectionDirection, 1);
                //float mipOffset = length(vector_reflectionDirection);

                #if defined (_CONTACT_HARDENING)
                    float3 vector_surfaceReflectionDirection = reflect(-vector_viewDirection, vector_normalDirection);

                    float3 boxMin = (unity_SpecCube0_BoxMin * 2.0) - vector_worldPosition.xyz;
                    float3 boxMax = (unity_SpecCube0_BoxMax * 2.0) - vector_worldPosition.xyz;

                    float mipOffset = RayBoxDistance(vector_worldPosition, reflect(-vector_viewDirection, vector_normalDirection), boxMin, boxMax);

                    //used for sampling blurry/sharp glossy reflections.
                    //float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness * (mipOffset / length(vector_reflectionDirection)));

                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);

                    mip *= (mipOffset * UNITY_SPECCUBE_LOD_STEPS) / length(vector_reflectionDirection);
                    mip /= UNITY_SPECCUBE_LOD_STEPS;
                    //mip = lerp(perceptualRoughnessToMipmapLevel(perceptualRoughness), mip, smoothness);
                    //mip = max(mip, perceptualRoughnessToMipmapLevel(perceptualRoughness));
                #else
                    //used for sampling blurry/sharp glossy reflections.
                    float mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
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
