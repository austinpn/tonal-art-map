Shader "Custom/TonalArtMapFragNoShadowShader"
{
    Properties
    {
        [NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
        _ColorTint ("Color Tint", Color) = ( 1.0, 1.0, 1.0, 1.0 )
		_TonalArtMap ("Tonal Art Map", 2DArray) = "" {}
        _ToneLevels ("Tone Levels", Int) = 7
        _MipLevelBias ( "Mip Level Bias", Float ) = 2.47
        _Emission ( "Emission", Float ) = 0
        _Shininess ( "Shininess", Float ) = 1
        _Smoothness ( "Smoothness", Float ) = .5
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        Pass
        {
            Tags { "LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SPECULAR_COLOR
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            // #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight

            // shadow helper functions and macros

            struct appdata
            {
                float3 uv : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normalWS : NORMAL;
                // SHADOW_COORDS(1) // put shadows data into TEXCOORD1
                // float2 uv_tam : TEXCOORD1;
                float3 positionWS : TEXCOORD1;
            };

            float4 _ColorTint;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

    		TEXTURE2D_ARRAY(_TonalArtMap);
            SAMPLER(sampler_TonalArtMap);
            float4 _TonalArtMap_TexelSize;
            float4 _TonalArtMap_ST;

            int _ToneLevels;
            float _MipLevelBias;

            float _Emission;
            float _Shininess;
            float _Smoothness;

            v2f vert (appdata v)
            {
                v2f o;
                // o.positionCS = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _TonalArtMap);
                // o.normalWS = TransformObjectToWorldNormal(v.normal);
                // o.positionWS = TransformObjectToWorld(v.vertex);
                VertexPositionInputs posnInputs = GetVertexPositionInputs(v.uv);
                VertexNormalInputs normInputs = GetVertexNormalInputs(v.normal);
                
                o.positionCS = posnInputs.positionCS;
                o.positionWS = posnInputs.positionWS;
                o.normalWS = normInputs.normalWS;
                // half nl = max(0, dot(worldNormal, _MainLightPosition.xyz));
                // o.diff = nl * _MainLightColor.rgb;
                // o.ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                
                // o.uv_tam = (v.vertex.xy + 0.5);
                
                // compute shadows data
                // TRANSFER_SHADOW(o)
                return o;
            }

            float luma(float4 color) {
                const float4 luma_vec = float4(0.2126, 0.7152, 0.0722, 1.0);
                return dot(color, luma_vec);
            }

            float4 frag (v2f input) : SV_Target
            {
                // float4 col = tex2D(_MainTex, i.uv);
                // compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
                // fixed shadow = SHADOW_ATTENUATION(i);
                // darken light's illumination with shadow, keep ambient intact
                float2 uv = input.uv;
                float4 colorSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = input.positionWS;
                lightingInput.normalWS = normalize( input.normalWS );
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir( input.positionWS );
                lightingInput.shadowCoord = TransformWorldToShadowCoord( input.positionWS );

                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = colorSample.rgb * _ColorTint.rgb;
                surfaceInput.alpha = colorSample.a * _ColorTint.a;
                surfaceInput.specular = _Shininess;
                surfaceInput.smoothness = _Smoothness;
                surfaceInput.emission = _Emission;

                float4 col = UniversalFragmentBlinnPhong(lightingInput, surfaceInput);

                // apply tam
                // grayscale
                float gray = 0.2126*col.r + 0.7152*col.g + 0.0722*col.b;
                float level = _ToneLevels - (lerp(0, _ToneLevels, gray));
                // fixed l = dot(col, float4(0.2126, 0.7152, 0.0722, 1.0));
			    float texI = frac( gray ) * 8;

                // mip level
                // float mipLevel = ComputeTextureLOD(i.uv, _TonalArtMap_TexelSize.zw, _MipLevelBias)


                // float4 col1 = UNITY_SAMPLE_TEX2DARRAY_LOD(_TonalArtMap, float3(i.uv, floor( level )), 0);
                // float4 col2 = UNITY_SAMPLE_TEX2DARRAY_LOD(_TonalArtMap, float3(i.uv, ceil( level )), 0);
                
                // float4 col1 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(i.uv, floor( level )));
                // float4 col2 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(i.uv, ceil( level )));
                // float4 col1 = SAMPLE_TEXTURE2D_ARRAY(_TonalArtMap, sampler_TonalArtMap, input.uv, floor( level ));
                // float4 col2 = SAMPLE_TEXTURE2D_ARRAY(_TonalArtMap, sampler_TonalArtMap, input.uv, ceil( level ));

                float mipLevel = ComputeTextureLOD(input.uv, _TonalArtMap_TexelSize.zw, _MipLevelBias);

                float4 col1 = SAMPLE_TEXTURE2D_ARRAY_LOD(_TonalArtMap, sampler_TonalArtMap, input.uv, floor( level ), mipLevel);
                float4 col2 = SAMPLE_TEXTURE2D_ARRAY_LOD(_TonalArtMap, sampler_TonalArtMap, input.uv, ceil( level ), mipLevel);


                // float4 col1 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(IN.uv_TonalArtMap, floor(texI)));
                // float4 col2 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(IN.uv_TonalArtMap, ceil(texI)));

                float4 hatch_col = lerp(col1, col2, level - floor(level));
                // col = l;


                // return ( level / 12 );
                // return col;
                // return float4( uv, 0, 0 );
                // return col;
                return hatch_col;
            }
            ENDHLSL
        }
    }
}
