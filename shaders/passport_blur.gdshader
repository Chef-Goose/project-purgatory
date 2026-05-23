shader_type canvas_item;

uniform float blur_amount: hint_range(0.0, 10.0) = 0.0;
uniform float blur_strength: hint_range(0.5, 3.0) = 0.9;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	if (blur_amount > 0.01) {
		// Gaussian-style blur by sampling nearby pixels
		float blur_step = (blur_amount * blur_strength) / 8.0;
		color = vec4(0.0);
		for (float x = -2.0; x <= 2.0; x += 1.0) {
			for (float y = -2.0; y <= 2.0; y += 1.0) {
				color += texture(TEXTURE, UV + vec2(x, y) * blur_step);
			}
		}
		color /= 25.0;
	}
	
	COLOR = color * COLOR;
}
