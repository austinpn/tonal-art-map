// https://stackoverflow.com/questions/40292021/need-average-and-max-value-of-a-texture-in-shader
Shader "Custom/TransparentFill"
{
    Properties
    {
        _Color ( "Color", Color ) = ( 1, 1, 1, 1 )
        _Alpha ( "Alpha", Range( 0, 1 ) ) = 0
    }
    SubShader
    {
        Tags {"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent" "Queue" = "Transparent"}
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
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
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };
            
            float4 _Color;
            float _Alpha;

            v2f vert (appdata input)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip( input.position );
                return o;
            }

            float4 frag (v2f input) : SV_Target
            {
                return float4( _Color.xyz, _Alpha ); 
            }
            ENDHLSL
        }
    }
}
