extends Control

const DPAD_CENTER = Vector2(39, 120)
const DPAD_TOUCH_RADIUS = 43.0
const DPAD_DEAD_ZONE = 8.0
const DPAD_VISUAL_OFFSET = 16.5
const BUTTONS = {
    "fire": {"center": Vector2(213, 120), "touch_radius": 25.0, "visual_radius": 15.5, "label": "FIRE"},
    "jump": {"center": Vector2(176, 132), "touch_radius": 24.0, "visual_radius": 14.5, "label": "JUMP"},
    "special": {"center": Vector2(207, 82), "touch_radius": 22.0, "visual_radius": 12.5, "label": "SP"}
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
    var idle_fill = 0.10
    var active_fill = 0.32
    var idle_edge = 0.20

    # One faint outer guide makes the pad read as a single control rather than four
    # opaque bubbles while keeping most of the playfield visible underneath it.
    draw_circle(DPAD_CENTER, 31.5, Color(0.03, 0.06, 0.055, 0.055 if not active else 0.09), true, -1.0, true)
    draw_circle(DPAD_CENTER, 31.5, Color(0.78, 0.94, 0.86, 0.13 if not active else 0.24), false, 1.0, true)
    draw_circle(DPAD_CENTER, 8.0, Color(0.04, 0.07, 0.065, 0.13 if not active else 0.24), true, -1.0, true)
    draw_circle(DPAD_CENTER, 8.0, Color(0.82, 0.96, 0.88, 0.19 if not active else 0.38), false, 1.0, true)

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
        var local_plate = Color(0.04, 0.075, 0.065, active_fill if is_pressed else idle_fill)
        var local_edge = Color(0.55, 1.0, 0.34, 0.70) if is_pressed else Color(0.84, 0.96, 0.89, idle_edge)
        draw_circle(center, 10.5, local_plate, true, -1.0, true)
        draw_circle(center, 10.5, local_edge, false, 1.0, true)
        if is_pressed:
            draw_circle(center, 7.0, Color(0.43, 1.0, 0.29, 0.18), true, -1.0, true)
        _draw_arrow(center, dir, Color(0.94, 1.0, 0.96, 0.82 if is_pressed else 0.46))

func _direction_matches(cardinal: Vector2):
    if cardinal.x != 0.0:
        return sign(pressed_dpad_direction.x) == sign(cardinal.x)
    if cardinal.y != 0.0:
        return sign(pressed_dpad_direction.y) == sign(cardinal.y)
    return false

func _draw_arrow(center: Vector2, dir: Vector2, color: Color):
    var forward = dir * 4.4
    var side = Vector2(-dir.y, dir.x) * 2.7
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
    var fill = Color(0.035, 0.065, 0.058, 0.34 if pressed else 0.095)
    var edge = Color(0.55, 1.0, 0.34, 0.72) if pressed else Color(0.84, 0.95, 0.89, 0.22)
    var inner = Color(0.42, 1.0, 0.26, 0.16 if pressed else 0.035)

    # Double-ring glass treatment: touch targets remain large, visuals stay light.
    draw_circle(center, radius, fill, true, -1.0, true)
    draw_circle(center, radius, edge, false, 1.0, true)
    draw_circle(center, radius - 3.0, inner, true, -1.0, true)
    draw_circle(center, radius - 3.0, Color(0.94, 1.0, 0.96, 0.12 if pressed else 0.07), false, 1.0, true)

    var label = str(data["label"])
    var font_size = 5 if label.length() > 2 else 6
    draw_string(
        ThemeDB.fallback_font,
        center + Vector2(-radius, 2),
        label,
        HORIZONTAL_ALIGNMENT_CENTER,
        radius * 2.0,
        font_size,
        Color(0.97, 1.0, 0.98, 0.90 if pressed else 0.66)
    )
