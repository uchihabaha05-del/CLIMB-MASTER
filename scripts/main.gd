extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var height_label: Label
var status_label: Label
var restart_button: Button
var pause_button: Button
const TOP_HEIGHT := 20.0
const SAVE_PATH := "user://climb_master.cfg"
var start_y := 0.0
var best_height := 0.0
var finished := false
var finish_position := Vector3.ZERO
var reset_button: Button
var win_overlay: Control
var win_label: Label
var game_over := false
var checkpoint_positions: Array[Vector3] = []
var active_checkpoint := 0
var checkpoint_label: Label
var record_label: Label
var climb_progress: ProgressBar
var pause_overlay: Control
var moving_obstacles: Array[AnimatableBody3D] = []
var obstacle_clock := 0.0
var last_player_feedback := ""

func _ready() -> void:
    _build_world()
    _build_photogrammetry_boulders()
    _build_imported_obstacles()
    _build_asset_course()
    _build_industrial_structures()
    _build_checkpoints()
    _build_obstacles()
    _build_player()
    _build_camera()
    _build_hud()
    start_y = player.global_position.y
    _load_record()
    record_label.text = "РЕКОРД  %d м" % int(best_height)

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY

    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    # Warm sunset palette: violet upper sky, rose cloud-light and a bright orange horizon.
    sky_material.sky_top_color = Color(0.105, 0.105, 0.25)
    sky_material.sky_horizon_color = Color(0.96, 0.36, 0.19)
    sky_material.ground_bottom_color = Color(0.075, 0.055, 0.10)
    sky_material.ground_horizon_color = Color(0.56, 0.19, 0.16)
    sky_material.sun_angle_max = 12.0
    sky_material.energy_multiplier = 1.15
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.92, 0.55, 0.43)
    environment.ambient_light_energy = 0.82
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.78, 0.34, 0.27)
    environment.fog_density = 0.012
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.name = "MountainSun"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(1.0, 0.57, 0.34)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 55.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "ColdSkyFill"
    fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
    fill.light_color = Color(0.42, 0.62, 0.9)
    fill.light_energy = 0.38
    add_child(fill)

    _add_platform(Vector3(0, -0.7, 0), Vector3(5.2, 1.2, 9), Color(0.25, 0.29, 0.32))
    _add_platform(Vector3(-1.45, 2.2, 0.0), Vector3(2.8, 0.6, 2.6), Color(0.35, 0.31, 0.26))
    _add_platform(Vector3(1.45, 5.0, 0.0), Vector3(2.8, 0.55, 2.4), Color(0.32, 0.36, 0.39))
    _add_platform(Vector3(-1.45, 7.8, 0.0), Vector3(2.6, 0.55, 2.3), Color(0.42, 0.34, 0.27))
    _add_platform(Vector3(1.45, 10.7, 0.0), Vector3(2.8, 0.55, 2.3), Color(0.32, 0.38, 0.34))
    _add_platform(Vector3(-1.45, 13.7, 0.0), Vector3(3.0, 0.55, 2.4), Color(0.39, 0.34, 0.31))
    _add_platform(Vector3(1.45, 16.8, 0.0), Vector3(3.0, 0.55, 2.4), Color(0.31, 0.36, 0.42))
    _add_platform(Vector3(-1.45, 20.0, 0.0), Vector3(3.5, 0.65, 3.0), Color(0.43, 0.36, 0.29))

    # Keep the central climbing lane readable. Natural cliff outcrops frame
    # the route from the far left and right instead of spawning in front of it.
    for side in [-1.0, 1.0]:
        for level in range(6):
            var outcrop := StaticBody3D.new()
            outcrop.name = "CliffOutcrop_%s_%d" % ["L" if side < 0.0 else "R", level]
            var rock := MeshInstance3D.new()
            var rock_mesh := SphereMesh.new()
            rock_mesh.radius = 1.0
            rock_mesh.height = 1.65
            rock.mesh = rock_mesh
            rock.scale = Vector3(1.1, randf_range(1.0, 1.7), 0.75)
            var rock_mat := StandardMaterial3D.new()
            rock_mat.albedo_color = Color(0.16, 0.19, 0.22)
            rock_mat.roughness = 0.98
            rock.material_override = rock_mat
            outcrop.add_child(rock)
            var collision := CollisionShape3D.new()
            var shape := SphereShape3D.new()
            shape.radius = 0.9
            collision.shape = shape
            collision.scale = Vector3(1.1, 1.3, 0.85)
            outcrop.add_child(collision)
            outcrop.position = Vector3(side * 4.65, 1.5 + float(level) * 3.35, -0.25)
            add_child(outcrop)



