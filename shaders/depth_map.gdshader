shader_type spatial;
render_mode unshaded, shadows_disabled;

void fragment() {
	float depth_tex = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, depth_tex) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	ALBEDO = vec3(view.z);
}