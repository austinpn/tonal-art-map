// https://github.com/Cyanilux/URP_ShaderCodeTemplates/blob/main/URP_PBRLitTemplate.shader
Shader "Custom/TonalArtMapFragOverwriteShader"
{
    Properties
    {
        [ToggleOff] _OverwriteColor("Overwrite Color", Float) = 0
        [ToggleOff] _Invert("Invert", Float) = 0

        _ColorTint ("Color Tint", Color) = ( 0, 0, 0, 1 )
        _ColorBackground ("Background", Color) = ( 1.0, 1.0, 1.0, 1.0 )
		_TonalArtMap ("Tonal Art Map", 2DArray) = "" {}
        _ToneLevels ("Tone Levels", Int) = 7
        _MipLevelBias ( "Mip Level Bias", Float ) = 2.47
        _Emission ( "Emission", Float ) = 0
        _Shininess ( "Shininess", Float ) = 1
        _Smoothness ( "Smoothness", Range( 0, 1 ) ) = 0
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SPECULAR_COLOR
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Utils.hlsl"
            
            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            // #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight

            // shadow helper functions and macros

            struct appdata
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float3 normal : NORMAL;
			};

            // struct v2f
            // {
            //     float4 positionCS : SV_POSITION;
            //     float2 uv : TEXCOORD0;
            //     // SHADOW_COORDS(1) // put shadows data into TEXCOORD1
            //     // float2 uv_tam : TEXCOORD1;
            //     float3 positionWS : TEXCOORD1;
            //     float4 shadowCoord : TEXCOORD2;
            //     DECLARE_LIGHTMAP_OR_SH( lightmapUV, vertexSH, 4 );
            //     half3 normalWS : NORMAL;
            // };

            struct v2f {
				float4 positionCS 					: SV_POSITION;
				float2 uv		    				: TEXCOORD0;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
				float3 positionWS					: TEXCOORD2;
                half3 normalWS					: TEXCOORD3;
				
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord 				: TEXCOORD7;
				#endif
				//UNITY_VERTEX_INPUT_INSTANCE_ID
				//UNITY_VERTEX_OUTPUT_STEREO
			};

            float4 _ColorTint;
            float4 _ColorBackground;
            float _OverwriteColor;
            float _Invert;

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
                o.uv = TRANSFORM_TEX(v.uv, _TonalArtMap);
                // o.normalWS = TransformObjectToWorldNormal(v.normal);
                // o.positionWS = TransformObjectToWorld(v.vertex);
                VertexPositionInputs posnInputs = GetVertexPositionInputs(v.positionOS);
                VertexNormalInputs normInputs = GetVertexNormalInputs(v.normal);

                o.positionCS = posnInputs.positionCS;
                o.positionWS = posnInputs.positionWS;
                o.normalWS = normInputs.normalWS;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					o.shadowCoord = GetShadowCoord(posnInputs);
				#endif

                OUTPUT_LIGHTMAP_UV( v.texcoord1, unity_LightmapST, o.lightmapUV );
                OUTPUT_SH( o.normalWS.xyz, o.vertexSH );
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

                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = input.positionWS;
                lightingInput.normalWS = normalize( input.normalWS );
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir( input.positionWS );
                lightingInput.bakedGI = 0;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    lightingInput.shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    lightingInput.shadowCoord = TransformWorldToShadowCoord(lightingInput.positionWS);
                #else
                    lightingInput.shadowCoord = float4(0, 0, 0, 0);
                #endif

                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = float4( 1, 1, 1, 1 );
                surfaceInput.alpha = 1;
                surfaceInput.smoothness = _Smoothness;
                surfaceInput.specular = 1;
                surfaceInput.metallic = 0;
                surfaceInput.normalTS = 0;
                surfaceInput.emission = _Emission;
                surfaceInput.occlusion = .4;
                surfaceInput.alpha = 0;
                surfaceInput.clearCoatMask = 0;
                surfaceInput.clearCoatSmoothness = 0;

                float4 col = UniversalFragmentPBR(lightingInput, surfaceInput);

                // apply tam
                // grayscale
                float gray = 0.2126*col.r + 0.7152*col.g + 0.0722*col.b;
                float level = (lerp(0, _ToneLevels, gray));
                level = lerp( _ToneLevels - level, level, _Invert );
                // fixed l = dot(col, float4(0.2126, 0.7152, 0.0722, 1.0));=

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

                float4 hatch_col = SAMPLE_TEXTURE2D_ARRAY_LOD(_TonalArtMap, sampler_TonalArtMap, input.uv, round( level ), mipLevel);
                

                // float4 col1 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(IN.uv_TonalArtMap, floor(texI)));
                // float4 col2 = UNITY_SAMPLE_TEX2DARRAY(_TonalArtMap, float3(IN.uv_TonalArtMap, ceil(texI)));

                // hatch_col = lerp(col1, col2, level - floor(level));
                hatch_col = lerp( hatch_col, float4( _ColorTint.xyz, hatch_col.w ), _OverwriteColor );
                hatch_col = combine_colors( hatch_col, _ColorBackground );
                // col = l;


                // return ( level / 12 );
                // return col;
                // return float4( uv, 0, 0 );
                // return col * hatch_col;
                return hatch_col;
                // return gray;
                // return col;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			// GPU Instancing
			#pragma multi_compile_instancing
			//#pragma multi_compile _ DOTS_INSTANCING_ON

			// Universal Pipeline Keywords
			// (v11+) This is used during shadow map generation to differentiate between directional and punctual (point/spot) light shadows, as they use different formulas to apply Normal Bias
			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            
            // #pragma vertex caster_vert
            // #pragma fragment caster_frag
            // #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // struct caster_appdata
            // {
            //     float3 positionOS : POSITION;
            //     float3 normalOS : NORMAL;
            // };

            // struct caster_v2f
            // {
            //     float4 positionCS : SV_POSITION;
            // };

            // float3 _LightDirection;
            
            // float4 GetShadowCasterPositionCS( float3 positionWS, float3 normalWS ) {
            //     float3 lightDirectionWS = _LightDirection;
            //     float4 positionCS = TransformWorldToHClip( ApplyShadowBias( positionWS, normalWS, lightDirectionWS ) );
            // #if UNITY_REVERSED_Z
            //     positionCS.z = min( positionCS.z, UNITY_NEAR_CLIP_VALUE );
            // #else
            //     positionCS.z = max( positionCS.z, UNITY_NEAR_CLIP_VALUE );
            // #endif
            //     return positionCS;
            // }

            // caster_v2f caster_vert( caster_appdata v ) {
            //     caster_v2f o;

            //     VertexPositionInputs posnInputs = GetVertexPositionInputs(v.positionOS);
            //     VertexNormalInputs normInputs = GetVertexNormalInputs(v.normalOS);

            //     o.positionCS = GetShadowCasterPositionCS( posnInputs.positionWS, normInputs.normalWS );
            //     return o;
            // }

            // float4 caster_frag ( caster_v2f input ) : SV_TARGET {
            //     return 0;
            // }

            ENDHLSL
        }
    }
}
