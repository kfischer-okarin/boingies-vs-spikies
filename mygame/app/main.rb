require 'app/camera.rb'
require 'app/camera_movement.rb'
require 'app/stage_editor.rb'

def tick(args)
  setup(args) if args.tick_count.zero?

  case args.state.scene
  when :game
    game_tick(args)
  when :stage_editor
    StageEditor.tick(args)
  end
end

def game_tick(args)
  game_process_inputs(args)
  game_update(args)
  game_render(args)
end

def setup(args)
  args.state.scene = :game
  args.state.stage = load_stage
  args.state.enemies = []
  args.state.camera = Camera.build
  args.state.player_area = { x: 0, y: 0, w: 200, h: 200, anchor_x: 0.5, anchor_y: 0.5 }
  args.state.launcher = { state: :idle, power: 0, direction: nil }
  args.state.launched_turrets = []
end

def load_stage
  $gtk.deserialize_state('stage')
end

def game_process_inputs(args)
  CameraMovement.control_camera(mouse: args.inputs.mouse, camera: args.state.camera)
  control_launcher(args)
  StageEditor.handle_onoff(args)
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
  player_area_on_screen = Camera.transform args.state.camera, args.state.player_area
  direction = Matrix.vec2(
    mouse.x - player_area_on_screen.x,
    mouse.y - player_area_on_screen.y
  )
  Matrix.normalize! direction
  direction
end

def build_turret(args)
  p = args.state.player_area
  launcher = args.state.launcher
  { x: p.x, y: p.y, w: 20, h: 20, dx: launcher[:direction].x, dy: launcher[:direction].y, pow: launcher[:power] / 5, logical_x: p.x, logical_y: p.y }
end

def game_update(args)
  spawn_spikey(args) if args.tick_count.mod_zero? 60
  move_enemies(args)
  handle_dead_enemies(args)
  update_launcher(args)
  update_launched_turrets(args)
end

def spawn_spikey(args)
  direction = %i[top right bottom left].sample
  case direction
  when :top
    x = -1200 + rand(1200)
    y = 1200
  when :right
    x = 1200
    y = -1200 + rand(1200)
  when :bottom
    x = -1200 + rand(1200)
    y = -1200
  when :left
    x = -1200
    y = -1200 + rand(1200)
  end

  args.state.enemies << {
    x: x, y: y, w: 100, h: 100,
    anchor_x: 0.5, anchor_y: 0.5,
    type: :spikey_ball
  }
end

def move_enemies(args)
  player_area = args.state.player_area
  args.state.enemies.each do |enemy|
    to_player_area = Matrix.vec2(
      player_area[:x] - enemy[:x],
      player_area[:y] - enemy[:y]
    )
    Matrix.normalize! to_player_area
    speed = 2
    enemy[:x] += to_player_area[:x] * speed
    enemy[:y] += to_player_area[:y] * speed
  end
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(args, enemy) }
end

def enemy_dead?(args, enemy)
  # for now die when enemy touches player area
  enemy.intersect_rect? args.state.player_area
end

def update_launcher(args)
  launcher = args.state.launcher
  return unless launcher[:state] == :charging

  # tick up the current charge state
  args.state.maxChargePower ||= 720- 100
  launcher[:power] += 1
  if launcher[:power] > args.state.maxChargePower
    launcher[:power] = args.state.maxChargePower
  end
end

def update_launched_turrets args
  args.state.launched_turrets.each do |lau|
    lau.x += (lau.dx) * lau.pow
    lau.y += (lau.dy+Math.sin(args.tick_count)) * lau.pow

    lau.logical_x += lau.dx * lau.pow
    lau.logical_y += lau.dy * lau.pow
    lau.pow -= 1
    if lau.pow <= 0
      lau.pow = 0
    end
  end
end

def game_render(args)
  render_player_area(args)
  render_stage(args)
  render_enemies(args)
  render_turrets(args)
  render_launcher_ui(args) if args.state.launcher[:state] == :charging
end

def render_player_area(args)
  camera = args.state.camera
  args.outputs.primitives << Camera.transform!(
    camera,
    args.state.player_area.to_sprite(path: :pixel, r: 0, g: 200, b: 0)
  )
end

def render_stage(args)
  stage = args.state.stage
  camera = args.state.camera
  args.outputs.primitives << stage[:walls].map { |wall|
    Camera.transform! camera, wall.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }
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
end

def render_launcher_ui(args)
  args.outputs.primitives << {
    x: 1100, y: 50, w: 50, h: args.state.launcher[:power],
    path: :pixel, r: 0, g: 200, b: 0,
  }.sprite!

  launcher = args.state.launcher
  if launcher[:direction]
    player_area_on_screen = Camera.transform args.state.camera, args.state.player_area
    x = player_area_on_screen.x
    y = player_area_on_screen.y
    length = 200
    args.outputs.primitives << {
      x: x, y: y, x2: x + launcher[:direction].x * length, y2: y + launcher[:direction].y * length
    }.line!
  end
end

$gtk.reset
