Shader "Custom/GeneratorStrokeShader"
{
    Properties
    {
        _MainTex( "Main Texture", 2D ) = "white" {}

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
        Tags { "RenderType"="Opaque" }

        Pass
        {
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

                float2 offset = float2( _StrokeOffsetX, _StrokeOffsetY );
                float2 scale = float2( rcp( _StrokeScaleX ), rcp( _StrokeScaleY ) );
                float rotation = _StrokeRotation;

                uv = uv + offset;
                if ( uv.x > 1 ) uv.x -= 1;
                if ( uv.y > 1 ) uv.y -= 1;
                if ( uv.x < 0 ) uv.x += 1;
                if ( uv.y < 0 ) uv.y += 1;
                
                float sinVal = sin ( rotation * Deg2Rad );
                float cosVal = cos ( rotation * Deg2Rad );
                float2x2 rotationMatrix = float2x2( cosVal, -sinVal, sinVal, cosVal);
                rotationMatrix = ( ( rotationMatrix * .5 ) + .5 ) * 2 - 1;
                uv = ( mul( uv - 0.5, rotationMatrix ) ) + 0.5;

                uv = ( uv - 0.5 ) * scale + 0.5;

                return uv;
            }

            // https://stackoverflow.com/questions/141855/programmatically-lighten-a-color
            float4 lighten_color( float4 color ) {
                
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
                // stroke_col -= _BrightnessRatio;
                stroke_col *= 1 - _BrightnessRatio;
                // stroke_col = lighten_color( stroke_col );
                float4 main_col = SAMPLE_TEXTURE2D( _MainTex, sampler_MainTex, input.uv);
                float4 col = combine_colors( stroke_col, main_col );

                return col;
            }
            ENDHLSL
        }
    }
}