func _build_photogrammetry_boulders() -> void:
    # Real photogrammetry scan; convex collision keeps the mobile physics cost manageable.
    var boulder_scene := load("res://assets/models/namaqualand_boulder_05_2k.gltf") as PackedScene
    if boulder_scene == null:
        push_warning("Photogrammetry boulder could not be loaded.")
        return

    var placements: Array[Dictionary] = [
        {"position": Vector3(-1.45, 1.25, -0.28), "rotation": Vector3(0.12, 0.35, -0.18), "scale": 2.65},
        {"position": Vector3(1.45, 4.25, -0.32), "rotation": Vector3(-0.16, 1.15, 0.22), "scale": 2.85},
        {"position": Vector3(-1.4, 7.25, -0.30), "rotation": Vector3(0.08, 2.1, -0.12), "scale": 2.7},
        {"position": Vector3(1.4, 10.15, -0.32), "rotation": Vector3(-0.1, 0.55, 0.16), "scale": 2.9},
        {"position": Vector3(-1.45, 13.25, -0.28), "rotation": Vector3(0.14, 1.65, -0.2), "scale": 2.75},
        {"position": Vector3(1.45, 16.35, -0.30), "rotation": Vector3(-0.12, 2.55, 0.14), "scale": 2.85}
    ]

    for placement in placements:
        var boulder := boulder_scene.instantiate() as Node3D
        if boulder == null:
            continue
        boulder.position = placement["position"]
        boulder.rotation = placement["rotation"]
        boulder.scale = Vector3.ONE * float(placement["scale"])
        add_child(boulder)
        _add_boulder_convex_collisions(boulder)


