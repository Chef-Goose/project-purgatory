shader_type canvas_item;

const int MAX_POINTS = 16;
uniform int table_point_count = 0;
uniform vec2 table_points[MAX_POINTS];

varying vec2 world_pos;

bool is_inside_table(vec2 p) {
	if (table_point_count < 3) {
		return true;
	}

	bool inside = false;
	vec2 prev = table_points[table_point_count - 1];

	for (int i = 0; i < MAX_POINTS; i++) {
		if (i >= table_point_count) {
			break;
		}

		vec2 curr = table_points[i];
		bool y_cross = (curr.y > p.y) != (prev.y > p.y);
		if (y_cross) {
			float denominator = prev.y - curr.y;
			if (abs(denominator) > 0.00001) {
				float x_intersection = (prev.x - curr.x) * (p.y - curr.y) / denominator + curr.x;
				if (p.x < x_intersection) {
					inside = !inside;
				}
			}
		}

		prev = curr;
	}

	return inside;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	if (tex_color.a <= 0.001) {
		discard;
	}

	if (!is_inside_table(world_pos)) {
		discard;
	}

	COLOR = tex_color;
}