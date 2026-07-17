// Desaturate (down to 30% saturation) and dim unfocused splits.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    if (iFocus == 0) {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = mix(vec3(gray), color.rgb, 0.3) * 0.5;
    }

    fragColor = color;
}
