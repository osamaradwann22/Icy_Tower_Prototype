extends Node2D

const VIEWPORT_SIZE := Vector2(540.0, 960.0)
const PLAYER_SIZE := Vector2(38.0, 54.0)
const PLATFORM_SIZE := Vector2(142.0, 18.0)
const START_Y := 720.0
const PLAYER_SPEED := 430.0
const AIR_ACCEL := 18.0
const BOUNCE_VELOCITY := -690.0
const BOOST_VELOCITY := -1040.0
const MAX_MOMENTUM_JUMP_BONUS := 260.0
const GRAVITY := 1850.0
const SIDE_MARGIN := 22.0
const PLATFORM_GAP_MIN := 70.0
const PLATFORM_GAP_MAX := 96.0
const PLATFORM_MAX_STEP_X := 176.0
const PLATFORM_KEEP_BELOW_CAMERA := 1080.0
const PLATFORM_BATCH_ABOVE := 1300.0
const COMBO_TIMEOUT := 2.2
const CAMERA_START_GRACE := 1.4
const CAMERA_BASE_SCROLL_SPEED := 34.0
const CAMERA_MAX_SCROLL_SPEED := 108.0
const CAMERA_WAIT_SPEED_MULTIPLIER := 1.85
const CAMERA_STILL_SPEED_MULTIPLIER := 2.65
const TILE_CHAIN_TIMEOUT := 2.4
const COMBO_START_TILE_COUNT := 5

const TYPE_PLAIN := "plain"
const TYPE_BOOST := "boost"
const TYPE_SPRINKLE := "sprinkle"
const TYPE_GLAZED := "glazed"
const TYPE_CRUMBLE := "crumble"

const POPUP_WORDS := ["Flip!", "Sweet Flip!", "Sugar Spin!", "Mega Flip!", "Tower Combo!"]

var player: CharacterBody2D
var player_visual_root: Node2D
var camera: Camera2D
var world_root: Node2D
var background_root: Node2D
var platform_root: Node2D
var effect_root: Node2D
var ui_layer: CanvasLayer
var score_label: Label
var combo_label: Label
var hint_label: Label
var start_panel: ColorRect
var game_over_panel: ColorRect
var touch_left_held := false
var touch_right_held := false
var touch_jump_requested := false
var rng := RandomNumberGenerator.new()
var highest_y := START_Y
var next_platform_y := START_Y
var last_platform_x := VIEWPORT_SIZE.x * 0.5
var camera_top_y := 0.0
var floor_score := 0
var height_score_steps := 0
var points := 0
var best_points := 0
var combo := 0
var best_combo := 0
var combo_timer := 0.0
var flip_spin_speed := 0.0
var flip_angle := 0.0
var combo_flip_timer := 0.0
var combo_flip_duration := 0.45
var combo_flip_direction := 1.0
var combo_flip_rotations := 1.0
var last_launch_was_trick := false
var camera_scroll_timer := 0.0
var tile_wait_timer := 0.0
var last_combo_platform_id := 0
var tile_chain_count := 0
var shake_timer := 0.0
var shake_strength := 0.0
var active_floor_type := TYPE_PLAIN
var game_started := false
var game_over := false


func _ready() -> void:
	rng.randomize()
	RenderingServer.set_default_clear_color(Color(0.98, 0.72, 0.82))
	_build_world()
	_build_ui()
	reset_game(false)


func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)

	if not game_started:
		if Input.is_action_just_pressed("jump") or touch_jump_requested:
			touch_jump_requested = false
			start_game()
		return

	if game_over:
		if Input.is_action_just_pressed("jump") or touch_jump_requested:
			touch_jump_requested = false
			start_game()
		return

	_update_combo(delta)
	_update_player(delta)
	_update_camera(delta)
	_update_platforms()
	_update_score()
	_check_game_over()


