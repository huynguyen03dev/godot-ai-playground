shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.1;
uniform float vignette_radius : hint_range(0.1, 1.0) = 0.5;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.07;
uniform float chroma_offset : hint_range(0.0, 0.02) = 0.004;
uniform float desaturate : hint_range(0.0, 1.0) = 0.4;
uniform vec4 horror_tint : source_color = vec4(0.02, 0.05, 0.0, 1.0);

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration
	float r = texture(SCREEN_TEXTURE, uv + vec2(chroma_offset, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(chroma_offset, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// Desaturate toward greenish horror tint
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);
	col += horror_tint.rgb * horror_tint.a;

	// Vignette
	vec2 centered = uv - 0.5;
	float vignette = 1.0 - smoothstep(vignette_radius, vignette_radius + 0.45,
			length(centered) * vignette_strength);
	col *= vignette;

	// Film grain
	float grain = rand(uv + fract(TIME * 0.07)) * grain_strength;
	col += grain - grain_strength * 0.5;

	COLOR = vec4(col, 1.0);
}
