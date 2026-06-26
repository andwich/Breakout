shader_type canvas_item;

uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float glow = smoothstep(0.0, 0.4, edge);
	COLOR.rgb = mix(COLOR.rgb, glow_color.rgb * glow_intensity, glow * 0.6);
	COLOR.a = 1.0;
}