func _add_boulder_convex_collisions(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            mesh_instance.create_convex_collision(true, true)
    for child in node.get_children():
        if child is not StaticBody3D:
            _add_boulder_convex_collisions(child)


func _build_imported_obstacles() -> void:
    # Authored obstacle pack: textured rock, rusty pipe and stone ledge.
    var obstacle_scene := load("res://assets/models/obstacles.gltf") as PackedScene
    if obstacle_scene == null:
        push_warning("Could not load assets/models/obstacles.gltf")
        return

    var source_root := obstacle_scene.instantiate() as Node3D
    if source_root == null:
        push_warning("Obstacle asset root is not Node3D")
        return
    add_child(source_root)

    var source_rock := _find_obstacle_mesh(source_root, "Rock")
    var source_pipe := _find_obstacle_mesh(source_root, "Pipe")
    var source_ledge := _find_obstacle_mesh(source_root, "Ledge")

    if source_rock == null or source_pipe == null or source_ledge == null:
        push_warning("Obstacle pack is missing Rock, Pipe or Ledge mesh")
        source_root.queue_free()
        return

    # Stagger the imported pieces along the route so they form a deliberate climbing line.
    var placements: Array[Dictionary] = [
        {"source": source_rock, "position": Vector3(-1.35, 3.15, 0.1), "rotation": -0.18, "scale": 1.35, "name": "TexturedRock_A"},
        {"source": source_pipe, "position": Vector3(1.35, 6.15, 0.15), "rotation": 0.10, "scale": 1.0, "name": "RustPipe_A"},
        {"source": source_ledge, "position": Vector3(-1.35, 8.95, 0.0), "rotation": -0.12, "scale": 1.15, "name": "StoneLedge_A"},
        {"source": source_rock, "position": Vector3(1.35, 12.0, 0.1), "rotation": 0.22, "scale": 1.28, "name": "TexturedRock_B"},
        {"source": source_pipe, "position": Vector3(-1.35, 15.0, 0.15), "rotation": -0.14, "scale": 1.05, "name": "RustPipe_B"},
        {"source": source_ledge, "position": Vector3(1.35, 17.9, 0.0), "rotation": 0.15, "scale": 1.18, "name": "StoneLedge_B"}
    ]

    for item in placements:
        var source := item["source"] as MeshInstance3D
        if source.mesh == null:
            continue
        var body := StaticBody3D.new()
        body.name = item["name"]
        body.position = item["position"]
        body.rotation.z = float(item["rotation"])
        body.scale = Vector3.ONE * float(item["scale"])
        body.add_to_group("imported_obstacle")

        var visual := MeshInstance3D.new()
        visual.name = "TexturedMesh"
        visual.mesh = source.mesh
        visual.material_override = source.material_override
        # Preserve the imported orientation, but center each piece at its placement.
        visual.transform = Transform3D(source.transform.basis, Vector3.ZERO)
        body.add_child(visual)

        var collision := CollisionShape3D.new()
        collision.name = "GeneratedConvexCollision"
        collision.shape = source.mesh.create_convex_shape()
        body.add_child(collision)
        add_child(body)

    source_root.queue_free()


func _find_obstacle_mesh(node: Node, target_name: String) -> MeshInstance3D:
    if node is MeshInstance3D and (node as MeshInstance3D).name.to_lower().contains(target_name.to_lower()):
        return node as MeshInstance3D
    for child in node.get_children():
        var found := _find_obstacle_mesh(child, target_name)
        if found != null:
            return found
    return null


func _build_asset_course() -> void:
    # The route is a clear zig-zag. Obstacles are attached to the cliff edges,
    # leaving the center open so the player can read each next move.
    var placements: Array[Dictionary] = [
        {"file": "fallen_log", "position": Vector3(-3.15, 1.15, -0.58), "rotation": Vector3(0.0, 0.12, 0.24), "scale": 0.78},
        {"file": "crate_stack", "position": Vector3(3.1, 4.1, -0.58), "rotation": Vector3(0.0, -0.18, -0.08), "scale": 0.72},
        {"file": "rock_arch", "collision": "trimesh", "position": Vector3(-3.25, 7.05, -0.62), "rotation": Vector3(0.0, 0.0, 0.0), "scale": 0.70},
        {"file": "tire_stack", "collision": "trimesh", "position": Vector3(3.15, 10.0, -0.58), "rotation": Vector3(0.0, 0.25, 0.06), "scale": 0.72},
        {"file": "pipe_cluster", "collision": "trimesh", "position": Vector3(-3.2, 12.95, -0.58), "rotation": Vector3(0.0, 0.0, 0.10), "scale": 0.68},
        {"file": "broken_bridge", "collision": "trimesh", "position": Vector3(3.1, 15.85, -0.62), "rotation": Vector3(0.0, 0.0, -0.12), "scale": 0.70},
        {"file": "ice_boulder", "position": Vector3(-3.15, 18.75, -0.58), "rotation": Vector3(0.0, 0.55, -0.10), "scale": 0.70},
        {"file": "giant_chain", "collision": "trimesh", "position": Vector3(3.1, 19.2, -0.60), "rotation": Vector3(0.0, 0.0, 0.0), "scale": 0.58}
    ]

    for item in placements:
        var asset_path := "res://assets/" + str(item["file"]) + ".gltf"
        var packed := load(asset_path) as PackedScene
        if packed == null:
            push_warning("Could not load course asset: " + asset_path)
            continue
        var instance := packed.instantiate() as Node3D
        if instance == null:
            push_warning("Course asset root is not Node3D: " + asset_path)
            continue
        instance.name = "Course_" + str(item["file"])
        instance.position = item["position"]
        instance.rotation = item["rotation"]
        instance.scale = Vector3.ONE * float(item["scale"])
        add_child(instance)
        _add_asset_collisions(instance, str(item.get("collision", "convex")) == "trimesh")


func _add_asset_collisions(node: Node, trimesh := false) -> void:
    # Convex hulls are cheap, but fill in arches, holes and chains, so those assets
    # use an exact (static) triangle-mesh collider instead.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            if trimesh:
                mesh_instance.create_trimesh_collision()
            else:
                mesh_instance.create_convex_collision(true, true)
    for child in node.get_children():
        if child is not StaticBody3D:
            _add_asset_collisions(child, trimesh)


func _build_industrial_structures() -> void:
    # Weathered steel frames make the climb feel like an abandoned quarry.
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.16, 0.21, 0.24)
    steel.metallic = 0.88
    steel.roughness = 0.34
    var rust := StandardMaterial3D.new()
    rust.albedo_color = Color(0.34, 0.19, 0.11)
    rust.metallic = 0.62
    rust.roughness = 0.78

    for side in [-1.0, 1.0]:
        for level in range(3):
            var frame := Node3D.new()
            frame.position = Vector3(side * 4.8, 2.0 + float(level) * 6.0, -0.2)
            add_child(frame)
            _add_steel_beam(frame, Vector3(-0.85, -2.6, 0), Vector3(-0.85, 2.6, 0), 0.13, steel)
            _add_steel_beam(frame, Vector3(0.85, -2.6, 0), Vector3(0.85, 2.6, 0), 0.13, steel)
            _add_steel_beam(frame, Vector3(-0.85, 2.35, 0), Vector3(0.85, 2.35, 0), 0.16, rust)
            _add_steel_beam(frame, Vector3(-0.85, -2.3, 0), Vector3(0.85, 2.2, 0), 0.075, steel)
            _add_steel_beam(frame, Vector3(0.85, -2.3, 0), Vector3(-0.85, 2.2, 0), 0.075, steel)

            for post_x in [-0.85, 0.85]:
                var foot := MeshInstance3D.new()
                var foot_mesh := BoxMesh.new()
                foot_mesh.size = Vector3(0.48, 0.18, 0.48)
                foot.mesh = foot_mesh
                foot.position = Vector3(post_x, -2.58, 0)
                foot.material_override = rust
                frame.add_child(foot)

