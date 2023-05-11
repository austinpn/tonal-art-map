// https://stackoverflow.com/questions/40292021/need-average-and-max-value-of-a-texture-in-shader
Shader "Custom/Reducer"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            float4 _MainTex_TexelSize;

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
                float dx = _MainTex_TexelSize.x*0.5;
                float4 total = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2(-dx,-dx));
                total += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2(dx,-dx));
                total += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2(-dx,dx));
                total += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2(dx,dx));
                return total / 4;
            }
            ENDHLSL
        }
    }
}
