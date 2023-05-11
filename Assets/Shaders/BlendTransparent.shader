// https://stackoverflow.com/questions/40292021/need-average-and-max-value-of-a-texture-in-shader
Shader "Custom/BlendTransparent"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ( "Color", Color ) = ( 1, 1, 1, 1 )
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Utils.hlsl"
            
            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            // #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight

            // shadow helper functions and macros

            struct appdata
            {
                float3 position : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            float4 _Color;

            v2f vert (appdata input)
            {
                v2f o;
                o.uv = input.uv;
                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.position);
                
                o.positionCS = posnInputs.positionCS;
                return o;
            }

            float4 frag (v2f input) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, input.uv, 0);
                return combine_colors( color, _Color );
            }
            ENDHLSL
        }
    }
}
