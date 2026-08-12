extends Control

const DPAD_CENTER = Vector2(39, 120)
const DPAD_TOUCH_RADIUS = 43.0
const DPAD_DEAD_ZONE = 8.0
const DPAD_VISUAL_OFFSET = 17.0
const BUTTONS = {
    "fire": {"center": Vector2(213, 120), "touch_radius": 25.0, "visual_radius": 16.0, "label": "FIRE"},
    "jump": {"center": Vector2(176, 132), "touch_radius": 24.0, "visual_radius": 15.0, "label": "JUMP"},
    "special": {"center": Vector2(207, 82), "touch_radius": 22.0, "visual_radius": 13.0, "label": "SP"}
}

var active_touches = {}
var pressed_dpad_direction = Vector2.ZERO

func _ready():
    position = Vector2.ZERO
    size = Vector2(240, 160)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    queue_redraw()

func _process(_delta):
    visible = GameState.touch_controls_visible
    queue_redraw()

func _input(event):
    if not visible:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            _press_touch(event.index, event.position)
        else:
            _release_touch(event.index)
    elif event is InputEventScreenDrag:
        _move_touch(event.index, event.position)

func _press_touch(index, pos):
    if pos.x < 96.0 and pos.distance_to(DPAD_CENTER) <= DPAD_TOUCH_RADIUS + 10.0:
        active_touches[index] = {"type": "dpad"}
        _update_dpad(pos)
        return

    for action_name in BUTTONS.keys():
        var data = BUTTONS[action_name]
        if pos.distance_to(data["center"]) <= float(data["touch_radius"]):
            active_touches[index] = {"type": "button", "action": action_name}
            InputRouter.set_touch_action(action_name, true)
            return

func _move_touch(index, pos):
    if not active_touches.has(index):
        _press_touch(index, pos)
        return

    var touch = active_touches[index]
    if touch["type"] == "dpad":
        if pos.x < 104.0:
            _update_dpad(pos)
        else:
            pressed_dpad_direction = Vector2.ZERO
            InputRouter.set_touch_move(Vector2.ZERO)
    elif touch["type"] == "button":
        var action_name = touch["action"]
        var data = BUTTONS[action_name]
        var still_inside = pos.distance_to(data["center"]) <= float(data["touch_radius"]) + 6.0
        InputRouter.set_touch_action(action_name, still_inside)

func _release_touch(index):
    if not active_touches.has(index):
        return
    var touch = active_touches[index]
    if touch["type"] == "dpad":
        pressed_dpad_direction = Vector2.ZERO
        InputRouter.set_touch_move(Vector2.ZERO)
    elif touch["type"] == "button":
        InputRouter.set_touch_action(touch["action"], false)
    active_touches.erase(index)

func _update_dpad(pos):
    var delta = pos - DPAD_CENTER
    if delta.length() < DPAD_DEAD_ZONE:
        pressed_dpad_direction = Vector2.ZERO
        InputRouter.set_touch_move(Vector2.ZERO)
        return

    var angle = atan2(delta.y, delta.x)
    var sector = int(round(angle / (PI / 4.0)))
    var dir = Vector2.ZERO
    match sector:
        0: dir = Vector2(1, 0)
        1: dir = Vector2(1, 1)
        2: dir = Vector2(0, 1)
        3: dir = Vector2(-1, 1)
        4, -4: dir = Vector2(-1, 0)
        -3: dir = Vector2(-1, -1)
        -2: dir = Vector2(0, -1)
        -1: dir = Vector2(1, -1)
    pressed_dpad_direction = dir
    InputRouter.set_touch_move(dir)

func _draw():
    if not visible:
        return
    _draw_dpad()
    for action_name in BUTTONS.keys():
        _draw_action_button(action_name)

func _draw_dpad():
    var active = pressed_dpad_direction != Vector2.ZERO
    var base_alpha = 0.18 if not active else 0.29
    var edge_alpha = 0.34 if not active else 0.56
    var plate = Color(0.04, 0.07, 0.06, base_alpha)
    var edge = Color(0.78, 0.94, 0.86, edge_alpha)
    var glow = Color(0.45, 1.0, 0.30, 0.26 if active else 0.08)

    draw_circle(DPAD_CENTER, 11.0, plate, true, -1.0, true)
    draw_circle(DPAD_CENTER, 11.0, edge, false, 1.0, true)

    var dirs = {
        "up": Vector2(0, -1),
        "down": Vector2(0, 1),
        "left": Vector2(-1, 0),
        "right": Vector2(1, 0)
    }
    for key in dirs.keys():
        var dir = dirs[key]
        var center = DPAD_CENTER + dir * DPAD_VISUAL_OFFSET
        var is_pressed = _direction_matches(dir)
        var local_plate = Color(0.05, 0.08, 0.07, 0.44 if is_pressed else base_alpha)
        var local_edge = Color(0.55, 1.0, 0.34, 0.74) if is_pressed else edge
        draw_circle(center, 12.5, local_plate, true, -1.0, true)
        draw_circle(center, 12.5, local_edge, false, 1.0, true)
        if is_pressed:
            draw_circle(center, 8.5, glow, true, -1.0, true)
        _draw_arrow(center, dir, Color(0.92, 1.0, 0.94, 0.76 if is_pressed else 0.48))

func _direction_matches(cardinal: Vector2):
    if cardinal.x != 0.0:
        return sign(pressed_dpad_direction.x) == sign(cardinal.x)
    if cardinal.y != 0.0:
        return sign(pressed_dpad_direction.y) == sign(cardinal.y)
    return false

func _draw_arrow(center: Vector2, dir: Vector2, color: Color):
    var forward = dir * 5.0
    var side = Vector2(-dir.y, dir.x) * 3.0
    draw_polygon(PackedVector2Array([
        center + forward,
        center - forward * 0.55 + side,
        center - forward * 0.55 - side
    ]), PackedColorArray([color, color, color]))

func _draw_action_button(action_name: String):
    var data = BUTTONS[action_name]
    var center = data["center"]
    var radius = float(data["visual_radius"])
    var pressed = InputRouter.is_action_pressed_mc(action_name)
    var fill = Color(0.04, 0.07, 0.06, 0.46 if pressed else 0.18)
    var edge = Color(0.55, 1.0, 0.34, 0.80) if pressed else Color(0.82, 0.94, 0.88, 0.36)
    var inner = Color(0.42, 1.0, 0.26, 0.24 if pressed else 0.06)

    draw_circle(center, radius, fill, true, -1.0, true)
    draw_circle(center, radius, edge, false, 1.0, true)
    draw_circle(center, radius - 3.0, inner, true, -1.0, true)

    var label = str(data["label"])
    var font_size = 5 if label.length() > 2 else 6
    draw_string(
        ThemeDB.fallback_font,
        center + Vector2(-radius, 2),
        label,
        HORIZONTAL_ALIGNMENT_CENTER,
        radius * 2.0,
        font_size,
        Color(0.96, 1.0, 0.97, 0.90)
    )
