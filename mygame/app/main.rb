require 'app/camera.rb'

def tick(args)
  setup(args) if args.tick_count.zero?

  process_inputs(args)
  update(args)
  render(args)
end

def setup(args)
  stage_boundaries = [
    { x: -10, y: -10, w: 1300, h: 10 },
    { x: -10, y: 720, w: 1300, h: 10 },
    { x: -10, y: -10, w: 10, h: 740 },
    { x: 1280, y: -10, w: 10, h: 740 },
  ]
  args.state.walls = stage_boundaries + [
    { x: 400, y: 100, w: 40, h: 520 },
    { x: 600, y: 0, w: 40, h: 400 },
    { x: 600, y: 570, w: 40, h: 150 },
    { x: 800, y: 220, w: 40, h: 500 },
    { x: 1000, y: 0, w: 40, h: 500 }
  ]
  args.state.enemies = []
  args.state.camera = Camera.build center_x: 640, center_y: 360
end

def process_inputs(args)
  mouse = args.inputs.mouse
  camera = args.state.camera
  mouse_camera_movement(mouse, camera)
  mouse_camera_zoom(mouse, camera)
end

def mouse_camera_movement(mouse, camera)
  return unless mouse.has_focus

  camera_move_area = 50
  camera_move_speed = 10 / camera[:zoom]
  if mouse.x <= camera_move_area
    camera[:center_x] -= camera_move_speed
  elsif mouse.x >= 1280 - camera_move_area
    camera[:center_x] += camera_move_speed
  end

  if mouse.y <= camera_move_area
    camera[:center_y] -= camera_move_speed
  elsif mouse.y >= 720 - camera_move_area
    camera[:center_y] += camera_move_speed
  end
end

def mouse_camera_zoom(mouse, camera)
  return unless mouse.wheel

  camera[:zoom] += mouse.wheel.y * 0.1 * camera[:zoom]
  camera[:zoom] = camera[:zoom].clamp(0.25, 4)
end

def update(args)
  spawn_spikey(args) if args.tick_count.mod_zero? 60
  move_enemies(args)
  handle_dead_enemies(args)
end

def spawn_spikey(args)
  args.state.enemies << {
    x: 1200,
    y: 10 + rand(600),
    type: :spikey_ball
  }
end

def move_enemies(args)
  args.state.enemies.each do |enemy|
    enemy[:x] -= 2
  end
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(enemy) }
end

def enemy_dead?(enemy)
  # for now die when you reach the left side of the screen
  enemy[:x] < 100
end

def render(args)
  render_walls(args)
  render_enemies(args)
end

def render_walls(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.walls.map { |wall|
    Camera.transform! camera, wall.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }
end

def render_enemies(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.enemies.map { |enemy|
    Camera.transform! camera, enemy.to_sprite(
      path: "sprites/#{enemy[:type]}.png", w: 100, h: 100,
      anchor_x: 0.5, anchor_y: 0.5
    )
  }
end

$gtk.reset