func _build_world() -> void:
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)

	background_root = Node2D.new()
	background_root.name = "CandyBakeryBackground"
	world_root.add_child(background_root)
	_build_background()

	platform_root = Node2D.new()
	platform_root.name = "Platforms"
	world_root.add_child(platform_root)

	effect_root = Node2D.new()
	effect_root.name = "Effects"
	world_root.add_child(effect_root)

	player = CharacterBody2D.new()
	player.name = "Player"
	world_root.add_child(player)

	var player_shape := CollisionShape2D.new()
	var player_rect := RectangleShape2D.new()
	player_rect.size = PLAYER_SIZE
	player_shape.shape = player_rect
	player.add_child(player_shape)

	player_visual_root = Node2D.new()
	player_visual_root.name = "SugarRunnerVisual"
	player.add_child(player_visual_root)
	_build_character_visual(player_visual_root)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.position = Vector2(VIEWPORT_SIZE.x * 0.5, START_Y - 150.0)
	add_child(camera)


func _build_background() -> void:
	for index in range(34):
		var y := START_Y + 420.0 - float(index) * 170.0
		var band := ColorRect.new()
		band.color = Color(1.0, 0.62, 0.75) if index % 2 == 0 else Color(1.0, 0.78, 0.56)
		band.position = Vector2(-80.0, y)
		band.size = Vector2(VIEWPORT_SIZE.x + 160.0, 92.0)
		background_root.add_child(band)

		var frosting := Line2D.new()
		frosting.default_color = Color(1.0, 0.94, 0.82, 0.72)
		frosting.width = 10.0
		frosting.points = PackedVector2Array([
			Vector2(0.0, y + 20.0),
			Vector2(90.0, y + 45.0),
			Vector2(190.0, y + 18.0),
			Vector2(310.0, y + 46.0),
			Vector2(450.0, y + 20.0),
			Vector2(600.0, y + 42.0),
		])
		background_root.add_child(frosting)

		for sprinkle_index in range(8):
			var sprinkle := ColorRect.new()
			sprinkle.color = _random_sprinkle_color()
			sprinkle.position = Vector2(rng.randf_range(20.0, VIEWPORT_SIZE.x - 20.0), y + rng.randf_range(10.0, 75.0))
			sprinkle.size = Vector2(18.0, 5.0)
			sprinkle.rotation = rng.randf_range(-0.7, 0.7)
			background_root.add_child(sprinkle)


func _build_character_visual(root: Node2D) -> void:
	var shadow := Polygon2D.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.polygon = PackedVector2Array([Vector2(-17.0, 25.0), Vector2(17.0, 25.0), Vector2(22.0, 29.0), Vector2(-22.0, 29.0)])
	root.add_child(shadow)

	var hat := Polygon2D.new()
	hat.color = Color(1.0, 0.96, 0.86)
	hat.polygon = PackedVector2Array([Vector2(-18.0, -34.0), Vector2(18.0, -34.0), Vector2(14.0, -19.0), Vector2(-14.0, -19.0)])
	root.add_child(hat)

	var body := Polygon2D.new()
	body.color = Color(0.16, 0.45, 0.92)
	body.polygon = PackedVector2Array([Vector2(-15.0, -8.0), Vector2(15.0, -8.0), Vector2(13.0, 20.0), Vector2(-13.0, 20.0)])
	root.add_child(body)

	var apron := Polygon2D.new()
	apron.color = Color(1.0, 0.92, 0.78)
	apron.polygon = PackedVector2Array([Vector2(-8.0, -6.0), Vector2(8.0, -6.0), Vector2(10.0, 18.0), Vector2(-10.0, 18.0)])
	root.add_child(apron)

	var scarf := Polygon2D.new()
	scarf.color = Color(0.95, 0.19, 0.35)
	scarf.polygon = PackedVector2Array([Vector2(-15.0, -9.0), Vector2(15.0, -9.0), Vector2(11.0, -1.0), Vector2(-13.0, 1.0)])
	root.add_child(scarf)

	var head := Polygon2D.new()
	head.color = Color(1.0, 0.77, 0.52)
	head.polygon = _circle_polygon(Vector2(0.0, -23.0), 14.0, 18)
	root.add_child(head)

	_add_limb(root, Vector2(-12.0, -2.0), Vector2(-25.0, 10.0), Color(1.0, 0.77, 0.52))
	_add_limb(root, Vector2(12.0, -2.0), Vector2(25.0, 10.0), Color(1.0, 0.77, 0.52))
	_add_limb(root, Vector2(-8.0, 19.0), Vector2(-18.0, 30.0), Color(0.12, 0.16, 0.25))
	_add_limb(root, Vector2(8.0, 19.0), Vector2(18.0, 30.0), Color(0.12, 0.16, 0.25))

	for eye_x in [-5.0, 5.0]:
		var eye := Polygon2D.new()
		eye.color = Color(0.05, 0.05, 0.06)
		eye.polygon = _circle_polygon(Vector2(eye_x, -23.0), 2.0, 8)
		root.add_child(eye)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	score_label = Label.new()
	score_label.position = Vector2(22.0, 18.0)
	score_label.size = Vector2(496.0, 78.0)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(0.18, 0.08, 0.12))
	ui_layer.add_child(score_label)

	combo_label = Label.new()
	combo_label.position = Vector2(22.0, 90.0)
	combo_label.size = Vector2(496.0, 48.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 30)
	combo_label.add_theme_color_override("font_color", Color(0.98, 0.18, 0.38))
	ui_layer.add_child(combo_label)

	hint_label = Label.new()
	hint_label.position = Vector2(24.0, 892.0)
	hint_label.size = Vector2(492.0, 30.0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.28, 0.12, 0.16))
	hint_label.text = "Hold left or right. The mascot jumps automatically."
	ui_layer.add_child(hint_label)

	_add_touch_button("LeftTouch", "LEFT", Vector2(18.0, 704.0), Vector2(246.0, 154.0), "_on_left_down", "_on_left_up")
	_add_touch_button("RightTouch", "RIGHT", Vector2(276.0, 704.0), Vector2(246.0, 154.0), "_on_right_down", "_on_right_up")

	start_panel = _make_overlay("Sugar Tower\nDonut Rush\n\nTry to reach the top of the Tower.", "START")
	game_over_panel = _make_overlay("", "RESTART")
	game_over_panel.visible = false