func _add_steel_beam(parent: Node3D, start: Vector3, finish: Vector3, width: float, material: Material) -> void:
    var beam := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(width, start.distance_to(finish), width)
    beam.mesh = mesh
    beam.position = (start + finish) * 0.5
    beam.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
    beam.material_override = material
    parent.add_child(beam)

func _build_checkpoints() -> void:
    # Checkpoints sit safely above the third and fifth ledges.
    checkpoint_positions = [
        Vector3(-1.35, 8.75, 0.0),
        Vector3(-1.35, 14.45, 0.0)
    ]
    for i in range(checkpoint_positions.size()):
        var marker := Node3D.new()
        marker.position = checkpoint_positions[i]
        add_child(marker)

        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.65
        ring_mesh.outer_radius = 0.82
        ring.mesh = ring_mesh
        # Keep the checkpoint ring facing the side-on camera.
        ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(0.15, 0.85, 0.62)
        ring_mat.emission_enabled = true
        ring_mat.emission = Color(0.05, 0.65, 0.42)
        ring_mat.emission_energy_multiplier = 1.4
        ring.material_override = ring_mat
        marker.add_child(ring)

        var beacon := MeshInstance3D.new()
        var beacon_mesh := CylinderMesh.new()
        beacon_mesh.top_radius = 0.035
        beacon_mesh.bottom_radius = 0.12
        beacon_mesh.height = 1.7
        beacon.mesh = beacon_mesh
        beacon.position.y = 0.9
        var beacon_mat := StandardMaterial3D.new()
        beacon_mat.albedo_color = Color(0.1, 0.75, 0.55, 0.28)
        beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        beacon_mat.emission_enabled = true
        beacon_mat.emission = Color(0.02, 0.35, 0.22)
        beacon.material_override = beacon_mat
        marker.add_child(beacon)

    _build_finish_marker()

