shader_type spatial;
//render_mode ;

group_uniforms ground;
uniform float ground_strenght = 3.0;
uniform vec2 ground_scale = vec2(0.01, 0.01);
uniform vec4 ground_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_normal_map : hint_normal;
uniform float ground_normal_strenght = 1.0;

uniform sampler2D ground_rough_map;
uniform float ground_roughness = 1.0;
group_uniforms;

group_uniforms Walls;
uniform float wall_strenght = 2.0;
uniform vec2 wall_scale = vec2(0.01, 0.01);
uniform vec4 wall_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D wall_normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform float wall_normal_strenght = 1.0;

uniform sampler2D wall_rough_map;
uniform float wall_roughness = 1.0;
group_uniforms;

group_uniforms Path;
uniform sampler2D path_mask;
uniform vec2 path_scale = vec2(0.1, 0.1);
uniform vec4 path_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D path_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D path_normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform float path_normal_strenght = 1.0;

uniform sampler2D path_rough_map;
uniform float path_roughness = 1.0;
group_uniforms;

varying float flatness;
varying vec3 pos_vertex;
varying vec3 pos_normal;

void vertex() {
	flatness = dot(NORMAL, vec3(0.0, 1.0, 0.0));

	// Triplanar map from mohsen zare youtube: https://www.youtube.com/watch?v=YwnVl2YHXBc
	pos_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pos_normal = abs(normalize(MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	// Blend between the two textures
	float ground_blend = clamp((flatness * ground_strenght ) - wall_strenght , 0.0, 1.0);
	float wall_blend = 1.0 - ground_blend;

	// Triplanar position
	vec2 uv = mix(pos_vertex.xy, pos_vertex.zy, round(pos_normal.x));
	uv = mix(uv, pos_vertex.xz, round(pos_normal.y));

	// Albedo color
	vec3 ground_albedo_color = texture(ground_albedo, uv * ground_scale).rgb * ground_blend;
	ground_albedo_color *= ground_color.rgb;

	vec3 wall_albedo_color = texture(wall_albedo, uv * wall_scale).rgb * wall_blend;
	wall_albedo_color *= wall_color.rgb;
	ALBEDO = ground_albedo_color + wall_albedo_color;
	
	float path_mask_value = texture(path_mask, UV).r;
	vec3 path_albedo_color = texture(path_albedo, uv * path_scale).rgb;
	path_albedo_color *= path_color.rgb;
	ALBEDO = mix(ALBEDO, path_albedo_color, path_mask_value);

	// Normal Map
	vec3 ground_normal = texture(ground_normal_map, uv * ground_scale).rgb * ground_blend;
	//ground_normal = normalize(ground_normal);
	ground_normal *= ground_normal_strenght;
	vec3 wall_normal = texture(wall_normal_map, uv * wall_scale).rgb * wall_blend;
	wall_normal *= wall_normal_strenght;
	//NORMAL_MAP = normalize(ground_normal + wall_normal);
	NORMAL_MAP = ground_normal + wall_normal;
	
	vec3 path_normal = texture(path_normal_map, uv * path_scale).rgb;
	path_normal *= path_normal_strenght;
	NORMAL_MAP = mix(NORMAL_MAP, path_normal, path_mask_value);

	// Roughness
	float ground_rough = ground_roughness * texture(ground_rough_map, uv * ground_scale).r;
	float wall_rough = wall_roughness * texture(wall_rough_map, uv * wall_scale).r;
	ROUGHNESS = ground_rough * ground_blend + wall_rough * wall_blend;
	
	float path_rough = path_roughness * texture(path_rough_map, uv * path_scale).r;
	ROUGHNESS = mix(ROUGHNESS, path_rough, path_mask_value);
}
