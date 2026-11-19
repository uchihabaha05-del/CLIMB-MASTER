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
    core.add_static_box(Vector2(3.0, -0.2), Vector2(0.35, 8.0), 0.0, 0.9, 0.0)
    core.configure_start(Vector2(0.0, -0.1))
    await physics_frame
    var start_y := core.pot.global_position.y
    for i in range(WAIT_FRAMES):
        await physics_frame
    var floor_ok := core.pot.global_position.y > 0.8 and core.pot.global_position.y < 2.0
    _assert(floor_ok, "Pot must settle on the floor, not tunnel through it")

    # A fixed target does not inject upward velocity into the pot.
    core.set_target_world(Vector2(0.8, -2.0))
    var stable_y := core.pot.global_position.y
    for i in range(120):
        await physics_frame
    var idle_ok := core.pot.global_position.y >= stable_y - 0.45
    _assert(idle_ok, "A stationary finger must not launch the pot")

    # Drive the hammer into the vertical wall. Continuous collision and the
    # pin joint should stop it at the wall and transfer reaction to the pot.
    var pot_before := core.pot.global_position
    core.set_target_world(Vector2(2.8, -1.0))
    for i in range(180):
        await physics_frame
    var joint_a := core.shoulder_joint.get_node_or_null(core.shoulder_joint.node_a)
    var joint_b := core.shoulder_joint.get_node_or_null(core.shoulder_joint.node_b)
    var joint_ok := joint_a == core.pot and joint_b == core.hammer
    _assert(joint_ok, "Shoulder joint must resolve both intended rigid bodies")
    var hammer_contacts := core.hammer.get_contact_count()
    var hammer_ok := hammer_contacts > 0
    _assert(hammer_ok, "Hammer must make physical contact with the wall")
    var pot_displacement := core.pot.global_position.distance_to(pot_before)
    print("PHYSICS_DIAGNOSTIC: pot_before=", pot_before, " pot_after=", core.pot.global_position,
        " displacement=", pot_displacement, " pot_rotation=", core.pot.rotation,
        " hammer_position=", core.hammer.global_position, " hammer_rotation=", core.hammer.rotation,
        " hammer_velocity=", core.hammer.linear_velocity, " contacts=", hammer_contacts,
        " joint_a=", joint_a, " joint_b=", joint_b, " joint_anchor=", core.shoulder_joint.global_position)
    var reaction_ok := pot_displacement > 0.04 or absf(core.pot.rotation) > 0.04
    _assert(reaction_ok, "Hammer contact must transfer motion through the shoulder joint")

    print("CLIMB_PHYSICS_2D_TESTS: ", "PASS" if _failures == 0 else "FAIL")
    quit(0 if _failures == 0 else 1)

var _failures := 0

func _assert(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error("TEST FAILED: " + message)
    else:
        print("TEST PASSED: " + message)
