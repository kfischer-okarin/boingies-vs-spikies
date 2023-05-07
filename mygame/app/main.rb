require "app/base.rb"
require "app/camera.rb"
require "app/camera_movement.rb"
require "app/pathfinding.rb"
require "app/turret.rb"
require "app/essence.rb"
require "app/stage_editor.rb"

def tick(args)
  setup(args) if args.tick_count.zero?

  case args.state.scene
  when :game
    game_tick(args)
  when :stage_editor
    StageEditor.tick(args)
  end
end

# TODO: should we move these game_* to a Game class/module?
def game_tick(args)
  game_process_inputs(args)
  game_update(args)
  game_render(args)
end

def setup(args)
  args.state.show_debug_info = false
  args.state.scene = :game
  args.state.stage = load_stage
  args.state.navigation_grid = Pathfinding.build_navigation_grid(args.state.stage, spacing: 30, grid_type: Pathfinding::HexGrid)
  args.state.enemies = []
  args.state.base = Base.build args.state.stage
  args.state.camera = Camera.build center_x: args.state.base[:x], center_y: args.state.base[:y]
  args.state.launcher = {state: :idle, power: 0, direction: nil}
  args.state.launched_turrets = []
  args.state.stationary_turrets = []
  args.state.projectiles = []

  args.state.dmg_popups = []
  args.state.escessence_drops = []
  args.state.essence_held = 0
end

def load_stage
  $gtk.deserialize_state("stage")
end

def game_process_inputs(args)
  unless game_over?(args)
    CameraMovement.control_camera(
      mouse: args.inputs.mouse,
      camera: args.state.camera,
      stage: args.state.stage
    )
    control_launcher(args)

    unless $gtk.production?
      StageEditor.handle_onoff(args)
      handle_toggle_debug_info(args)
    end
  end
  $gtk.reset if args.inputs.keyboard.key_up.r
end

def control_launcher args
  m = args.inputs.mouse
  launcher = args.state.launcher

  case launcher[:state]
  when :idle
    if m.click
      launcher[:state] = :charging
      launcher[:power] = 0
    end
  when :charging
    launcher[:direction] = calculate_launcher_direction(args, m)
    if m.click
      args.state.launched_turrets << build_turret(args)
      launcher[:state] = :idle
      launcher[:power] = 0
    end
  end
end

def calculate_launcher_direction(args, mouse)
  # to get the correct direction vector
  base_on_screen = Camera.transform args.state.camera, args.state.base
  direction = Matrix.vec2(
    mouse.x - base_on_screen.x,
    mouse.y - base_on_screen.y
  )
  Matrix.normalize! direction
  direction
end

def build_turret(args)
  p = args.state.base
  launcher = args.state.launcher
  options = [:bigRoller, :pdc, :stickers]
  #CD should be based on turret type
  {x: p.x, y: p.y, w: 20, h: 20, dx: launcher[:direction].x, dy: launcher[:direction].y,
    pow: launcher[:power] / 5, logical_x: p.x, logical_y: p.y, type: options[0], cd:60}
end

def handle_toggle_debug_info(args)
  return unless args.inputs.keyboard.key_down.nine

  args.state.show_debug_info = !args.state.show_debug_info
end

def game_update(args)
  return if game_over?(args)

  spawn_spikey(args) if args.tick_count.mod_zero? 60
  move_enemies(args)
  handle_enemy_vs_base_collisions(args)
  handle_dead_enemies(args)
  update_launcher(args)
  update_launched_turrets(args)
  tick_turret(args)
  update_dmg_popups(args)
  update_essence(args)
end

def spawn_spikey(args)
  direction = %i[top right bottom left].sample
  bounds = stage_bounds(args.state.stage)
  case direction
  when :top
    x = bounds.left + rand(bounds.w)
    y = bounds.top
  when :right
    x = bounds.right
    y = bounds.bottom + rand(bounds.h)
  when :bottom
    x = bounds.left + rand(bounds.w)
    y = bounds.bottom
  when :left
    x = bounds.left
    y = bounds.bottom + rand(bounds.h)
  end

  args.state.enemies << {
    x: x, y: y, w: 100, h: 100,
    anchor_x: 0.5, anchor_y: 0.5,
    health: 100,
    type: :spikey_ball,
    essence_amount: 10
  }
end

def move_enemies(args)
  args.state.enemies.each do |enemy|
    to_base = Pathfinding.direction_to_base(args.state.navigation_grid, enemy)
    speed = 2
    enemy[:x] += to_base[:x] * speed
    enemy[:y] += to_base[:y] * speed
  end
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(args, enemy) }
end

def enemy_dead?(args, enemy)
  # for now die when enemy touches player area
  enemy.health == 0
end

def handle_enemy_vs_base_collisions(args)
  args.state.enemies.each do |enemy|
    if enemy.intersect_rect? args.state.base
      args.state.base.health -= 5
      enemy.health = 0
    end
  end
end

def update_launcher(args)
  launcher = args.state.launcher
  return unless launcher[:state] == :charging

  # tick up the current charge state
  args.state.maxChargePower ||= 720 - 100
  launcher[:power] += 1
  if launcher[:power] > args.state.maxChargePower
    launcher[:power] = args.state.maxChargePower
  end
