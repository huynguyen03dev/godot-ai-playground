extends WorldEnvironment

func _ready() -> void:
	var env := Environment.new()

	# Dark sky
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.01, 0.02)
	sky_mat.sky_horizon_color = Color(0.02, 0.02, 0.04)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.ground_horizon_color = Color(0.01, 0.01, 0.02)
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Very dark ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.03, 0.05)
	env.ambient_light_energy = 0.22

	# Volumetric fog
	env.fog_enabled = true
	env.fog_density = 0.015
	env.fog_light_color = Color(0.03, 0.04, 0.06)
	env.fog_light_energy = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.05, 0.06, 0.08)
	env.volumetric_fog_anisotropy = 0.2
	env.volumetric_fog_length = 64.0

	# SSAO — deep shadow in corners
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.ssao_power = 1.8
	env.ssao_detail = 0.5

	# SSIL — subtle indirect bounce
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 0.8

	# Glow / bloom
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8

	# Color grading — desaturated, slightly green horror palette
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.88
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.55

	# Screen space reflections
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2

	environment = env
