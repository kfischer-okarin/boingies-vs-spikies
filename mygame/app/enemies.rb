module Enemies
  TYPES = {
    spikey_ball: {
      speed: 2,
      health: 150,
      damage: 30,
      w: 100,
      h: 100,
      path: "sprites/spikey_ball.png",
    },
    spikey_cube: {
      speed: 1,
      health: 200,
      damage: 50,
      path: "sprites/spikey_cube.png",
      w: 180,
      h: 180
    },
    spikey: {
      speed: 3,
      health: 100,
      damage: 10,
      path: "sprites/spikey.png",
      w: 60,
      h: 120
    }
  }

  class << self
    def spawn_spikey(args)
      spawn_zone = args.state.stage.spawn_zones.sample
      enemy = TYPES.values.sample.merge(
        x: spawn_zone.x + rand(spawn_zone.w).to_i,
        y: spawn_zone.y + rand(spawn_zone.h).to_i,
        anchor_x: 0.5, anchor_y: 0.5,
        essence_amount: 10,
        unique_id: args.state.enemy_unique_id
      )

      args.state.enemies << enemy

      args.state.enemy_unique_id += 1
    end

    def update(args)
      args.state.enemies.each do |enemy|
        move(args, enemy)
      end
    end

    def move(args, enemy)
      to_base = Pathfinding.direction_to_base(args.state.navigation_grid, enemy)
      enemy.x += to_base.x * enemy.speed
      enemy.y += to_base.y * enemy.speed
    end

    def handle_enemy_vs_base_collisions(args)
      args.state.enemies.each do |enemy|
        if enemy.intersect_rect? args.state.base
          args.state.base.health -= 5
          enemy.health = 0
        end
      end
    end

    def handle_dead_ones(args)
      args.state.enemies.reject! { |enemy| dead?(args, enemy) }
    end

    def dead?(args, enemy)
      enemy.health <= 0
    end
  end
end
