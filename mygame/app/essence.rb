def make_essence enemy
  speed = 2
  life_time = 200
  x = enemy.x
  y = enemy.y
  ess = enemy.essence_amount
  {
    x: x,
    y: y,
    w: 20,
    h: 20,
    amount: ess,
    speed: speed,
    life_time: life_time,
    max_life_time: life_time,
    angle: 45
  }
end

def render_essence args
  camera = args.state.camera
  args.outputs.primitives << args.state.escessence_drops.map { |ess|
    Camera.transform! camera, ess.to_sprite(path: :pixel, r: 100, g: 100, b: 200)
  }

  args.outputs.labels << {x:20, y:20, text: "Essence: #{args.state.essence_held}"}
end

def update_essence args
  base = args.state.base
  mouse = mouse_in_world(args)

  args.state.escessence_drops.reject!{|ess| ess.life_time <= 0}

  args.state.escessence_drops.each do |ess|
    ess.life_time -= 1

    if ess.life_time < (ess.max_life_time / 2)
      to_base = direction_between(ess, base)
      speed = ess.speed
      ess[:x] += to_base[:x] * speed
      ess[:y] += to_base[:y] * speed
    end

    if ess.intersect_rect? base
      args.state.essence_held += ess.amount
      ess.amout = 0
      ess.life_time = 0
    end

    if ess.intersect_rect? mouse
      args.state.essence_held += ess.amount
      ess.amout = 0
      ess.life_time = 0
    end
  end
end
