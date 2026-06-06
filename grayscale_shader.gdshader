shader_type canvas_item;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	gray = step(0.5, gray);
	COLOR = vec4(vec3(gray), col.a);
}
