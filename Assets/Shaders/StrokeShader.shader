Shader "Custom/StrokeShader"
{
    Properties
    {
        _MainTex( "Main Texture", 2D ) = "white" {}

        [ToggleOff] _OverwriteColor("Overwrite Color", Float) = 0
        [ToggleOff] _Invert("Invert", Float) = 0
        _Color( "Color", Color ) = ( 0, 0, 0, 1 )

        _StrokeTex( "Stroke Texture", 2D ) = "white" {}
        _StrokeOffsetX( "Stroke Offsets X", float ) = 0
        _StrokeOffsetY( "Stroke Offsets Y", float ) = 0
        _StrokeScaleX( "Stroke Scales X", float ) = 1
        _StrokeScaleY( "Stroke Scales Y", float ) = 1
        _StrokeRotation( "Stroke Rotations X", float ) = 0
        _BrightnessRatio( "Brightness Ratio", Range( 0.0, 1.0 ) ) = 0
    }
    SubShader
    {
        // Tags { "RenderType"="Opaque" }
        Tags {"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent" "Queue" = "Transparent"}

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Utils.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _OverwriteColor;
            float _Invert;
            float4 _Color;

            TEXTURE2D(_StrokeTex);
            SAMPLER(sampler_StrokeTex);

            float _StrokeOffsetX;
            float _StrokeOffsetY;
            float _StrokeScaleX;
            float _StrokeScaleY;
            float _StrokeRotation;
            float _BrightnessRatio;

            float2 translate_uv( float2 uv ) {
                const float Pi = 3.14159265f;
                const float Deg2Rad = (Pi * 2.0) / 360.0;

                // ends up with overlap in center. Not sure if its the blue noise class or my transforms.
                float2 offset = float2( _StrokeOffsetX, _StrokeOffsetY );
                float2 scale = float2( rcp( _StrokeScaleX ), rcp( _StrokeScaleY ) );
                float rotation = _StrokeRotation;
                
                float sinVal = sin (radians( rotation ) );
                float cosVal = cos ( radians( rotation ) );
                float2x2 rotationMatrix = float2x2( cosVal, -sinVal, sinVal, cosVal);
                float3x3 scaleMatrix = float3x3( 
                    scale.x, 0, 0,
                    0, scale.y, 0,
                    0, 0, 1
                 );

                uv = frac( uv + offset ) - .5;                
                uv = mul( rotationMatrix, ( uv ) );
                uv = mul( scaleMatrix, float3( uv, 1 ) ).xy + .5;

                return uv;
            }

            v2f vert (appdata input)
            {
                v2f o;
                o.uv = input.uv;
                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
                o.positionCS = posnInputs.positionCS;

                return o;
            }

            float4 frag (v2f input) : SV_Target
            {
                float2 stroke_uv = clamp( translate_uv( input.uv), 0, 1 );
                
                float4 stroke_col = SAMPLE_TEXTURE2D_LOD( _StrokeTex, sampler_StrokeTex, stroke_uv, 0);
                float brightnessDirection = lerp( -1, 1, _Invert );
                stroke_col = lerp( stroke_col, float4( _Color.xyz, stroke_col.w ), _OverwriteColor );
                stroke_col *= 1 + brightnessDirection * _BrightnessRatio;
                float4 main_col = SAMPLE_TEXTURE2D( _MainTex, sampler_MainTex, input.uv);
                float4 col = combine_colors( stroke_col, main_col );

                return col;
            }
            ENDHLSL
        }
    }
}
