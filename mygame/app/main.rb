require 'app/camera.rb'
require 'app/stage.rb'

def tick(args)
  setup(args) if args.tick_count.zero?

  process_inputs(args)
  update(args)
  render(args)
end

def setup(args)
  args.state.walls = stage_walls
  args.state.enemies = []
  args.state.camera = Camera.build
  args.state.player_area = { x: -100, y: -100, w: 200, h: 200 }

  args.state.launchedTurrets = []
end

def process_inputs(args)
  mouse = args.inputs.mouse
  camera = args.state.camera
  mouse_camera_movement(mouse, camera)
  mouse_camera_zoom(mouse, camera)
  control_launcher(args)
end

# Q: should move this to mouse_camera methods to camera module?
def mouse_camera_movement(mouse, camera)
  return unless mouse.has_focus

  camera_move_area_x = 250
  camera_speed = 20
  if mouse.x <= camera_move_area_x
    camera_move_factor = (camera_move_area_x - mouse.x) / camera_move_area_x
    camera[:center_x] -= (camera_speed * camera_move_factor) / camera.zoom
  elsif mouse.x >= 1280 - camera_move_area_x
    camera_move_factor = ((mouse.x - (1280 - camera_move_area_x))) / camera_move_area_x
    camera[:center_x] += (camera_speed * camera_move_factor) / camera.zoom
  end

  camera_move_area_y = 125
  if mouse.y <= camera_move_area_y
    camera_move_factor = (camera_move_area_y - mouse.y) / camera_move_area_y
    camera[:center_y] -= (camera_speed * camera_move_factor) / camera.zoom
  elsif mouse.y >= 720 - camera_move_area_y
    camera_move_factor = ((mouse.y - (720 - camera_move_area_y))) / camera_move_area_y
    camera[:center_y] += (camera_speed * camera_move_factor) / camera.zoom
  end
end

def mouse_camera_zoom(mouse, camera)
  return unless mouse.wheel

  camera[:zoom] += mouse.wheel.y * 0.1 * camera[:zoom]
  camera[:zoom] = camera[:zoom].clamp(0.25, 4)
end

# cursed magi code is go
def control_launcher args
  m = args.inputs.mouse

  args.state.charging ||=false
  if m.click
    if args.state.charging == false
      args.state.charging = true
      args.state.chargePower = 0
    else
      args.state.charging = false
      # do a launch  take mouse pos then normalise to x y between -1 & 1
      args.state.launchedTurrets << makeTurret(args, m.x, m.y)
      args.state.chargePower = 0
    end
  end

  if args.state.charging == true
    # tick up the current charge state
    args.state.maxChargePower ||= 720- 100
    args.state.chargePower += 1
    if args.state.chargePower > args.state.maxChargePower
      args.state.chargePower = args.state.maxChargePower
    end
  end
end

def update(args)
  spawn_spikey(args) if args.tick_count.mod_zero? 60
  move_enemies(args)
  handle_dead_enemies(args)

  tickLaunched(args)
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
  args.state.enemies.each do |enemy|
    distance_to_center = Math.sqrt(enemy[:x]**2 + enemy[:y]**2)
    speed = 2
    enemy[:x] += -(enemy[:x] / distance_to_center) * speed
    enemy[:y] += -(enemy[:y] / distance_to_center) * speed
  end
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(args, enemy) }
end

def enemy_dead?(args, enemy)
  # for now die when enemy touches player area
  enemy.intersect_rect? args.state.player_area
end

def render(args)
  render_player_area(args)
  render_walls(args)
  render_enemies(args)
  renderLaunched(args)
  chargeBar args
end

def render_player_area(args)
  camera = args.state.camera
  args.outputs.primitives << Camera.transform!(
    camera,
    args.state.player_area.to_sprite(path: :pixel, r: 0, g: 200, b: 0)
  )
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
      path: "sprites/#{enemy[:type]}.png"
    )
  }
end

def renderLaunched(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.launchedTurrets.map { |lau|
    Camera.transform! camera, lau.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }
end

def tickLaunched args
  args.state.launchedTurrets.each_with_index do |lau, i|
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

def makeTurret(args, x, y)
  p = args.state.player_area
  camera = args.state.camera
  # yeah this just wasn't working??? the idea was the I would calc a direction based on mouse pos vs player area, then normalise
  # between -1 and 1 so it could be multiplied for the appropriate speed but math no work
  #dx = normalise0to1( x - p.x,0,2)-1
  #dy = normalise0to1( y - p.y,0,2)-1
  dx = 1
  dy = 1
  {x: p.x, y: p.y, w:20, h:20, path: :pixel, r:200, dx: dx, dy:dy , pow: args.state.chargePower/5, logical_x: p.x, logical_y: p.y}
end

def normalise0to1 val, min,max
	x = (val - min) / (max - min)
	puts "result #{x} input val #{val}, min #{min}, max #{max}"

	return x
end


def chargeBar args
  args.state.chargyBary ||= {x:1100, y: 50, w:50, h:0, g:200, path: :pixel}

  args.state.chargyBary.h = args.state.chargePower

#I do not understand why this is pink but oh well XD
  args.outputs.primitives << args.state.chargyBary.to_sprite
end

$gtk.reset
