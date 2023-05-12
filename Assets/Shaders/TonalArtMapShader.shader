Shader "Custom/TonalArtMapShader"
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

            struct appdata
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float3 normal : NORMAL;
			};

            struct v2f {
				float4 positionCS 					: SV_POSITION;
				float2 uv		    				: TEXCOORD0;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
				float3 positionWS					: TEXCOORD2;
                half3 normalWS					: TEXCOORD3;
				
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord 				: TEXCOORD7;
				#endif
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
                o.uv = TRANSFORM_TEX(v.uv, _TonalArtMap);
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
                
                return o;
			}

            float luma(float4 color) {
                const float4 luma_vec = float4(0.2126, 0.7152, 0.0722, 1.0);
                return dot(color, luma_vec);
            }

            float4 frag (v2f input) : SV_Target
            {
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

                float gray = 0.2126*col.r + 0.7152*col.g + 0.0722*col.b;
                float level = (lerp(0, _ToneLevels, gray));
                level = lerp( _ToneLevels - level, level, _Invert );

                float mipLevel = ComputeTextureLOD(input.uv, _TonalArtMap_TexelSize.zw, _MipLevelBias);
                float4 hatch_col = SAMPLE_TEXTURE2D_ARRAY_LOD(_TonalArtMap, sampler_TonalArtMap, input.uv, round( level ), mipLevel);
                hatch_col = lerp( hatch_col, float4( _ColorTint.xyz, hatch_col.w ), _OverwriteColor );
                hatch_col = combine_colors( hatch_col, _ColorBackground );
                
                return hatch_col;
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

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			#pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }
    }
}