func _build_finish_marker() -> void:
    finish_position = Vector3(-1.45, 21.0, 0.0)
    var marker := Node3D.new()
    marker.name = "SummitMarker"
    marker.position = finish_position
    add_child(marker)
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color(1.0, 0.78, 0.22)
    gold.metallic = 0.8
    gold.roughness = 0.3
    gold.emission_enabled = true
    gold.emission = Color(0.9, 0.55, 0.05)
    gold.emission_energy_multiplier = 1.3
    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.72
    ring_mesh.outer_radius = 0.95
    ring.mesh = ring_mesh
    ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    ring.material_override = gold
    marker.add_child(ring)

func _build_obstacles() -> void:
    # Compact edge-mounted pendulums: hazards challenge timing without sealing
    # the whole climbing lane like a flat wall across the screen.
    var hazard_material := StandardMaterial3D.new()
    hazard_material.albedo_color = Color(0.28, 0.095, 0.055)
    hazard_material.metallic = 0.72
    hazard_material.roughness = 0.34

    var warning_material := StandardMaterial3D.new()
    warning_material.albedo_color = Color(0.95, 0.34, 0.08)
    warning_material.metallic = 0.4
    warning_material.emission_enabled = true
    warning_material.emission = Color(0.8, 0.12, 0.015)
    warning_material.emission_energy_multiplier = 1.1

    var hazard_data := [
        {"x": -3.45, "y": 5.75, "phase": 0.0},
        {"x": 3.45, "y": 11.65, "phase": 1.8},
        {"x": -3.45, "y": 17.55, "phase": 3.2}
    ]
    for i in range(hazard_data.size()):
        var data: Dictionary = hazard_data[i]
        var obstacle := AnimatableBody3D.new()
        obstacle.name = "EdgePendulum_%d" % i
        obstacle.position = Vector3(float(data["x"]), float(data["y"]), 0.0)
        obstacle.sync_to_physics = true
        obstacle.add_to_group("climb_hazard")

        var pivot: Node3D = obstacle   # arm, weight and collision are children of the body itself
        var arm := MeshInstance3D.new()
        var arm_mesh := CylinderMesh.new()
        arm_mesh.top_radius = 0.075
        arm_mesh.bottom_radius = 0.11
        arm_mesh.height = 1.8
        arm.mesh = arm_mesh
        arm.position = Vector3(0.0, -0.9, 0.0)
        arm.material_override = hazard_material
        pivot.add_child(arm)

        var weight := MeshInstance3D.new()
        var weight_mesh := SphereMesh.new()
        weight_mesh.radius = 0.32
        weight_mesh.height = 0.64
        weight.mesh = weight_mesh
        weight.position = Vector3(0.0, -1.82, 0.0)
        weight.material_override = warning_material
        pivot.add_child(weight)

        var collision := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.radius = 0.24
        shape.height = 2.0
        collision.shape = shape
        collision.position = Vector3(0.0, -0.95, 0.0)
        pivot.add_child(collision)

        moving_obstacles.append(obstacle)
        add_child(obstacle)


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
    camera.position = Vector3(0, 2.0, 18.0)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.2
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    hud.name = "GameHUD"
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hud)

    # Top-left climbing telemetry: height, personal best and route progress.
    var info_panel := PanelContainer.new()
    info_panel.position = Vector2(22, 18)
    info_panel.custom_minimum_size = Vector2(330, 116)
    info_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.055, 0.075, 0.92)))
    hud.add_child(info_panel)

    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 3)
    info_panel.add_child(info)

    var title := Label.new()
    title.text = "CLIMB MASTER   /   ВЫСОТА"
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.52, 0.82, 0.83))
    info.add_child(title)

    height_label = Label.new()
    height_label.text = "0 м"
    height_label.add_theme_font_size_override("font_size", 34)
    height_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
    info.add_child(height_label)

    record_label = Label.new()
    record_label.text = "РЕКОРД  0 м"
    record_label.add_theme_font_size_override("font_size", 12)
    record_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.81))
    info.add_child(record_label)

    climb_progress = ProgressBar.new()
    climb_progress.custom_minimum_size = Vector2(0, 8)
    climb_progress.min_value = 0
    climb_progress.max_value = TOP_HEIGHT
    climb_progress.value = 0
    climb_progress.show_percentage = false
    climb_progress.add_theme_stylebox_override("background", _hud_panel_style(Color(0.12, 0.17, 0.20)))
    var progress_fill := StyleBoxFlat.new()
    progress_fill.bg_color = Color(0.20, 0.82, 0.70)
    progress_fill.corner_radius_top_left = 5
    progress_fill.corner_radius_top_right = 5
    progress_fill.corner_radius_bottom_left = 5
    progress_fill.corner_radius_bottom_right = 5
    climb_progress.add_theme_stylebox_override("fill", progress_fill)
    info.add_child(climb_progress)

    # Compact checkpoint badge.
    checkpoint_label = Label.new()
    checkpoint_label.text = "СТАРТ  •  КП 0"
    checkpoint_label.position = Vector2(22, 148)
    checkpoint_label.add_theme_font_size_override("font_size", 14)
    checkpoint_label.add_theme_color_override("font_color", Color(0.72, 0.94, 0.86))
    hud.add_child(checkpoint_label)

    # Top-right controls.
    var controls := HBoxContainer.new()
    controls.anchor_left = 1.0
    controls.anchor_right = 1.0
    controls.offset_left = -200
    controls.offset_right = -22
    controls.offset_top = 20
    controls.offset_bottom = 82
    controls.add_theme_constant_override("separation", 10)
    hud.add_child(controls)

    pause_button = Button.new()
    pause_button.text = "II"
    pause_button.tooltip_text = "Пауза"
    pause_button.custom_minimum_size = Vector2(62, 58)
    pause_button.add_theme_font_size_override("font_size", 24)
    _style_hud_button(pause_button, Color(0.08, 0.15, 0.18, 0.96))
    pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_button.pressed.connect(_toggle_pause)
    controls.add_child(pause_button)

    reset_button = Button.new()
    reset_button.text = "СБРОС"
    reset_button.tooltip_text = "Вернуться к контрольной точке"
    reset_button.custom_minimum_size = Vector2(96, 58)
    reset_button.add_theme_font_size_override("font_size", 15)
    _style_hud_button(reset_button, Color(0.20, 0.11, 0.09, 0.96))
    reset_button.process_mode = Node.PROCESS_MODE_ALWAYS
    reset_button.pressed.connect(_reset_player)
    controls.add_child(reset_button)

    # Bottom instruction strip stays clear of the character and touch area.
    var hint_panel := PanelContainer.new()
    hint_panel.anchor_left = 0.5
    hint_panel.anchor_right = 0.5
    hint_panel.anchor_top = 1.0
    hint_panel.anchor_bottom = 1.0
    hint_panel.offset_left = -250
    hint_panel.offset_right = 250
    hint_panel.offset_top = -66
    hint_panel.offset_bottom = -18
    hint_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.055, 0.075, 0.82)))
    hud.add_child(hint_panel)

    status_label = Label.new()
    status_label.text = "КАСАЙСЯ ЭКРАНА И ВЕДИ СЕРП  •  ЦЕПЛЯЙСЯ ЗА КРАЯ"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 14)
    status_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.92))
    hint_panel.add_child(status_label)

    restart_button = Button.new()
    restart_button.text = "ВЕРНУТЬСЯ К КОНТРОЛЬНОЙ ТОЧКЕ"
    restart_button.anchor_left = 0.5
    restart_button.anchor_right = 0.5
    restart_button.anchor_top = 0.5
    restart_button.anchor_bottom = 0.5
    restart_button.offset_left = -190
    restart_button.offset_right = 190
    restart_button.offset_top = 115
    restart_button.offset_bottom = 165
    restart_button.visible = false
    restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
    _style_hud_button(restart_button, Color(0.55, 0.20, 0.10, 0.98))
    restart_button.pressed.connect(_reset_player)
    hud.add_child(restart_button)

    # Pause screen with a clear resume action.
    pause_overlay = Control.new()
    pause_overlay.name = "PauseOverlay"
    pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_overlay.visible = false
    pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.add_child(pause_overlay)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.008, 0.018, 0.028, 0.78)
    pause_overlay.add_child(dim)

    var pause_card := PanelContainer.new()
    pause_card.anchor_left = 0.5
    pause_card.anchor_right = 0.5
    pause_card.anchor_top = 0.5
    pause_card.anchor_bottom = 0.5
    pause_card.offset_left = -190
    pause_card.offset_right = 190
    pause_card.offset_top = -145
    pause_card.offset_bottom = 145
    pause_card.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.045, 0.075, 0.09, 0.99)))
    pause_overlay.add_child(pause_card)

    var pause_content := VBoxContainer.new()
    pause_content.alignment = BoxContainer.ALIGNMENT_CENTER
    pause_content.add_theme_constant_override("separation", 15)
    pause_card.add_child(pause_content)

    var pause_title := Label.new()
    pause_title.text = "ПЕРЕДЫШКА"
    pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_title.add_theme_font_size_override("font_size", 28)
    pause_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.60))
    pause_content.add_child(pause_title)

    var pause_subtitle := Label.new()
    pause_subtitle.text = "Подумай над следующим движением"
    pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_subtitle.add_theme_font_size_override("font_size", 14)
    pause_subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.84))
    pause_content.add_child(pause_subtitle)

    var resume_button := Button.new()
    resume_button.text = "ПРОДОЛЖИТЬ ПОДЪЁМ"
    resume_button.custom_minimum_size = Vector2(300, 54)
    _style_hud_button(resume_button, Color(0.08, 0.42, 0.36, 1.0))
    resume_button.pressed.connect(_toggle_pause)
    pause_content.add_child(resume_button)

    var menu_reset := Button.new()
    menu_reset.text = "К КОНТРОЛЬНОЙ ТОЧКЕ"
    menu_reset.custom_minimum_size = Vector2(300, 48)
    _style_hud_button(menu_reset, Color(0.22, 0.14, 0.11, 1.0))
    menu_reset.pressed.connect(_reset_player)
    pause_content.add_child(menu_reset)

    _build_win_overlay(hud)
    # Touches that start on these controls must not swing the scythe.
    player.ui_blockers = [pause_button, reset_button, restart_button, win_overlay]