func _make_overlay(text: String, button_text: String) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = Color(0.22, 0.09, 0.13, 0.72)
	panel.position = Vector2.ZERO
	panel.size = VIEWPORT_SIZE
	ui_layer.add_child(panel)

	var title := Label.new()
	title.name = "Text"
	title.text = text
	title.position = Vector2(48.0, 176.0)
	title.size = Vector2(444.0, 382.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(title)

	var button := Button.new()
	button.name = "ActionButton"
	button.text = button_text
	button.position = Vector2(142.0, 604.0)
	button.size = Vector2(256.0, 82.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(_on_jump_down)
	panel.add_child(button)
	return panel


func _add_touch_button(node_name: String, label: String, pos: Vector2, size: Vector2, down_method: StringName, up_method: StringName) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.22, 0.08, 0.12))
	button.modulate = Color(1.0, 0.96, 0.92, 0.56)
	button.button_down.connect(Callable(self, down_method))
	button.button_up.connect(Callable(self, up_method))
	ui_layer.add_child(button)


func start_game() -> void:
	game_started = true
	start_panel.visible = false
	reset_game(true)


func reset_game(show_game: bool) -> void:
	game_over = false
	game_over_panel.visible = false
	touch_jump_requested = false
	touch_left_held = false
	touch_right_held = false
	active_floor_type = TYPE_PLAIN
	combo = 0
	combo_timer = 0.0
	flip_spin_speed = 0.0
	flip_angle = 0.0
	combo_flip_timer = 0.0
	combo_flip_duration = 0.45
	combo_flip_direction = 1.0
	combo_flip_rotations = 1.0
	last_launch_was_trick = false
	camera_scroll_timer = 0.0
	tile_wait_timer = 0.0
	last_combo_platform_id = 0
	tile_chain_count = 0
	floor_score = 0
	height_score_steps = 0
	points = 0
	shake_timer = 0.0
	camera.offset = Vector2.ZERO

	for child in platform_root.get_children():
		child.queue_free()
	for child in effect_root.get_children():
		child.queue_free()

	player.position = Vector2(VIEWPORT_SIZE.x * 0.5, START_Y - 70.0)
	player.velocity = Vector2.ZERO
	highest_y = player.position.y
	next_platform_y = START_Y
	last_platform_x = VIEWPORT_SIZE.x * 0.5
	camera.position = Vector2(VIEWPORT_SIZE.x * 0.5, START_Y - 150.0)
	camera_top_y = camera.position.y - VIEWPORT_SIZE.y * 0.5

	_spawn_platform(Vector2(VIEWPORT_SIZE.x * 0.5, START_Y + 16.0), PLATFORM_SIZE.x * 1.7, TYPE_PLAIN)
	while next_platform_y > camera_top_y - PLATFORM_BATCH_ABOVE:
		_spawn_next_platform()
	_update_ui()
	combo_label.text = ""
	if not show_game:
		start_panel.visible = true


