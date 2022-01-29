# 3D Particle Occlusion/Collision for Godot 3
This project shows a few examples of a simple method to add collision-like effects to 3D particles in Godot 3, using an orthogonal viewport depth buffer. Created with Godot 3.4.2 Stable.

![Screenshot from 2022-01-29 13-30-40](https://user-images.githubusercontent.com/72348938/151674934-372c57b0-48c8-4075-9d88-6b3b44c6430c.png)

It is perhaps more accurate to describe the process as 3D particle *occlusion*, hence the repository name. While Godot 4 features physics-enabled particles, this shader method works off of visibility and render layers. Because of this, no collision shapes are necessary, but "collisions" will not occur on transparent surfaces, and particles will act as if they've collided if they pass behind a surface.

I developed my first version of this technique because I simply wanted rain particles not to enter indoor/sheltered spaces. Such a use case is ideal for this method, because it depends primarily upon vertical occlusion.

# How is it implemented?
````
Particles
  RemoteTransform
  Viewport
    Camera
      PlaneMesh
````
The way it is set up in the project, particles are expected to be emitted in the direction of the Particles node's negative Y basis, like rain. The RemoteTransform passes a rotated transform to the Camera, which is monitoring the depth map on a specific render layer. The particle shader retrieves the depth map from the Viewport.

I recommend creating your own shader file from a ParticlesMaterial with the following instructions:
1. Create and configure a ParticlesMaterial; it is easier to set up the built-in behaviors this way.
2. Convert it to a ShaderMaterial (drop-down on the right).
3. Add these uniforms to the list:
````
uniform float occlusion_margin = 0.04;
uniform float depth_cam_size;  // equal to camera size
uniform sampler2D depth_map : hint_albedo; // link to viewport texture
````
4. Insert this code below the "else" after *"if (RESTART || restart)"* (see examples in project):
````
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
````
5. The plane mesh size, camera size, and depth_cam_size uniform must be equal for accurate mapping.
6. Assign the viewport as a ViewportTexture to the depth_map uniform.

Depth mapping gets its own render layer, so be sure to include particle-occluding objects on that layer. You can also use the layer to hide invisible copies of transparent surfaces, enabling them to occlude particles too.

# License
This project uses the [MIT License](https://github.com/Wolfe2x7/3D-particle-occlusion-collision-for-Godot-3/blob/main/LICENSE) with no copyright. The main body of each example shader is automatically converted from Godot Engine 3.4.2.stable's ParticlesMaterial.
