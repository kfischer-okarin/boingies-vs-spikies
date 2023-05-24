module Turret
  TYPES = [
    {
      name: :big_roller,
      cost: 100
    },
    {
      name: :pdc,
      cost: 50
    },
    {
      name: :stickers,
      cost: 75
    }
  ]

  class << self
    def enemies_in_range(turret, enemies)
      enemies.select do |enemy|
        circle_to_point_colision turret, enemy
      end
    end

    def line_of_sight(turret, enemy)
      {
        x: enemy.x,
        y: enemy.y,
        x2: turret.x + turret.w / 2,
        y2: turret.y + turret.h / 2
      }
    end

    def walls_in_range(turret, walls)
      range = turret.range
      turret_range_rect = { x: turret.x - range, y: turret.y - range, h: 2 * range, w: 2 * range }

      GTK::Geometry.find_all_intersect_rect turret_range_rect, walls
    end

    def can_see_enemy?(turret, enemy, stage)
      # draw a line between turret and enemy
      line = line_of_sight(turret, enemy)
      # check if it collides with any of the walls
      obstructing_wall = walls_in_range(turret, stage.walls).detect do |wall|
        Collisions.line_intersect_rect? line, wall
      end

      !obstructing_wall
    end
  end
end

def makeTurret x, y, cd, type
  range = 500
  speed = 2
  life_time = range / speed
  {
    x: x,
    y: y,
    w: 100,
    h: 100,
    cd: 0,
    maxCd: cd,
    dmg: 10,
    shotSpeed: speed,
    type: type, # yet to be used but will be
    range: range,
    life_time: life_time,
    fusion_range: 40
  }.merge!( send("turret_stats_#{type}"))
end

def turret_stats_big_roller
  {
    dmg: 10,
    shotSpeed: 1,
    range: 300,
    maxCd: 300,
    life_time: 600
  }
end

def turret_stats_pdc
  {
    dmg: 2,
    shotSpeed: 20,
    range: 500,
    maxCd: 8,
    life_time: 20
  }
end





def tick_turret args
  args.state.stationary_turrets.each do |turret|
    turret.cd += 1
    if turret.cd > turret.maxCd
      enemies_in_range = Turret.enemies_in_range(turret, args.state.enemies)
      enemies_in_range.each do |enemy|
        if Turret.can_see_enemy?(turret, enemy, args.state.stage)
          args.state.projectiles << send("make_#{turret.type}_projectile", enemy, turret  )
          turret.cd = 0
          break
        end
      end
    end
  end

  #yeah I was being lazy maybe projectiles should have there own update
  args.state.projectiles.reject! { |shot| shot.pen < 0 || shot.life_time < 0 }

  args.state.projectiles.each do |shot|
    shot.life_time -= 1

    if shot.target != nil && shot.homing == true
      shot.target_position = { x: shot.target.x, y: shot.target.y }
    end

    to_target = direction_between(shot, shot.target_position)
    speed = shot.speed
    shot[:x] += to_target[:x] * speed
    shot[:y] += to_target[:y] * speed

    #the intent here is, if its really close to the target xy it'll just stop and clear itself
    #doesn't work in its current state # STILL DOESN@T WORK :( SADNESS

    if distance_between(shot, to_target) < (2*speed)
      shot.life_time = -1
    end

    args.state.enemies.each do |en|
      if shot.intersect_rect? en
        unless shot.enemies_hit.include? en.unique_id
          en.health -= shot.dmg
          args.state.dmg_popups << DamageNumbers.build_damage_number(
            x: (en.x + shot.x) / 2,
            y: ((en.y + shot.y) / 2) + 50,
            amount: shot.dmg
          )

          shot.pen -= 1
          shot.r = 0

          if en.health <= 0
            args.state.essence_drops << make_essence(en)
          else
            shot.enemies_hit << en.unique_id.dup
            shot.homing = false
          end
        end
      end
    end
  end
end

#doing center to center for the collision just felt like the best option
def circle_to_point_colision turret, enemy
  cx = turret.x + (turret.w / 2)
  cy = turret.y + (turret.h / 2)

  px = enemy.x + (enemy.w / 2)
  py = enemy.y + (enemy.h / 2)

  disx = px - cx
  disy = py - cy

  dis = Math.sqrt((disx**2) + (disy**2))

  dis < turret.range
end

def make_big_roller_projectile target, turret
  tx = target.x + (target.w/2)
  ty = target.y + (target.h/2)
  enemies_hit = []
  speed = turret.shotSpeed/2
  {
    x: turret.x,
    y: turret.y,
    w: 50,
    h: 50,
    speed: speed,
    #this will change so don't bother refactoring it XD cuz we will have sprites right??
    path: :pixel,
    r: 100,
    b: 0,
    g: 0,
    target_position: { x: tx, y: ty },
    dmg: turret.dmg,
    pen: 5,
    life_time: turret.life_time,
    target: target,
    homing: true, # can be refactored later to be good
    enemies_hit: enemies_hit
  }
end

def make_pdc_projectile target, turret
  tx = target.x + (target.w/2)
  ty = target.y + (target.h/2)
  enemies_hit = []
  {
    x: turret.x,
    y: turret.y,
    w: 10,
    h: 10,
    speed: turret.shotSpeed,
    #this will change so don't bother refactoring it XD cuz we will have sprites right??
    path: :pixel,
    r: 100,
    b: 0,
    g: 0,
    target_position: { x: tx, y: ty },
    dmg: turret.dmg,
    pen: 5,
    life_time: turret.life_time,
    target: target,
    homing: true, # can be refactored later to be good
    enemies_hit: enemies_hit
  }
end

def setup_circle object, radius
  obj_center_x = object.x + (object.w/2)
  obj_center_y = object.y + (object.h/2)

  x = obj_center_x - radius
  y = obj_center_y - radius
  r2 = radius * 2
  {x: x, y: y, h: r2, w: r2, path:"sprites/circle_transparent.png", r: 0, g: 200, b: 0, a: 128, primitive_marker: :sprite,
     centre:{x: obj_center_x, y: obj_center_y, radius:radius}}
end


def circle_col obj1, obj2
  distance = Math.sqrt( ((obj1.x - obj2.x)**2) + ((obj1.y - obj2.y)**2) )
  return distance < (obj1.fusion_range + obj2.fusion_range)
end

def fuse_turret existing_turret, fusing_from
  existing_turret.dmg += (fusing_from.dmg * 0.2)
  existing_turret.range *= 1.05
  existing_turret.shotSpeed *= 1.1
  existing_turret.maxCd *= 0.95
  existing_turret.life_time = existing_turret.range / existing_turret.shotSpeed
end