func _update_player(delta: float) -> void:
	if player.is_on_floor():
		tile_wait_timer += delta
	else:
		tile_wait_timer = 0.0

	var touch_axis := float(int(touch_right_held) - int(touch_left_held))
	var input_axis: float = clamp(Input.get_axis("move_left", "move_right") + touch_axis, -1.0, 1.0)
	var target_speed := input_axis * PLAYER_SPEED
	var floor_accel := PLAYER_SPEED * 7.0 if active_floor_type == TYPE_GLAZED else PLAYER_SPEED * 12.0
	var accel := floor_accel if player.is_on_floor() else PLAYER_SPEED * AIR_ACCEL
	player.velocity.x = move_toward(player.velocity.x, target_speed, accel * delta)
	player.velocity.y += GRAVITY * delta

	touch_jump_requested = false

	var was_falling := player.velocity.y > 0.0
	player.move_and_slide()

	if was_falling and player.is_on_floor():
		var platform := _get_landed_platform()
		_handle_landing(platform)

	var half_player_width := PLAYER_SIZE.x * 0.5
	player.position.x = clamp(player.position.x, SIDE_MARGIN + half_player_width, VIEWPORT_SIZE.x - SIDE_MARGIN - half_player_width)
	if is_equal_approx(player.position.x, SIDE_MARGIN + half_player_width) or is_equal_approx(player.position.x, VIEWPORT_SIZE.x - SIDE_MARGIN - half_player_width):
		player.velocity.x = 0.0

	highest_y = min(highest_y, player.position.y)
	_update_character_motion_visual(delta)


func _get_landed_platform() -> StaticBody2D:
	for index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(index)
		if collision.get_normal().y < -0.6 and collision.get_collider() is StaticBody2D:
			return collision.get_collider() as StaticBody2D
	return null


func _handle_landing(platform: StaticBody2D) -> void:
	var platform_type := TYPE_PLAIN
	if platform != null and platform.has_meta("platform_type"):
		platform_type = str(platform.get_meta("platform_type"))
	active_floor_type = platform_type
	_register_tile_chain(platform)
	_launch_from_platform(platform_type, platform)


func _launch_from_platform(platform_type: String, platform: StaticBody2D) -> void:
	var speed_abs: float = abs(player.velocity.x)
	var speed_ratio: float = clamp(speed_abs / PLAYER_SPEED, 0.0, 1.0)
	var launch_velocity: float = lerp(BOUNCE_VELOCITY, BOUNCE_VELOCITY - MAX_MOMENTUM_JUMP_BONUS, speed_ratio)
	var award := 1
	var text := "Hop"
	var should_flip := combo > 0
	var is_super := combo >= 6

	if platform_type == TYPE_BOOST:
		launch_velocity = min(launch_velocity - 110.0, BOOST_VELOCITY)
		award += 2
		text = "Boost Flip!"
		_add_shake(0.18, 10.0)
		_spawn_sprinkles(player.position, 20)
	elif platform_type == TYPE_SPRINKLE:
		award += 2
		text = "Sprinkle Bonus!"
		_spawn_sprinkles(player.position, 14)
	elif platform_type == TYPE_GLAZED:
		award += 1
		text = "Glide Jump!"
	elif platform_type == TYPE_CRUMBLE:
		award += 1
		text = "Crumble!"
		_crumble_platform(platform)

	if combo > 0:
		text = "Combo Flip!"
		award += 1 + int(combo / 5)
	if combo >= 6:
		launch_velocity -= 80.0
		award += 2
		text = "Super Combo!"

	if platform_type == TYPE_BOOST and should_flip:
		text = "Sugar Spin!"
		award += 1

	player.velocity.y = launch_velocity
	_start_flip(speed_abs, should_flip, is_super)
	_score_tile_chain_jump(award, text, should_flip)
	_pulse_platform(platform)


