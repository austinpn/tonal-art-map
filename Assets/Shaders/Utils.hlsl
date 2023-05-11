float4 combine_colors( float4 color0, float4 color1 ) {
    float4 color;
    color.a = ( 1 -  color0.a) * color1.a + color0.a;
    color.r = ( ( 1 - color0.a ) * color1.a * color1.r + color0.a * color0.r ) / color.a;
    color.g = ( ( 1 - color0.a ) * color1.a * color1.g + color0.a * color0.g ) / color.a;
    color.b = ( ( 1 - color0.a ) * color1.a * color1.b + color0.a * color0.b ) / color.a;

    return color;
}



float gray( float4 col ) {
    return 0.2126*col.r + 0.7152*col.g + 0.0722*col.b;
}

float whiten( float4 col ) {
    return gray( combine_colors( col, float4( 1, 1, 1, 1 ) ) );
}