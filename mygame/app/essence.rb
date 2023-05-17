def make_essence enemy
  speed = 5
  acceleration = 1
  life_time = 400
  x = enemy.x
  y = enemy.y
  amount = enemy.essence_amount
  {
    x: x,
    y: y,
    w: 20,
    h: 20,
    amount: amount,
    speed: speed,
    acceleration: acceleration,
    life_time: life_time,
    max_life_time: life_time,
    angle: 45
  }
end

def render_essence args
  camera = args.state.camera
  args.outputs.primitives << args.state.essence_drops.map { |ess|
    Camera.transform! camera, ess.to_sprite(path: :pixel, r: 100, g: 100, b: 200)
  }

  args.outputs.labels << {x:20, y:20, text: "Essence: #{args.state.essence_held}"}
end

def update_essence args
  base = args.state.base
  mouse = mouse_in_world(args)

  args.state.essence_drops.reject!{|essence| essence.life_time <= 0}

  args.state.essence_drops.each do |essence|
    essence.life_time -= 1

    if essence.life_time < 350
      direction = direction_between(essence, mouse)
      distance = distance_between(essence, mouse)
      essence.acceleration += 1 / distance if distance > 1
      essence.speed = (essence.speed + essence.acceleration).clamp(0, 20)
      essence[:x] += direction[:x] * essence.speed
      essence[:y] += direction[:y] * essence.speed
    end

    if essence.intersect_rect? base
      args.state.essence_held += essence.amount
      essence.amout = 0
      essence.life_time = 0
    end

    if essence.intersect_rect? mouse.merge(w: 20, h: 20)
      args.state.essence_held += essence.amount
      essence.amout = 0
      essence.life_time = 0
    end
  end
end
