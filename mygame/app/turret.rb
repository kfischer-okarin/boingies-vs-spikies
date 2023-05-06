def makeTurret x,y,cd, type
  range = 500
  speed = 2
  life_time = range/speed
  {
    x:x,
    y:y,
    w:20,
    h:20,
    cd:0,
    maxCd:cd,
    dmg: 10,
    shotSpeed: speed,
    type: type, # yet to be used but will be
    range: range,
    life_time:life_time
  }
end

def tick_turret args
  args.state.stationary_turrets.each do |t|
    t.cd +=1
    if t.cd > t.maxCd
      #do the shoot
      #nah should probably check if something is in range
      args.state.enemies.each do |en|
        in_range = circle_to_point_col t, en
        if in_range
          #now we do the shoot # would make use of turret type somehow
          args.state.projectiles << make_projectile(en, t)
          t.cd = 0
          break;
        end
      end
    end
  end

  #yeah I was being lazy maybe projectiles should have there own update
  args.state.projectiles.reject!{|shot| shot.pen < 0 || shot.life_time < 0}

  args.state.projectiles.each do |shot|
    shot.life_time -=1

    if shot.target != nil && shot.homing == true
      shot.target_x = shot.target.x
      shot.target_y = shot.target.y
    end

    to_target = Matrix.vec2(
      shot[:target_x] - shot[:x],
      shot[:target_y] - shot[:y]
    )
    Matrix.normalize! to_target
    speed = shot.speed
    shot[:x] += to_target[:x] * speed
    shot[:y] += to_target[:y] * speed

    #the intent here is, if its really close to the target xy it'll just stop and clear itself
    #doesn't work in its current state
    if (shot.x - to_target.x).abs < (2*speed) && (shot.y - to_target.y).abs < (2*speed)
      shot.life_time = -1
    end

    args.state.enemies.each do |en|
      if shot.intersect_rect? en
        en.health -= shot.dmg
        args.state.dmg_popups<< make_dmg_popup(shot)

        shot.pen -=1
        shot.r =0
      end
    end
  end
end
#doing center to center for the collision just felt like the best option
def circle_to_point_col cir, pt
  cx = cir.x + (cir.w/2)
  cy = cir.y + (cir.h/2)

  px = pt.x + (pt.w/2)
  py = pt.y + (pt.h/2)

  disx = px - cx
  disy = py - cy

  dis = Math.sqrt( (disx ** 2) + (disy ** 2))

  in_range = dis < cir.range

end

def make_projectile target, turret
  tx = target.x + (target.w/2)
  ty = target.y + (target.h/2)
  {
    x: turret.x,
    y:turret.y,
    w:10,
    h:10,
    speed:turret.shotSpeed,
    #this will change so don't bother refactoring it XD cuz we will have sprites right??
    path: :pixel,
    r: 100,
    b:0,
    g:0,
    target_x: tx,
    target_y: ty,
    dmg: turret.dmg,
    pen:0,
    life_time: turret.life_time,
    target: target,
    homing: true # can be refactored later to be good
  }
end

#going to render these as labels for now but could be work putting them into RT's
#for more interesting visual effects
def make_dmg_popup shot
  dx = (rand(2.0)-1) * (rand(2)+1)
  dy = (rand(1.0)+1 )* (rand(2)+1)
  x = shot.x
  y = shot.y
  txt = shot.dmg
  r = rand(255)
  g = rand(255)
  b = rand(255)

  size_px = 40 + rand(20)
  {
    x:x,
    y:y,
    text:txt,
    dx:dx,
    dy:dy,
    life_time: 200,
    size_px: size_px,
    r:r,
    g:g,
    b:b
  }
end

def update_dmg_popups args
  args.state.dmg_popups.each do |lab|
    lab.x += lab.dx
    lab.y += lab.dy
    lab.life_time -=1
  end

  args.state.dmg_popups.reject!{|lab| lab.life_time<0}
end

def render_dmg_popups args
  camera = args.state.camera
  args.outputs.labels << args.state.dmg_popups.map { |lab| Camera.transform camera, lab.to_label()  }
end
