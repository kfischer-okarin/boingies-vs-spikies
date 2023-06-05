module Turret
  TYPES = {
    pdc: {
      cost: 50,
      dmg: 5,
      shotSpeed: 20,
      range: 500,
      maxCd: 8,
      life_time: 20
    },
    big_roller: {
      cost: 100,
      dmg: 30,
      shotSpeed: 1.2,
      range: 300,
      maxCd: 300,
      life_time: 600
    }
  }

  class << self
    def enemies_in_range(turret, enemies, &block)
      enemies.each do |enemy|
        yield enemy if circle_to_point_colision(turret, enemy)
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

    def available_turret_types(args)
      Turret::TYPES.keys
    end

    def definition(type)
      Turret::TYPES[type]
    end

    def build(type, x:, y:)
      definition(type).to_sprite(
        x: x,
        y: y,
        w: 100,
        h: 100,
        cd: 0,
        type: type, # yet to be used but will be
        fusion_range: 40,
        path: "sprites/turret_#{type}.png"
      )
    end
  end
end

def tick_turret args
  args.state.stationary_turrets.each do |turret|
    turret.cd += 1
    if turret.cd > turret.maxCd
      Turret.enemies_in_range(turret, args.state.enemies) do |enemy|
        if Turret.can_see_enemy?(turret, enemy, args.state.stage)
          args.state.projectiles << send("make_#{turret.type}_projectile", enemy, turret  )
          turret.cd = 0
          break
        end
      end
    end
  end

  #handle_dead_projectiles
  #yeah I was being lazy maybe projectiles should have there own update
  args.state.projectiles.reject! { |shot| shot.pen < 0 || shot.life_time < 0 }

  #update_projectiles
  args.state.projectiles.each do |shot|
    shot.life_time -= 1

    if shot.target != nil && shot.homing == true
      shot.target_position = { x: shot.target.x, y: shot.target.y }
    end

    to_target = direction_between(shot, shot.target_position)
    speed = shot.speed
    shot[:x] += to_target[:x] * speed
    shot[:y] += to_target[:y] * speed

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
    path: "sprites/bigshot.png",
    r: 255,
    b: 255,
    g: 255,
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
    w: 25,
    h: 25,
    speed: turret.shotSpeed,
    #this will change so don't bother refactoring it XD cuz we will have sprites right??
    path: "sprites/bigshotsmall.png",
    r: 255,
    b: 255,
    g: 255,
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

$gtk.reset_sprites
