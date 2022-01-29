// Example of particles with orthogonal occlusion using a viewport depth buffer
// by Wolfe (https://github.com/Wolfe2x7/)
// MIT License; main body of shader automatically converted from Godot Engine 3.4.2.stable's ParticlesMaterial.

shader_type particles;
uniform vec3 direction;
uniform float spread;
uniform float flatness;
uniform float initial_linear_velocity;
uniform float initial_angle;
uniform float angular_velocity;
uniform float orbit_velocity;
uniform float linear_accel;
uniform float radial_accel;
uniform float tangent_accel;
uniform float damping;
uniform float scale;
uniform float hue_variation;
uniform float anim_speed;
uniform float anim_offset;
uniform float initial_linear_velocity_random;
uniform float initial_angle_random;
uniform float angular_velocity_random;
uniform float orbit_velocity_random;
uniform float linear_accel_random;
uniform float radial_accel_random;
uniform float tangent_accel_random;
uniform float damping_random;
uniform float scale_random;
uniform float hue_variation_random;
uniform float anim_speed_random;
uniform float anim_offset_random;
uniform float lifetime_randomness;
uniform vec3 emission_box_extents;
uniform vec4 color_value : hint_color;
uniform int trail_divisor;
uniform vec3 gravity;

//
uniform float occlusion_margin = 0.04;
uniform float depth_cam_size;  // equal to camera size
uniform sampler2D depth_map : hint_albedo; // link to viewport texture
//


float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

