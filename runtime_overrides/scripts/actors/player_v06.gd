extends "res://scripts/actors/player.gd"

const GameRulesV06 = preload("res://scripts/data/game_rules.gd")
const LADDER_SPEED = 54.0
const LADDER_SNAP_SPEED = 210.0

var ladder_contacts = []
var climbing = false
var active_ladder = null

func register_ladder(ladder):
    if ladder == null or not is_instance_valid(ladder):
        return
    if not ladder_contacts.has(ladder):
        ladder_contacts.append(ladder)

func unregister_ladder(ladder):
    ladder_contacts.erase(ladder)
    if climbing and active_ladder == ladder:
        _leave_ladder()

func _physics_process(delta):
    if dead:
        if climbing:
            _leave_ladder()
        super._physics_process(delta)
        return

    _prune_ladder_contacts()
    var move_input = InputRouter.get_move_vector()

    if climbing and (active_ladder == null or not is_instance_valid(active_ladder)):
        _leave_ladder()

    if not climbing:
        _try_mount_ladder(move_input)

    if climbing:
        _physics_process_ladder(delta, move_input)
        return

    # Canonical ground/air movement remains identical to the stable v0.5 player.
    _update_aim(move_input)

    if is_on_floor():
        coyote_left = GameRulesV06.COYOTE_TIME
    else:
        coyote_left = max(0.0, coyote_left - delta)

    if InputRouter.is_action_just_pressed_mc("jump"):
        jump_buffer_left = GameRulesV06.JUMP_BUFFER_TIME
    else:
        jump_buffer_left = max(0.0, jump_buffer_left - delta)

    if jump_buffer_left > 0.0 and coyote_left > 0.0:
        velocity.y = -GameRulesV06.JUMP_SPEED
        jump_buffer_left = 0.0
        coyote_left = 0.0

    if not is_on_floor():
        var gravity_scale = 0.52 if velocity.y < 0.0 and InputRouter.is_action_pressed_mc("jump") else 1.0
        velocity.y += GameRulesV06.GRAVITY * gravity_scale * delta

    if InputRouter.is_action_just_released_mc("jump") and velocity.y < -55.0:
        velocity.y *= 0.42

    velocity.x = move_input.x * move_speed

    if InputRouter.is_action_pressed_mc("fire"):
        weapons.fire_default(aim_direction)
    if InputRouter.is_action_pressed_mc("special"):
        weapons.fire_special(aim_direction)

    move_and_slide()

    if global_position.y > 190.0:
        health.force_kill()

    _update_animation(move_input)
    _update_invulnerability_visual()
    _update_camera(delta)
    if GameState.debug_collision_visible:
        queue_redraw()

func _try_mount_ladder(move_input):
    if abs(move_input.y) < 0.2:
        return

    var best_ladder = null
    var best_distance = 99999.0
    for ladder in ladder_contacts:
        if ladder == null or not is_instance_valid(ladder):
            continue
        if not ladder.has_method("can_mount"):
            continue
        if not ladder.can_mount(global_position, move_input.y):
            continue
        var distance_x = abs(global_position.x - ladder.center_x)
        if distance_x < best_distance:
            best_distance = distance_x
            best_ladder = ladder

    if best_ladder == null:
        return

    active_ladder = best_ladder
    climbing = true
    velocity = Vector2.ZERO
    coyote_left = 0.0
    jump_buffer_left = 0.0
    fire_was_held = false
    sprite.flip_h = false
    sprite.speed_scale = 1.0
    if sprite.animation != "climb":
        sprite.play("climb")

func _physics_process_ladder(delta, move_input):
    if active_ladder == null or not is_instance_valid(active_ladder):
        _leave_ladder()
        return

    # Jump cleanly dismounts without changing the established jump envelope.
    if InputRouter.is_action_just_pressed_mc("jump"):
        var launch_dir = int(sign(move_input.x))
        if launch_dir == 0:
            launch_dir = facing
        _leave_ladder()
        velocity.x = float(launch_dir) * move_speed * 0.48
        velocity.y = -GameRulesV06.JUMP_SPEED * 0.78
        move_and_slide()
        _update_animation(move_input)
        _update_invulnerability_visual()
        _update_camera(delta)
        return

    global_position.x = move_toward(global_position.x, active_ladder.center_x, LADDER_SNAP_SPEED * delta)
    velocity.x = 0.0
    velocity.y = move_input.y * LADDER_SPEED

    # No weapon fire while climbing. Direction is retained for the dismount.
    fire_was_held = false
    aim_direction = Vector2(float(facing), 0.0)
    locked_aim = aim_direction
    sprite.flip_h = false

    move_and_slide()

    if active_ladder.should_exit_top(global_position.y, move_input.y):
        var exit_position = active_ladder.get_top_standing_position()
        _leave_ladder()
        global_position = exit_position
        velocity = Vector2.ZERO
    elif active_ladder != null and is_instance_valid(active_ladder) and active_ladder.should_exit_bottom(global_position.y, move_input.y):
        var bottom_position = active_ladder.get_bottom_standing_position()
        _leave_ladder()
        global_position = bottom_position
        velocity = Vector2.ZERO

    if global_position.y > 190.0:
        health.force_kill()

    _update_animation(move_input)
    _update_invulnerability_visual()
    _update_camera(delta)
    if GameState.debug_collision_visible:
        queue_redraw()

func _leave_ladder():
    climbing = false
    active_ladder = null
    if sprite != null:
        sprite.speed_scale = 1.0

func _prune_ladder_contacts():
    for index in range(ladder_contacts.size() - 1, -1, -1):
        var ladder = ladder_contacts[index]
        if ladder == null or not is_instance_valid(ladder):
            ladder_contacts.remove_at(index)

func _update_animation(move_input):
    if climbing:
        if sprite.animation != "climb":
            sprite.play("climb")
        sprite.speed_scale = 1.0 if abs(velocity.y) > 1.0 else 0.0
        return

    if sprite.speed_scale == 0.0:
        sprite.speed_scale = 1.0
    super._update_animation(move_input)

func take_damage(amount, source_position = Vector2.ZERO):
    if climbing:
        _leave_ladder()
    return super.take_damage(amount, source_position)

func respawn_at(position_value):
    _leave_ladder()
    super.respawn_at(position_value)

func _on_died():
    if climbing:
        _leave_ladder()
    super._on_died()
