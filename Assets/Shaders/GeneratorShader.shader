Shader "Unlit/GeneratorShader"
{
    Properties
    {
        _StrokeTex( "Stroke Texture", 2D ) = "white" {}
        // _StrokeOffsets( "Stroke Offsets", float2[] )
        // _StrokeScale( "Stroke Scales", float2[] )
        // _StrokeRotations( "Stroke Rotations", float3[] )
        _StrokeOffsetsX( "Stroke Offsets X", float ) = 0
        _StrokeOffsetsY( "Stroke Offsets Y", float ) = 0
        _StrokeScalesX( "Stroke Scales X", float ) = 0
        _StrokeScalesY( "Stroke Scales Y", float ) = 0
        _StrokeRotations( "Stroke Rotations X", float ) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

            TEXTURE2D(_StrokeTex);
            SAMPLER(sampler_StrokeTex);
            SamplerState sampler_Test
            {
                AddressU = Wrap;
                AddressV = Wrap;
                Filter = Point;
            };

            float _StrokeOffsetsX;
            float _StrokeOffsetsY;
            float _StrokeScalesX;
            float _StrokeScalesY;
            float _StrokeRotations;

            float2 translate_uv( float2 uv, float2 offset, float2 scale, float rotation ) {
                const float Pi = 3.14159265f;
                const float Deg2Rad = (Pi * 2.0) / 360.0;

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

            v2f vert (appdata input)
            {
                
                // float sinVal = sin ( _StrokeRotations );
                // float cosVal = cos ( _StrokeRotations );
                // float2x2 rotationMatrix = float2x2( cosVal, -sinVal, sinVal, cosVal);
                // o.uv = ( mul( o.uv - 0.5, rotationMatrix ) ) + 0.5;

                

                // o.uv.x = frac( o.uv.x );
                // if( o.uv.x > 1.0 ) o.uv.x -= 1.0;
                // if( o.uv.x < 0.0 ) o.uv.x += 1.0;
                // if( o.uv.y > 1.0 ) o.uv.y -= 1.0;
                // if( o.uv.x < 0.0 ) o.uv.y += 1.0;
                
                // float2 scaleCenter = float2( 0.5, 0.5 );
                // float2 scale = float2( _StrokeScalesX, _StrokeScalesY );
                // o.uv = o.uv * scale;
                // float2 offset = float2(-0.5, -0.5) * (scale - 1.0);

                

                

                
                
                
                // if ( o.uv.y > 1 && o.uv.y < 2 ) {
                //     o.uv.y -= 1;
                // }
                v2f o;

                // float2 uv = input.uv + float2( _StrokeOffsetsX, _StrokeOffsetsY );
                // if ( uv.x > 1 ) uv.x -= 1;
                // float2 fractional = frac( uv );
                // float2 clampedFractional = clamp( fractional, 0, 0.999 );
                // uv = fmod(uv+1.0, 2.0)-1.0;
                // uv = fractional;

                // float2 scaleCenter = float2( 0.5, 0.5 );
                // float2 scale = float2( rcp( _StrokeScalesX ), rcp( _StrokeScalesY ) );
                // float2 scale = float2( _StrokeScalesX ,_StrokeScalesY );
                // uv = ( uv - 0.5 ) * scale + 0.5;
                // o.uv = o.uv * scale;
                // float2 offset = float2(-0.5, -0.5) * (scale - 1.0);
                
                o.uv = input.uv;

                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
                o.positionCS = posnInputs.positionCS;


                return o;
            }

            float4 frag (v2f input) : SV_Target
            {
                float2 uv = translate_uv( input.uv, float2( _StrokeOffsetsX, _StrokeOffsetsY ), float2( rcp( _StrokeScalesX ), rcp( _StrokeScalesY ) ), _StrokeRotations );

                float4 col = SAMPLE_TEXTURE2D( _StrokeTex, sampler_StrokeTex, uv);
                return col;
                // if ( uv.x > 1 && uv.x < 2 ) {
                //     uv.x -= 1;
                // }
                // uv = float2( clamp( uv.x, 0, 1.0 ), clamp( uv.y, 0, 1.0 ) );
                // float4 col = float4( input.uv.x, input.uv.x, input.uv.x, 1 );
                // col = float4( col.a, col.a, col.a, 255 );
                // col.r += lerp( 0, 1, 1 -col.a );
                // col.b += lerp( 0, 1, 1 - col.a );
                // col.g += lerp( 0, 1, 1 - col.a );
                // col.g = lerp( 0, 255,  col.a);
                // col.b = lerp( 0, 255,  col.a);
            }
            ENDHLSL
        }
    }
}