func _register_tile_chain(platform: StaticBody2D) -> void:
	if platform == null or not is_instance_valid(platform):
		return

	var platform_id := platform.get_instance_id()
	if platform_id == last_combo_platform_id:
		_reset_tile_chain("Same tile")
		return

	tile_chain_count += 1
	combo = max(0, tile_chain_count - COMBO_START_TILE_COUNT + 1)
	if combo > 0:
		best_combo = max(best_combo, combo)
	combo_timer = TILE_CHAIN_TIMEOUT
	last_combo_platform_id = platform_id


func _score_tile_chain_jump(base_points: int, text: String, should_flip: bool) -> void:
	if combo > 0:
		var combo_bonus := 1 + int(combo / 6)
		points += base_points + combo_bonus
		var display_text := "%s  x%d" % [text, combo] if should_flip else "Chain x%d" % combo
		_show_world_popup(player.position + Vector2(0.0, -72.0), "+%d %s" % [base_points + combo_bonus, display_text], Color(0.98, 0.12, 0.36))
	elif tile_chain_count > 0:
		points += base_points
		_show_world_popup(player.position + Vector2(0.0, -68.0), "+%d Chain %d/%d" % [base_points, tile_chain_count, COMBO_START_TILE_COUNT], Color(0.34, 0.12, 0.16))
	else:
		points += base_points
	_update_ui()


func _update_combo(delta: float) -> void:
	if tile_chain_count <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		_reset_tile_chain("Chain")
	else:
		combo_label.text = "COMBO x%d" % combo if combo > 0 else "CHAIN %d/%d" % [tile_chain_count, COMBO_START_TILE_COUNT]
		combo_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 90.0)


func _reset_tile_chain(reason: String) -> void:
	if combo > 0 and reason != "":
		_show_world_popup(player.position + Vector2(0.0, -68.0), "%s reset" % reason, Color(0.34, 0.12, 0.16))
	combo = 0
	combo_timer = 0.0
	tile_chain_count = 0
	last_combo_platform_id = 0
	combo_label.text = ""


func _start_flip(speed_abs: float, is_trick: bool, is_super: bool) -> void:
	last_launch_was_trick = is_trick
	if not is_trick:
		flip_spin_speed = 0.0
		combo_flip_timer = 0.0
		flip_angle = clamp(player.velocity.x / PLAYER_SPEED, -1.0, 1.0) * 0.13
		return

	var direction := 1.0 if player.velocity.x >= 0.0 else -1.0
	var combo_spin: float = clamp(float(combo) / 8.0, 0.0, 1.0)
	var speed_spin: float = clamp(speed_abs / PLAYER_SPEED, 0.0, 1.0)
	var spin_strength: float = lerp(5.8, 16.0, max(combo_spin, speed_spin * 0.55))
	if is_super:
		spin_strength += min(7.0, float(combo) * 0.45)
		_spawn_sprinkles(player.position, 10)
		_add_shake(0.10, 5.0)
	flip_spin_speed = direction * spin_strength
	combo_flip_timer = 0.0
	combo_flip_direction = direction
	combo_flip_duration = lerp(0.52, 0.30, clamp(float(combo) / 10.0, 0.0, 1.0))
	combo_flip_rotations = 1.0 + floor(float(combo) / 7.0)


func _update_character_motion_visual(delta: float) -> void:
	if player.velocity.x < -8.0:
		player_visual_root.scale.x = -1.0
	elif player.velocity.x > 8.0:
		player_visual_root.scale.x = 1.0

	if player.is_on_floor():
		flip_spin_speed = 0.0
		combo_flip_timer = 0.0
		flip_angle = 0.0
		player_visual_root.rotation = 0.0
		player_visual_root.scale.y = 0.92
	else:
		player_visual_root.scale.y = 1.08 if last_launch_was_trick else 1.02
		if last_launch_was_trick:
			combo_flip_timer += delta
			var flip_progress: float = clamp(combo_flip_timer / combo_flip_duration, 0.0, 1.0)
			var eased_progress: float = sin(flip_progress * PI * 0.5)
			flip_angle = wrapf(combo_flip_direction * TAU * combo_flip_rotations * eased_progress, -PI, PI)
			if flip_progress >= 1.0 and abs(flip_spin_speed) > 0.0:
				flip_angle = wrapf(flip_angle + flip_spin_speed * delta * 0.35, -PI, PI)
		else:
			flip_angle = clamp(player.velocity.x / PLAYER_SPEED, -1.0, 1.0) * 0.20

	player_visual_root.rotation = flip_angle