func _hud_panel_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.28, 0.58, 0.58, 0.72)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style


func _style_hud_button(button: Button, color: Color) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.border_color = Color(0.42, 0.76, 0.72, 0.8)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 12
    normal.content_margin_right = 12
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = color.lightened(0.16)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = color.darkened(0.18)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color(0.96, 0.98, 0.95))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _toggle_pause() -> void:
    player.release_pointer()
    get_tree().paused = not get_tree().paused
    if is_instance_valid(pause_button):
        pause_button.text = ">" if get_tree().paused else "II"
    if is_instance_valid(pause_overlay):
        pause_overlay.visible = get_tree().paused

func _physics_process(delta: float) -> void:
    obstacle_clock += delta
    for i in range(moving_obstacles.size()):
        var obstacle := moving_obstacles[i]
        if is_instance_valid(obstacle):
            obstacle.rotation.z = sin(obstacle_clock * (0.82 + float(i) * 0.13) + float(i) * 1.7) * 0.48

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var h := maxf(0.0, player.global_position.y - start_y)
    _check_checkpoint()
    if player.hook_feedback != last_player_feedback:
        last_player_feedback = player.hook_feedback
        status_label.text = last_player_feedback
    if h > best_height:
        var old_best := int(best_height)
        best_height = h
        if int(best_height) != old_best:
            _save_record()
    height_label.text = "%d м" % int(h)
    record_label.text = "РЕКОРД  %d м" % int(best_height)
    climb_progress.value = clampf(h, 0.0, TOP_HEIGHT)
    _check_finish()
    # Fixed, slightly elevated chase camera: it follows the climber but does not orbit.
    # Fixed side-on camera: no orbit, depth travel, or perspective drift.
    var target_camera := Vector3(player.global_position.x, player.global_position.y + 2.25, 18.0)
    camera.global_position = camera.global_position.lerp(target_camera, 1.0 - exp(-4.2 * delta))
    camera.look_at(player.global_position + Vector3(0, 2.25, 0), Vector3.UP)
    if player.global_position.y < -8.0 and not game_over:
        game_over = true
        status_label.text = "Падение! Нажми СБРОС, чтобы вернуться к контрольной точке."
        restart_button.visible = true

