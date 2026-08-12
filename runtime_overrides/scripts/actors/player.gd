extends CharacterBody2D

signal died(player)

const CharacterDatabase = preload("res://scripts/data/character_database.gd")
const GameRules = preload("res://scripts/data/game_rules.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const WeaponController = preload("res://scripts/weapons/weapon_controller.gd")

var character_id = "nada"
var character_data = {}
var move_speed = 72.0
var facing = 1
var aim_direction = Vector2.RIGHT
var locked_aim = Vector2.RIGHT
var fire_was_held = false
var coyote_left = 0.0
var jump_buffer_left = 0.0
var dead = false
var sprite
var health
var weapons
var camera
var camera_target_offset = Vector2.ZERO

func setup(selected_id):
    character_id = selected_id

func _ready():
    add_to_group("players")
    collision_layer = 2
    collision_mask = 1
    character_data = CharacterDatabase.get_character(character_id)
    move_speed = float(character_data["move_speed"])

    var collider = CollisionShape2D.new()
    collider.name = "BodyCollider"
    var body_shape = RectangleShape2D.new()
    body_shape.size = GameRules.STANDARD_HITBOX_SIZE
    collider.shape = body_shape
    collider.position = Vector2(0, -2)
    add_child(collider)

    sprite = AnimatedSprite2D.new()
    sprite.name = "Sprite"
    sprite.position = Vector2(0, -18)
    # The source atlases were being displayed unnecessarily small on phones.
    # This still fits the standardized hitbox but keeps more of the authored pixel detail visible.
    sprite.scale = Vector2(0.54, 0.54)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.sprite_frames = _build_sprite_frames(load(character_data["atlas"]))
    add_child(sprite)
    sprite.play("idle")

    health = HealthComponent.new()
    health.name = "Health"
    health.configure(GameState.max_hp, GameRules.PLAYER_INVULNERABILITY)
    add_child(health)
    health.health_changed.connect(_on_health_changed)
    health.died.connect(_on_died)

    weapons = WeaponController.new()
    weapons.name = "Weapons"
    weapons.configure(self, character_data["fire_interval"], character_data["projectile_damage"])
    add_child(weapons)

    camera = Camera2D.new()
    camera.name = "Camera"
    # Camera coordinates are rounded every frame to keep the 240x160 viewport pixel-stable.
    camera.position_smoothing_enabled = false
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 960
    camera.limit_bottom = 160
    camera.enabled = true
    add_child(camera)

func _physics_process(delta):
    if dead:
        velocity.y += GameRules.GRAVITY * delta
        move_and_slide()
        _update_camera(delta)
        return

    var move_input = InputRouter.get_move_vector()
    _update_aim(move_input)

    if is_on_floor():
        coyote_left = GameRules.COYOTE_TIME
    else:
        coyote_left = max(0.0, coyote_left - delta)

    if InputRouter.is_action_just_pressed_mc("jump"):
        jump_buffer_left = GameRules.JUMP_BUFFER_TIME
    else:
        jump_buffer_left = max(0.0, jump_buffer_left - delta)

    if jump_buffer_left > 0.0 and coyote_left > 0.0:
        velocity.y = -GameRules.JUMP_SPEED
        jump_buffer_left = 0.0
        coyote_left = 0.0

    if not is_on_floor():
        var gravity_scale = 0.52 if velocity.y < 0.0 and InputRouter.is_action_pressed_mc("jump") else 1.0
        velocity.y += GameRules.GRAVITY * gravity_scale * delta

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

func _update_aim(move_input):
    var fire_held = InputRouter.is_action_pressed_mc("fire")
    var valid_input = _get_valid_aim(move_input)

    if fire_held and not fire_was_held:
        locked_aim = valid_input if valid_input != Vector2.ZERO else Vector2(facing, 0)

    if fire_held:
        if move_input.y != 0.0:
            locked_aim = valid_input
        elif move_input.x != 0.0 and int(sign(move_input.x)) == facing:
            locked_aim = valid_input
        aim_direction = locked_aim.normalized()
        if aim_direction.x != 0.0:
            facing = int(sign(aim_direction.x))
    else:
        if move_input.x != 0.0:
            facing = int(sign(move_input.x))
        aim_direction = valid_input if valid_input != Vector2.ZERO else Vector2(facing, 0)
        locked_aim = aim_direction

    fire_was_held = fire_held
    sprite.flip_h = facing < 0

func _get_valid_aim(move_input):
    var result = Vector2(sign(move_input.x), sign(move_input.y))
    if is_on_floor() and result.y > 0.0:
        result.y = 0.0
        if result.x == 0.0:
            result.x = facing
    if result == Vector2.ZERO:
        return Vector2.ZERO
    return result.normalized()

func _update_camera(delta):
    if camera == null:
        return
    var look_x = float(facing) * 24.0
    if InputRouter.is_action_pressed_mc("fire") and abs(aim_direction.x) > 0.1:
        look_x = aim_direction.x * 30.0
    var look_y = -8.0 if aim_direction.y < -0.2 else (8.0 if aim_direction.y > 0.2 and not is_on_floor() else 0.0)
    camera_target_offset = Vector2(look_x, look_y)
    var blend = min(1.0, delta * 7.5)
    var next_position = camera.position.lerp(camera_target_offset, blend)
    camera.position = Vector2(round(next_position.x), round(next_position.y))

func _update_animation(move_input):
    var desired = "idle"
    if not is_on_floor():
        desired = "jump"
    elif InputRouter.is_action_pressed_mc("fire") and abs(velocity.x) < 1.0 and abs(aim_direction.y) < 0.35:
        desired = "shoot"
    elif abs(velocity.x) > 1.0:
        desired = "run"
    if sprite.animation != desired:
        sprite.play(desired)

func _update_invulnerability_visual():
    if health.is_invulnerable() and not dead:
        sprite.visible = int(Time.get_ticks_msec() / 70) % 2 == 0
    else:
        sprite.visible = true

func _build_sprite_frames(texture):
    var frames = SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    _add_animation(frames, texture, "idle", [0, 1, 2, 3, 4, 5], 7.0, true)
    _add_animation(frames, texture, "run", [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], 13.0, true)

    # Nada's original firing range crosses source-pose boundaries. These clean
    # full-height ready-fire frames prevent the clipped fragment that was appearing
    # behind her until the dedicated production firing strip is wired into the repo.
    if character_id == "nada":
        _add_animation(frames, texture, "shoot", [24, 25, 26, 27, 28, 29], 10.0, true)
    else:
        _add_animation(frames, texture, "shoot", [34, 35, 36, 37, 38, 39], 14.0, true)

    _add_animation(frames, texture, "jump", [40, 41, 42, 43, 44, 45, 46, 47], 10.0, true)
    _add_animation(frames, texture, "death", [56, 57, 58, 59, 60, 61, 62, 63], 9.0, false)
    _add_animation(frames, texture, "climb", [64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79], 10.0, true)
    return frames

func _add_animation(frames, texture, animation_name, indices, fps, should_loop):
    frames.add_animation(animation_name)
    frames.set_animation_speed(animation_name, fps)
    frames.set_animation_loop(animation_name, should_loop)
    for index in indices:
        var atlas = AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = Rect2((index % 10) * 224, int(index / 10) * 160, 224, 160)
        frames.add_frame(animation_name, atlas)

func take_damage(amount, source_position = Vector2.ZERO):
    if dead:
        return false
    if health.damage(amount):
        GameState.reset_combo()
        var direction = sign(global_position.x - source_position.x)
        if direction == 0.0:
            direction = -facing
        velocity.x = direction * 55.0
        velocity.y = -58.0
        return true
    return false

func heal(amount):
    health.heal(amount)

func equip_special(weapon_id):
    weapons.equip_special(weapon_id)

func get_special_weapon():
    return weapons.special_weapon

func respawn_at(position_value):
    global_position = position_value
    velocity = Vector2.ZERO
    dead = false
    collision_layer = 2
    collision_mask = 1
    health.restore_full()
    weapons.clear_special()
    sprite.visible = true
    sprite.play("idle")

func _on_health_changed(current, maximum):
    GameState.max_hp = maximum
    GameState.set_player_hp(current)

func _on_died():
    if dead:
        return
    dead = true
    collision_layer = 0
    collision_mask = 1
    weapons.clear_special()
    sprite.play("death")
    died.emit(self)

func _draw():
    if GameState.debug_collision_visible:
        draw_rect(Rect2(Vector2(-6.5, -16.5), Vector2(13, 29)), Color(0.1, 1.0, 0.2, 0.55), false, 1.0)
