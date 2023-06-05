module Waves
  class << self
    def build_state(stage)
      waves_state = {
        phase: nil,
        wave_index: -1,
        waves: stage[:waves],
        timer: 0,
      }
      prepare_next_wave(waves_state)
      waves_state
    end

    def tick(args, waves_state)
      send("tick_#{waves_state[:phase]}", args, waves_state)
    end

    def prepare_next_wave(waves_state)
      waves_state[:wave_index] += 1
      waves_state[:phase] = :between_waves
      waves_state[:timer] = 5.seconds
    end

    def no_more_enemies_in_this_wave?(waves_state)
      waves_state[:queued_enemies].empty?
    end

    def in_wave?(waves_state)
      waves_state[:phase] == :in_wave
    end

    def last_wave?(waves_state)
      waves_state[:wave_index] % waves_state[:waves].length == 0
    end

    private

    def tick_between_waves(args, waves_state)
      waves_state[:timer] -= 1
      start_wave(waves_state) if waves_state[:timer] <= 0
    end

    def tick_in_wave(args, waves_state)
      return if no_more_enemies_in_this_wave?(waves_state)

      if spawn_next_enemy?(waves_state)
        next_enemy_type = waves_state[:queued_enemies].pop
        Enemies.spawn(args, next_enemy_type)
        reset_spawn_timer(waves_state)
      else
        waves_state[:spawn_timer] -= 1
      end
    end

    def start_wave(waves_state)
      current_wave = waves_state[:waves][waves_state[:wave_index]%waves_state[:waves].length]

      waves_state[:queued_enemies] = []
      extraEnemies = $args.state.enemy_scaling.floor()
      puts extraEnemies
      current_wave[:enemies].each do |enemy, number|
        waves_state[:queued_enemies] += [enemy] * (number + extraEnemies)
      end
      waves_state[:queued_enemies].shuffle!

      waves_state[:phase] = :in_wave
      waves_state[:spawn_interval] = current_wave[:spawn_interval]

      reset_spawn_timer(waves_state)
    end

    def spawn_next_enemy?(waves_state)
      waves_state[:spawn_timer] <= 0
    end

    def reset_spawn_timer(waves_state)
      waves_state[:spawn_timer] = waves_state[:spawn_interval]
    end
  end
end