func _update_camera(delta: float) -> void:
	camera_scroll_timer += delta
	var difficulty: float = clamp(float(floor_score) / 150.0, 0.0, 1.0)
	var scroll_speed: float = lerp(CAMERA_BASE_SCROLL_SPEED, CAMERA_MAX_SCROLL_SPEED, difficulty)
	if player.is_on_floor():
		scroll_speed *= CAMERA_WAIT_SPEED_MULTIPLIER
		if tile_wait_timer > 0.55 and abs(player.velocity.x) < 42.0:
			scroll_speed *= CAMERA_STILL_SPEED_MULTIPLIER
	var auto_scroll_y := camera.position.y
	if camera_scroll_timer > CAMERA_START_GRACE:
		auto_scroll_y -= scroll_speed * delta

	var player_follow_y: float = highest_y + 95.0
	var target_y: float = min(auto_scroll_y, player_follow_y)
	camera.position.y = lerp(camera.position.y, target_y, 5.0 * delta)
	camera_top_y = camera.position.y - VIEWPORT_SIZE.y * 0.5


func _update_camera_shake(delta: float) -> void:
	if shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_timer -= delta
	camera.offset = Vector2(rng.randf_range(-shake_strength, shake_strength), rng.randf_range(-shake_strength, shake_strength))
	shake_strength = max(0.0, shake_strength - 38.0 * delta)


func _add_shake(duration: float, strength: float) -> void:
	shake_timer = max(shake_timer, duration)
	shake_strength = max(shake_strength, strength)


func _update_platforms() -> void:
	while next_platform_y > camera_top_y - PLATFORM_BATCH_ABOVE:
		_spawn_next_platform()

	for platform in platform_root.get_children():
		if platform.position.y > camera.position.y + PLATFORM_KEEP_BELOW_CAMERA:
			platform.queue_free()


func _update_score() -> void:
	var new_floor_score: int = max(0, int((START_Y - highest_y) / 32.0))
	if new_floor_score != floor_score:
		floor_score = new_floor_score
		var new_height_steps := int(floor_score / 4)
		if new_height_steps > height_score_steps:
			points += new_height_steps - height_score_steps
			height_score_steps = new_height_steps
		best_points = max(best_points, points)
		_update_ui()


func _check_game_over() -> void:
	if player.position.y > camera.position.y + VIEWPORT_SIZE.y * 0.56:
		game_over = true
		best_points = max(best_points, points)
		var text := game_over_panel.get_node("Text") as Label
		text.text = "You fell!\nScore %d\nFloor %d    Best %d\nBest Combo x%d" % [points, floor_score, best_points, best_combo]
		game_over_panel.visible = true


func _spawn_next_platform() -> void:
	var difficulty: float = clamp(float(floor_score) / 150.0, 0.0, 1.0)
	var gap: float = rng.randf_range(PLATFORM_GAP_MIN, lerp(PLATFORM_GAP_MAX, 110.0, difficulty))
	var horizontal_reach: float = lerp(PLATFORM_MAX_STEP_X, 220.0, difficulty)
	var width: float = lerp(PLATFORM_SIZE.x, 104.0, difficulty)
	next_platform_y -= gap

	var min_x := width * 0.55
	var max_x := VIEWPORT_SIZE.x - width * 0.55
	var ideal_min_x: float = max(min_x, last_platform_x - horizontal_reach)
	var ideal_max_x: float = min(max_x, last_platform_x + horizontal_reach)
	var x: float = rng.randf_range(ideal_min_x, ideal_max_x)

	if abs(x - last_platform_x) < 54.0:
		var direction := -1.0 if last_platform_x > VIEWPORT_SIZE.x * 0.5 else 1.0
		x = clamp(last_platform_x + direction * rng.randf_range(54.0, horizontal_reach), min_x, max_x)

	var platform_type := _choose_platform_type(difficulty)
	_spawn_platform(Vector2(x, next_platform_y), width, platform_type)
	last_platform_x = x