func _check_checkpoint() -> void:
    for i in range(active_checkpoint, checkpoint_positions.size()):
        if player.global_position.distance_to(checkpoint_positions[i]) < 1.45:
            active_checkpoint = i + 1
            status_label.text = "КОНТРОЛЬНАЯ ТОЧКА %d СОХРАНЕНА!" % active_checkpoint
            checkpoint_label.text = "КОНТРОЛЬНАЯ ТОЧКА  •  %d" % active_checkpoint

func _reset_player() -> void:
    get_tree().paused = false
    player.release_pointer()
    finished = false
    if is_instance_valid(win_overlay):
        win_overlay.visible = false
    if is_instance_valid(pause_button):
        pause_button.text = "II"
    if is_instance_valid(pause_overlay):
        pause_overlay.visible = false
    var respawn := Vector3(0, 1.0, 0)
    if active_checkpoint > 0:
        respawn = checkpoint_positions[active_checkpoint - 1] + Vector3(0, 0.65, 0)
    respawn.z = 0.0
    player.global_position = respawn
    player.velocity = Vector3.ZERO
    player.reset_hammer()
    game_over = false
    restart_button.visible = false
    status_label.text = "КАСАЙСЯ ЭКРАНА И ВЕДИ СЕРП  •  ЦЕПЛЯЙСЯ ЗА КРАЯ"


