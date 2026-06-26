shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float frequency : hint_range(4.0, 80.0) = 30.0;

void fragment() {
	float scan_y = mod(TIME * speed + UV.y * frequency, 1.0);
	float scan = sin(scan_y * 3.14159 * 2.0) * intensity + (1.0 - intensity * 0.5);
	COLOR.rgb *= scan;
}
