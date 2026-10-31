extends Node3D
## Outil de développement : rend une planche de modèles (godot --path godot res://scripts/showcase.tscn).
func _ready():
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fd8ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0)
	add_child(sun)
	var names = ["chest_wood", "chest_silver", "chest_gold", "chest_magic", "chest_crown", "chest_magic"]
	for i in names.size():
		var n = load("res://assets/models/blender/" + names[i] + ".glb").instantiate()
		n.position = Vector3((i % 3) * 2.6 - 2.6, 0, (i / 3) * 2.4 - 1.5)
		n.rotation.y = 0.35
		add_child(n)
		var ap = n.find_child("AnimationPlayer", false, false)
		if i == 0:
			print("chest anims: ", ap.get_animation_list())
		ap.play("Opened" if i == 5 else "Idle")
		ap.seek(0.5, true)
	var cam = Camera3D.new()
	cam.position = Vector3(0, 4.2, 7.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
