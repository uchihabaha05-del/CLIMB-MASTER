extends SceneTree

const CORE = preload("res://scripts/climb_physics_2d.gd")
const WAIT_FRAMES := 240

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node2D.new()
    root.add_child(world)
    var core := CORE.new()
    world.add_child(core)
    await process_frame
    core.add_static_box(Vector2(0.0, 2.0), Vector2(30.0, 0.5), 0.0, 1.0, 0.0)
    var wall := core.add_static_box(Vector2(3.0, -0.2), Vector2(0.35, 8.0), 0.0, 0.9, 0.0)
    core.configure_start(Vector2(0.0, -0.1))
    await physics_frame
    var start_y := core.pot.global_position.y
    for i in range(WAIT_FRAMES):
        await physics_frame
    var floor_ok := core.pot.global_position.y > 0.8 and core.pot.global_position.y < 2.0
    _assert(floor_ok, "Pot must settle on the floor, not tunnel through it")
    _assert(not core.last_contact, "Hammer-to-pot contact must not be reported as a world hook")

    # A fixed target does not inject upward velocity into the pot.
    core.set_target_world(Vector2(0.8, -2.0))
    var stable_y := core.pot.global_position.y
    for i in range(120):
        await physics_frame
    var idle_ok := core.pot.global_position.y >= stable_y - 0.45
    _assert(idle_ok, "A stationary finger must not launch the pot")

    # Isolate the reaction check from floor friction: in zero gravity,
    # the hammer must push the freely suspended pot when its head hits the wall.
    core.pot.gravity_scale = 0.0
    core.hammer.gravity_scale = 0.0
    core.pot.mass = 50.0
    core.configure_start(Vector2(0.0, 0.0))
    await physics_frame
    var pot_before := core.pot.global_position
    core.set_target_world(Vector2(3.8, 0.4))
    for i in range(300):
        await physics_frame
    var shoulder_alignment := core.hammer.global_position.distance_to(core.shoulder_anchor.global_position)
    _assert(shoulder_alignment < 0.12, "Hammer grip must stay aligned with the shoulder constraint")
    var hammer_contacts := core.hammer.get_contact_count()
    var wall_contact := core.hammer.get_colliding_bodies().has(wall)
    var hammer_head := core.hammer.to_global(Vector2(0.88, -3.13))
    var head_before_wall := hammer_head.x <= 3.08
    _assert(wall_contact and head_before_wall, "Hammer head must contact the wall without tunnelling")
    _assert(core.last_contact, "World contact must be exposed to the climbing HUD")
    var pot_displacement := core.pot.global_position.distance_to(pot_before)
    print("PHYSICS_DIAGNOSTIC: pot_before=", pot_before, " pot_after=", core.pot.global_position,
        " displacement=", pot_displacement, " pot_rotation=", core.pot.rotation,
        " hammer_position=", core.hammer.global_position, " hammer_head=", hammer_head,
        " hammer_rotation=", core.hammer.rotation, " contacts=", hammer_contacts,
        " COM_mode=", core.hammer.center_of_mass_mode, " COM=", core.hammer.center_of_mass,
        " shoulder_anchor=", core.shoulder_anchor.global_position)
    var reaction_ok := pot_displacement > 0.025 or absf(core.pot.rotation) > 0.025
    _assert(reaction_ok, "Hammer contact must transfer motion through the shoulder joint")

    # Surface materials and reset must remain deterministic after a fall.
    var ice := core.add_static_box(Vector2(-5.0, 0.0), Vector2(1.0, 1.0), 0.0, 0.035)
    var rock := core.add_static_box(Vector2(-7.0, 0.0), Vector2(1.0, 1.0), 0.0, 1.18)
    var capsule := core.add_static_capsule(Vector2(-9.0, 0.0), 0.3, 1.2, 0.0, 0.42)
    _assert(ice.physics_material_override.friction < rock.physics_material_override.friction,
        "Ice must be more slippery than rock")
    _assert(is_equal_approx(capsule.physics_material_override.friction, 0.42),
        "Capsule colliders must preserve their source surface friction")
    core.pot.linear_velocity = Vector2(4.0, 2.0)
    core.reset_to(Vector2(-2.0, -1.0))
    await physics_frame
    var reset_position_ok := core.pot.global_position.distance_to(Vector2(-2.0, -1.0)) < 0.08
    var reset_hammer_ok := core.hammer.global_position.distance_to(core.pot.global_position + Vector2(0.30, -0.72)) < 0.08
    var reset_velocity_ok := core.pot.linear_velocity.length() < 0.05 and core.hammer.linear_velocity.length() < 0.05
    print("RESET_DIAGNOSTIC: pot=", core.pot.global_position, " hammer=", core.hammer.global_position,
        " expected_hammer=", core.pot.global_position + Vector2(0.30, -0.72),
        " pot_velocity=", core.pot.linear_velocity, " hammer_velocity=", core.hammer.linear_velocity,
        " rotation=", core.hammer.rotation, " target=", core.target_angle)
    _assert(reset_position_ok and reset_hammer_ok and reset_velocity_ok,
        "Reset must restore pot, hammer anchor and velocity")

    print("CLIMB_PHYSICS_2D_TESTS: ", "PASS" if _failures == 0 else "FAIL")
    quit(0 if _failures == 0 else 1)

var _failures := 0

func _assert(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error("TEST FAILED: " + message)
    else:
        print("TEST PASSED: " + message)