end

def update_launched_turrets args
  args.state.launched_turrets.reject!{|lau| lau.pow <=0}

  args.state.launched_turrets.each do |lau|
    lau.x += lau.dx * lau.pow
    lau.y += (lau.dy + Math.sin(args.tick_count)) * lau.pow

    lau.logical_x += lau.dx * lau.pow
    lau.logical_y += lau.dy * lau.pow
    lau.pow -= 1
    if lau.pow <= 0
      lau.pow = 0
      #eh symbols for turrets?
      args.state.stationary_turrets << makeTurret(lau.logical_x, lau.logical_y, lau.cd, lau.type)
    end
  end
end

def stage_bounds(stage)
  { x: -stage[:w] / 2, y: -stage[:h] / 2, w: stage[:w], h: stage[:h] }
end

def game_over?(args)
  Base.dead?(args.state.base) # || winning condition
end

def game_render(args)
  render_base(args)
  render_stage(args)
  render_enemies(args)
  render_turrets(args)
  render_launcher_ui(args) if args.state.launcher[:state] == :charging
  render_game_over(args) if Base.dead?(args.state.base)
  render_debug_info(args) if args.state.show_debug_info
  render_dmg_popups(args)
  render_essence(args)
end

def render_base(args)
  camera = args.state.camera
  base = args.state.base
  args.outputs.primitives << [
    Camera.transform!(camera, Base.sprite(base)),
    Camera.transform!(camera, Base.health_label(base)),
  ]

end

def render_stage(args)
  stage = args.state.stage
  camera = args.state.camera
  args.outputs.primitives << stage[:walls].map { |wall|
    Camera.transform! camera, wall.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }
  render_stage_border(args)
end

def render_stage_border(args)
  stage = args.state.stage
  camera = args.state.camera
  bounds_on_screen = Camera.transform! camera, stage_bounds(stage)
  border_style = { path: :pixel, r: 100, g: 100, b: 100 }
  args.outputs.primitives << [
    { x: 0, y: 0, w: bounds_on_screen.left, h: 720 }.sprite!(border_style),
    { x: bounds_on_screen.left, y: 0, w: 1280, h: bounds_on_screen.bottom }.sprite!(border_style),
    { x: bounds_on_screen.right, y: 0, w: 1280 - bounds_on_screen.right, h: 720 }.sprite!(border_style),
    { x: bounds_on_screen.left, y: bounds_on_screen.top, w: 1280, h: 720 - bounds_on_screen.top }.sprite!(border_style)
  ]
end

def render_enemies(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.enemies.map { |enemy|
    Camera.transform! camera, enemy.to_sprite(
      path: "sprites/#{enemy[:type]}.png"
    )
  }
end

def render_turrets(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.launched_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }

  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 0, b: 200)
  }

  args.outputs.primitives << args.state.projectiles.map { |shot|
    Camera.transform! camera, shot.to_sprite(path: :pixel)
  }
end

def render_launcher_ui(args)
  args.outputs.primitives << {
    x: 1100, y: 50, w: 50, h: args.state.launcher[:power],
    path: :pixel, r: 0, g: 200, b: 0
  }.sprite!

  launcher = args.state.launcher
  if launcher[:direction]
    base_on_screen = Camera.transform args.state.camera, args.state.base
    x = base_on_screen.x
    y = base_on_screen.y
    length = 200
    args.outputs.primitives << {
      x: x, y: y, x2: x + launcher[:direction].x * length, y2: y + launcher[:direction].y * length
    }.line!
  end
end

def render_game_over(args)
  args.outputs.primitives << [
    {
      x: 0, y: 0,
      w: 1280, h: 720,
      r: 255, g: 255, b: 255,
      a: 180 + Math.sin(args.state.tick_count / 100) * 75,
      path: :pixel
    }.to_sprite,
    {
      text: "GAME OVER",
      x: args.grid.w / 2, y: 360,
      size_px: 200,
      alignment_enum: 1,
      vertical_alignment_enum: 1,
      r: 0, g: 0, b: 0
    }.to_label,
    {
      text: "press R to restart",
      x: args.grid.w / 2, y: 250,
      size_px: 50,
      alignment_enum: 1,
      vertical_alignment_enum: 1,
      r: 0, g: 0, b: 0
    }.to_label
  ]
end

def render_debug_info(args)
  args.outputs.primitives << [
    { x: 0, y: 690, w: 200, h: 30, r: 0, g: 0, b: 0, a: 128, path: :pixel }.sprite!,
    { x: 5, y: 715, text: "FPS: #{args.gtk.current_framerate.to_i}", r: 255, g: 255, b: 255 }.label!
  ]
end

def fat_border(rect, line_width:, **values)
  [
    { x: rect.x - line_width, y: rect.y - line_width, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
    { x: rect.x - line_width, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values),
    { x: rect.x - line_width, y: rect.y + rect.h, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
    { x: rect.x + rect.w, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values)
  ]
end

$gtk.reset
