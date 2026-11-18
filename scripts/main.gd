extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var height_label: Label
var status_label: Label
var restart_button: Button
var start_y := 0.0
var peak_y := 0.0
var game_over := false

func _ready() -> void:
    _build_world()
    _build_player()
    _build_camera()
    _build_hud()
    start_y = player.global_position.y
    peak_y = start_y

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.055, 0.075, 0.105)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.65, 0.72, 0.85)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    _add_platform(Vector3(0, -0.7, 0), Vector3(9, 1.2, 9), Color(0.25, 0.29, 0.32))
    _add_platform(Vector3(2.5, 2.2, -1.0), Vector3(3.2, 0.6, 2.6), Color(0.35, 0.31, 0.26))
    _add_platform(Vector3(-1.8, 5.0, -2.0), Vector3(2.8, 0.55, 2.4), Color(0.32, 0.36, 0.39))
    _add_platform(Vector3(1.5, 7.8, -3.0), Vector3(2.6, 0.55, 2.3), Color(0.42, 0.34, 0.27))
    _add_platform(Vector3(-2.0, 10.7, -4.0), Vector3(2.8, 0.55, 2.3), Color(0.32, 0.38, 0.34))
    _add_platform(Vector3(1.2, 13.7, -5.0), Vector3(3.0, 0.55, 2.4), Color(0.39, 0.34, 0.31))
    _add_platform(Vector3(-1.2, 16.8, -6.0), Vector3(3.0, 0.55, 2.4), Color(0.31, 0.36, 0.42))
    _add_platform(Vector3(1.5, 20.0, -7.0), Vector3(3.5, 0.65, 3.0), Color(0.43, 0.36, 0.29))

    for i in range(12):
        var rock := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = randf_range(0.35, 1.0)
        mesh.bottom_radius = randf_range(0.7, 1.5)
        mesh.height = randf_range(3.0, 8.0)
        rock.mesh = mesh
        rock.position = Vector3(randf_range(-13, 13), randf_range(0, 17), randf_range(-13, -9))
        rock.rotation.z = randf_range(-0.2, 0.2)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.17, 0.21, 0.25)
        rock.material_override = mat
        add_child(rock)

func _add_platform(pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    mesh_instance.material_override = mat
    body.add_child(mesh_instance)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    add_child(body)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Climber"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 1.0, 0)
    add_child(player)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 6, 13)
    camera.rotation_degrees = Vector3(-18, 0, 0)
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)

    var panel := PanelContainer.new()
    panel.position = Vector2(18, 16)
    panel.custom_minimum_size = Vector2(300, 82)
    hud.add_child(panel)
    var vbox := VBoxContainer.new()
    panel.add_child(vbox)

    height_label = Label.new()
    height_label.text = "ВЫСОТА: 0 м"
    height_label.add_theme_font_size_override("font_size", 23)
    vbox.add_child(height_label)

    status_label = Label.new()
    status_label.text = "Веди молот пальцем. Отпусти, чтобы зацепиться."
    vbox.add_child(status_label)

    var controls := HBoxContainer.new()
    controls.anchor_left = 0.5
    controls.anchor_right = 0.5
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.offset_left = -170
    controls.offset_right = 170
    controls.offset_top = -92
    controls.offset_bottom = -18
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 18)
    hud.add_child(controls)

    for item in [["◀", "left"], ["▲", "up"], ["▶", "right"], ["↻", "reset"]]:
        var button := Button.new()
        button.text = item[0]
        button.custom_minimum_size = Vector2(72, 66)
        button.add_theme_font_size_override("font_size", 27)
        controls.add_child(button)
        if item[1] == "reset":
            button.pressed.connect(_reset_player)
        else:
            button.button_down.connect(func(): player.set_mobile_input(item[1], true))
            button.button_up.connect(func(): player.set_mobile_input(item[1], false))

    restart_button = Button.new()
    restart_button.text = "Начать заново"
    restart_button.position = Vector2(18, 112)
    restart_button.visible = false
    restart_button.pressed.connect(_reset_player)
    hud.add_child(restart_button)

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var h := maxf(0.0, player.global_position.y - start_y)
    peak_y = maxf(peak_y, h)
    height_label.text = "ВЫСОТА: %d м  |  РЕКОРД: %d м" % [int(h), int(peak_y)]
    camera.global_position = camera.global_position.lerp(
        Vector3(player.global_position.x * 0.25, player.global_position.y + 5.5, player.global_position.z + 13.0),
        1.0 - exp(-3.0 * delta)
    )
    camera.look_at(player.global_position + Vector3(0, 1.3, 0), Vector3.UP)
    if player.global_position.y < -8.0 and not game_over:
        game_over = true
        status_label.text = "Падение! Попробуй ещё раз."
        restart_button.visible = true

func _reset_player() -> void:
    player.global_position = Vector3(0, 1.0, 0)
    player.velocity = Vector3.ZERO
    player.reset_hammer()
    game_over = false
    restart_button.visible = false
    status_label.text = "Веди молот пальцем. Отпусти, чтобы зацепиться."