void vertex() {
	uint base_number = NUMBER / uint(trail_divisor);
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);
	float angle_rand = rand_from_seed(alt_seed);
	float scale_rand = rand_from_seed(alt_seed);
	float hue_rot_rand = rand_from_seed(alt_seed);
	float anim_offset_rand = rand_from_seed(alt_seed);
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;

	bool restart = false;
	float tv = 0.0;
	if (CUSTOM.y > CUSTOM.w) {
		restart = true;
		tv = 1.0;
	}

	if (RESTART || restart) {
		uint alt_restart_seed = hash(base_number + uint(301184) + RANDOM_SEED);
		float tex_linear_velocity = 0.0;
		float tex_angle = 0.0;
		float tex_anim_offset = 0.0;
		float spread_rad = spread * degree_to_rad;
		{
			float angle1_rad = rand_from_seed_m1_p1(alt_restart_seed) * spread_rad;
			float angle2_rad = rand_from_seed_m1_p1(alt_restart_seed) * spread_rad * (1.0 - flatness);
			vec3 direction_xz = vec3(sin(angle1_rad), 0.0, cos(angle1_rad));
			vec3 direction_yz = vec3(0.0, sin(angle2_rad), cos(angle2_rad));
			direction_yz.z = direction_yz.z / max(0.0001,sqrt(abs(direction_yz.z))); // better uniform distribution
			vec3 spread_direction = vec3(direction_xz.x * direction_yz.z, direction_yz.y, direction_xz.z * direction_yz.z);
			vec3 direction_nrm = length(direction) > 0.0 ? normalize(direction) : vec3(0.0, 0.0, 1.0);
			// rotate spread to direction
			vec3 binormal = cross(vec3(0.0, 1.0, 0.0), direction_nrm);
			if (length(binormal) < 0.0001) {
				// direction is parallel to Y. Choose Z as the binormal.
				binormal = vec3(0.0, 0.0, 1.0);
			}
			binormal = normalize(binormal);
			vec3 normal = cross(binormal, direction_nrm);
			spread_direction = binormal * spread_direction.x + normal * spread_direction.y + direction_nrm * spread_direction.z;
			VELOCITY = spread_direction * initial_linear_velocity * mix(1.0, rand_from_seed(alt_restart_seed), initial_linear_velocity_random);
		}
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.y = 0.0;
		CUSTOM.w = (1.0 - lifetime_randomness * rand_from_seed(alt_restart_seed));
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random);
		TRANSFORM[3].xyz = vec3(rand_from_seed(alt_restart_seed) * 2.0 - 1.0, rand_from_seed(alt_restart_seed) * 2.0 - 1.0, rand_from_seed(alt_restart_seed) * 2.0 - 1.0) * emission_box_extents;
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
	else {
		CUSTOM.y += DELTA / LIFETIME;
		tv = CUSTOM.y / CUSTOM.w;
		float tex_linear_velocity = 0.0;
		float tex_angular_velocity = 0.0;
		float tex_linear_accel = 0.0;
		float tex_radial_accel = 0.0;
		float tex_tangent_accel = 0.0;
		float tex_damping = 0.0;
		float tex_angle = 0.0;
		float tex_anim_speed = 0.0;
		float tex_anim_offset = 0.0;
		vec3 force = gravity;
		vec3 pos = TRANSFORM[3].xyz;
		// apply linear acceleration
		force += length(VELOCITY) > 0.0 ? normalize(VELOCITY) * (linear_accel + tex_linear_accel) * mix(1.0, rand_from_seed(alt_seed), linear_accel_random) : vec3(0.0);
		// apply radial acceleration
		vec3 org = EMISSION_TRANSFORM[3].xyz;
		vec3 diff = pos - org;
		force += length(diff) > 0.0 ? normalize(diff) * (radial_accel + tex_radial_accel) * mix(1.0, rand_from_seed(alt_seed), radial_accel_random) : vec3(0.0);
		// apply tangential acceleration;
		vec3 crossDiff = cross(normalize(diff), normalize(gravity));
		force += length(crossDiff) > 0.0 ? normalize(crossDiff) * ((tangent_accel + tex_tangent_accel) * mix(1.0, rand_from_seed(alt_seed), tangent_accel_random)) : vec3(0.0);
		// apply attractor forces
		VELOCITY += force * DELTA;
		// orbit velocity
		if (damping + tex_damping > 0.0) {
			float v = length(VELOCITY);
			float damp = (damping + tex_damping) * mix(1.0, rand_from_seed(alt_seed), damping_random);
			v -= damp * DELTA;
			if (v < 0.0) {
				VELOCITY = vec3(0.0);
			} else {
				VELOCITY = normalize(VELOCITY) * v;
			}
		}
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		base_angle += CUSTOM.y * LIFETIME * (angular_velocity + tex_angular_velocity) * mix(1.0, rand_from_seed(alt_seed) * 2.0 - 1.0, angular_velocity_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random) + CUSTOM.y * (anim_speed + tex_anim_speed) * mix(1.0, rand_from_seed(alt_seed), anim_speed_random);
		
		//// Particle occlusion ////
		vec3 vector = TRANSFORM[3].xyz - EMISSION_TRANSFORM[3].xyz;
		vec3 x_basis = EMISSION_TRANSFORM[0].xyz;
		vec3 y_basis = EMISSION_TRANSFORM[1].xyz;
		vec3 z_basis = EMISSION_TRANSFORM[2].xyz;
		
		// Get UV for depth map from particle's relative XZ position
		float x_diff = vector.x * x_basis.x + vector.y * x_basis.y + vector.z * x_basis.z;
		float z_diff = vector.x * z_basis.x + vector.y * z_basis.y + vector.z * z_basis.z;
		vec2 drop_map = 2.0 * vec2(x_diff, z_diff) / depth_cam_size;
		drop_map = 0.5 * (drop_map + vec2(1.0));
		
		// Get nearest surface depth, as well as relative Y position and velocity
		float surface = texture(depth_map, drop_map).x;
		float y_pos = vector.x * y_basis.x + vector.y * y_basis.y + vector.z * y_basis.z;
		float y_velocity = VELOCITY.x * y_basis.x + VELOCITY.y * y_basis.y + VELOCITY.z * y_basis.z;
		
		if (y_pos - occlusion_margin + y_velocity * DELTA < surface) {
			//*// insert "collision" logic here //*//
			ACTIVE = false;  // or cull particle on contact
		}
		////////
	}
	float tex_scale = 1.0;
	float tex_hue_variation = 0.0;
	float hue_rot_angle = (hue_variation + tex_hue_variation) * pi * 2.0 * mix(1.0, hue_rot_rand * 2.0 - 1.0, hue_variation_random);
	float hue_rot_c = cos(hue_rot_angle);
	float hue_rot_s = sin(hue_rot_angle);
	mat4 hue_rot_mat = mat4(vec4(0.299, 0.587, 0.114, 0.0),
			vec4(0.299, 0.587, 0.114, 0.0),
			vec4(0.299, 0.587, 0.114, 0.0),
			vec4(0.000, 0.000, 0.000, 1.0)) +
		mat4(vec4(0.701, -0.587, -0.114, 0.0),
			vec4(-0.299, 0.413, -0.114, 0.0),
			vec4(-0.300, -0.588, 0.886, 0.0),
			vec4(0.000, 0.000, 0.000, 0.0)) * hue_rot_c +
		mat4(vec4(0.168, 0.330, -0.497, 0.0),
			vec4(-0.328, 0.035,  0.292, 0.0),
			vec4(1.250, -1.050, -0.203, 0.0),
			vec4(0.000, 0.000, 0.000, 0.0)) * hue_rot_s;
	COLOR = hue_rot_mat * color_value;

	TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz);
	TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz);
	TRANSFORM[2].xyz = normalize(TRANSFORM[2].xyz);
	float base_scale = tex_scale * mix(scale, 1.0, scale_random * scale_rand);
	if (base_scale < 0.000001) {
		base_scale = 0.000001;
	}
	TRANSFORM[0].xyz *= base_scale;
	TRANSFORM[1].xyz *= base_scale;
	TRANSFORM[2].xyz *= base_scale;
	if (CUSTOM.y > CUSTOM.w) {
		ACTIVE = false;
	}
}