func _choose_platform_type(difficulty: float) -> String:
	var roll := rng.randf()
	if roll < lerp(0.08, 0.15, difficulty):
		return TYPE_BOOST
	if roll < lerp(0.18, 0.31, difficulty):
		return TYPE_SPRINKLE
	if roll < lerp(0.25, 0.40, difficulty):
		return TYPE_GLAZED
	if floor_score > 18 and roll < lerp(0.30, 0.48, difficulty):
		return TYPE_CRUMBLE
	return TYPE_PLAIN


func _spawn_platform(pos: Vector2, width: float, platform_type: String) -> void:
	var platform := StaticBody2D.new()
	platform.name = "Platform_%s" % platform_type
	platform.position = pos
	platform.set_meta("platform_type", platform_type)
	platform_root.add_child(platform)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, PLATFORM_SIZE.y)
	shape.shape = rect
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	platform.add_child(shape)

	match platform_type:
		TYPE_BOOST:
			_add_donut_visual(platform, width, Color(0.58, 0.27, 0.08), Color(0.96, 0.08, 0.32), true)
		TYPE_SPRINKLE:
			_add_donut_visual(platform, width, Color(0.60, 0.32, 0.09), Color(1.0, 0.82, 0.05), true)
		TYPE_GLAZED:
			_add_bar_visual(platform, width, Color(0.45, 0.78, 0.96), Color(0.96, 1.0, 1.0))
		TYPE_CRUMBLE:
			_add_donut_visual(platform, width, Color(0.30, 0.14, 0.06), Color(0.14, 0.07, 0.03), false)
		_:
			_add_bar_visual(platform, width, Color(0.62, 0.34, 0.12), Color(0.98, 0.71, 0.22))


func _add_bar_visual(platform: StaticBody2D, width: float, base_color: Color, top_color: Color) -> void:
	var shadow := ColorRect.new()
	shadow.color = Color(0.10, 0.04, 0.04, 0.40)
	shadow.position = Vector2(-width * 0.5 + 5.0, -PLATFORM_SIZE.y * 0.5 + 7.0)
	shadow.size = Vector2(width, PLATFORM_SIZE.y + 5.0)
	platform.add_child(shadow)

	var outline := ColorRect.new()
	outline.color = Color(0.15, 0.06, 0.04)
	outline.position = Vector2(-width * 0.5 - 5.0, -PLATFORM_SIZE.y * 0.5 - 5.0)
	outline.size = Vector2(width + 10.0, PLATFORM_SIZE.y + 10.0)
	platform.add_child(outline)

	var visual := ColorRect.new()
	visual.color = base_color
	visual.position = Vector2(-width * 0.5, -PLATFORM_SIZE.y * 0.5)
	visual.size = Vector2(width, PLATFORM_SIZE.y)
	platform.add_child(visual)

	var frosting := Line2D.new()
	frosting.default_color = top_color
	frosting.width = 5.0
	frosting.points = PackedVector2Array([
		Vector2(-width * 0.48, -8.0),
		Vector2(-width * 0.2, -2.0),
		Vector2(width * 0.1, -8.0),
		Vector2(width * 0.46, -3.0),
	])
	platform.add_child(frosting)


func _add_donut_visual(platform: StaticBody2D, width: float, dough_color: Color, glaze_color: Color, sprinkles: bool) -> void:
	var radius_x := width * 0.5
	var radius_y := 24.0

	var shadow := Polygon2D.new()
	shadow.color = Color(0.10, 0.04, 0.04, 0.35)
	shadow.position = Vector2(5.0, 7.0)
	shadow.polygon = _ellipse_polygon(Vector2.ZERO, Vector2(radius_x + 4.0, radius_y + 3.0), 28)
	platform.add_child(shadow)

	var outline := Polygon2D.new()
	outline.color = Color(0.12, 0.05, 0.03)
	outline.polygon = _ellipse_polygon(Vector2.ZERO, Vector2(radius_x + 6.0, radius_y + 6.0), 28)
	platform.add_child(outline)

	var dough := Polygon2D.new()
	dough.color = dough_color
	dough.polygon = _ellipse_polygon(Vector2.ZERO, Vector2(radius_x, radius_y), 28)
	platform.add_child(dough)

	var glaze := Polygon2D.new()
	glaze.color = glaze_color
	glaze.polygon = _ellipse_polygon(Vector2(0.0, -3.0), Vector2(radius_x * 0.78, radius_y * 0.68), 24)
	platform.add_child(glaze)

	var hole := Polygon2D.new()
	hole.color = Color(0.16, 0.07, 0.06)
	hole.polygon = _ellipse_polygon(Vector2.ZERO, Vector2(radius_x * 0.22, radius_y * 0.45), 18)
	platform.add_child(hole)

	if sprinkles:
		for index in range(10):
			var sprinkle := ColorRect.new()
			sprinkle.color = _random_sprinkle_color()
			sprinkle.position = Vector2(rng.randf_range(-radius_x * 0.55, radius_x * 0.55), rng.randf_range(-radius_y * 0.45, radius_y * 0.2))
			sprinkle.size = Vector2(12.0, 4.0)
			sprinkle.rotation = rng.randf_range(-0.9, 0.9)
			platform.add_child(sprinkle)