func _restart_run() -> void:
    active_checkpoint = 0
    checkpoint_label.text = "СТАРТ  •  КП 0"
    _reset_player()

func _check_finish() -> void:
    if finished:
        return
    if player.global_position.distance_to(finish_position) < 1.1:
        finished = true
        player.release_pointer()
        win_label.text = "ВЕРШИНА!\nРекорд: %d м" % int(best_height)
        win_overlay.visible = true
        _save_record()

func _build_win_overlay(hud: CanvasLayer) -> void:
    win_overlay = Control.new()
    win_overlay.name = "WinOverlay"
    win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    win_overlay.visible = false
    win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    hud.add_child(win_overlay)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.008, 0.018, 0.028, 0.72)
    win_overlay.add_child(dim)

    var card := PanelContainer.new()
    card.anchor_left = 0.5
    card.anchor_right = 0.5
    card.anchor_top = 0.5
    card.anchor_bottom = 0.5
    card.offset_left = -190
    card.offset_right = 190
    card.offset_top = -145
    card.offset_bottom = 145
    card.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.045, 0.075, 0.09, 0.99)))
    win_overlay.add_child(card)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 15)
    card.add_child(box)

    win_label = Label.new()
    win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    win_label.add_theme_font_size_override("font_size", 28)
    win_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.60))
    box.add_child(win_label)

    var again := Button.new()
    again.text = "НАЧАТЬ ЗАНОВО"
    again.custom_minimum_size = Vector2(300, 54)
    _style_hud_button(again, Color(0.08, 0.42, 0.36, 1.0))
    again.pressed.connect(_restart_run)
    box.add_child(again)

    var stay := Button.new()
    stay.text = "ОСТАТЬСЯ НА ВЕРШИНЕ"
    stay.custom_minimum_size = Vector2(300, 48)
    _style_hud_button(stay, Color(0.22, 0.14, 0.11, 1.0))
    stay.pressed.connect(func(): win_overlay.visible = false)
    box.add_child(stay)

func _load_record() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        best_height = float(cfg.get_value("progress", "best_height", 0.0))

func _save_record() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "best_height", best_height)
    cfg.save(SAVE_PATH)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_record()