func _pulse_platform(platform: StaticBody2D) -> void:
	if platform == null or not is_instance_valid(platform):
		return
	var tween := create_tween()
	tween.tween_property(platform, "scale", Vector2(1.12, 0.82), 0.06)
	tween.tween_property(platform, "scale", Vector2.ONE, 0.12)


func _crumble_platform(platform: StaticBody2D) -> void:
	if platform == null or not is_instance_valid(platform) or platform.has_meta("crumbling"):
		return
	platform.set_meta("crumbling", true)
	var tween := create_tween()
	tween.tween_property(platform, "modulate:a", 0.25, 0.28)
	await get_tree().create_timer(0.32).timeout
	if is_instance_valid(platform):
		platform.queue_free()


func _show_world_popup(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text if combo < 8 else POPUP_WORDS[min(POPUP_WORDS.size() - 1, int(combo / 4))]
	label.position = pos - Vector2(110.0, 20.0)
	label.size = Vector2(220.0, 44.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	effect_root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0.0, -52.0), 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _spawn_sprinkles(pos: Vector2, count: int) -> void:
	for index in range(count):
		var sprinkle := ColorRect.new()
		sprinkle.color = _random_sprinkle_color()
		sprinkle.position = pos
		sprinkle.size = Vector2(12.0, 4.0)
		sprinkle.rotation = rng.randf_range(-1.0, 1.0)
		effect_root.add_child(sprinkle)
		var target := pos + Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(-95.0, 35.0))
		var tween := create_tween()
		tween.tween_property(sprinkle, "position", target, rng.randf_range(0.32, 0.62))
		tween.parallel().tween_property(sprinkle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(sprinkle.queue_free)


func _update_ui() -> void:
	score_label.text = "Score %d\nFloor %d    Best %d" % [points, floor_score, best_points]
	if combo > 0:
		combo_label.text = "COMBO x%d" % combo


func _circle_polygon(center: Vector2, radius: float, points_count: int) -> PackedVector2Array:
	return _ellipse_polygon(center, Vector2(radius, radius), points_count)


func _ellipse_polygon(center: Vector2, radius: Vector2, points_count: int) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for index in range(points_count):
		var angle := TAU * float(index) / float(points_count)
		vertices.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return vertices


func _add_limb(root: Node2D, start: Vector2, end: Vector2, color: Color) -> void:
	var limb := Line2D.new()
	limb.default_color = color
	limb.width = 6.0
	limb.begin_cap_mode = Line2D.LINE_CAP_ROUND
	limb.end_cap_mode = Line2D.LINE_CAP_ROUND
	limb.points = PackedVector2Array([start, end])
	root.add_child(limb)


func _random_sprinkle_color() -> Color:
	var colors := [
		Color(0.95, 0.16, 0.34),
		Color(0.18, 0.66, 0.96),
		Color(1.0, 0.87, 0.22),
		Color(0.42, 0.86, 0.52),
		Color(0.62, 0.32, 0.92),
	]
	return colors[rng.randi_range(0, colors.size() - 1)]


func _on_left_down() -> void:
	touch_left_held = true


func _on_left_up() -> void:
	touch_left_held = false


func _on_right_down() -> void:
	touch_right_held = true


func _on_right_up() -> void:
	touch_right_held = false


func _on_jump_down() -> void:
	touch_jump_requested = true


func _on_jump_up() -> void:
	pass
