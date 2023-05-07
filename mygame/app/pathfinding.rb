module Pathfinding
  class << self
    def build_navigation_grid(stage, spacing: 50, grid_type: RectGrid)
      grid = grid_type.build(stage_bounds(stage), spacing: spacing)

      wall_points = {}
      unwalkable_distance = 25
      stage[:walls].each do |wall|
        unwalkable_area = {
          x: wall[:x] - unwalkable_distance,
          y: wall[:y] - unwalkable_distance,
          w: wall[:w] + (unwalkable_distance * 2),
          h: wall[:h] + (unwalkable_distance * 2)
        }
        grid_type.grid_points_in_rect(grid, unwalkable_area).each do |wall_point|
          wall_points[wall_point] = true
        end
      end

      costs = {}

      # Basic cost
      start = grid_type.grid_point(grid, stage[:base_position])
      frontier = [start]
      came_from = {}
      cost_so_far = {}

      came_from[start] = nil
      cost_so_far[start] = 0

      while frontier.any?
        current = frontier.shift
        grid_type.neighbors(grid, current).each do |neighbor|
          new_cost = cost_so_far[current] + 10
          next if wall_points[neighbor] || (cost_so_far[neighbor] && new_cost >= cost_so_far[neighbor])

          cost_so_far[neighbor] = new_cost
          frontier << neighbor
          came_from[neighbor] = current
        end
      end

      costs.merge! cost_so_far

      # Wall closeness cost
      frontier = wall_points.keys
      came_from = {}
      cost_so_far = {}

      frontier.each do |wall_point|
        cost_so_far[wall_point] = 3
        came_from[wall_point] = nil
      end

      while frontier.any?
        current = frontier.shift
        grid_type.neighbors(grid, current).each do |neighbor|
          new_cost = cost_so_far[current] - 1
          next if (cost_so_far[neighbor] && new_cost <= cost_so_far[neighbor]) || new_cost <= 0

          cost_so_far[neighbor] = new_cost
          frontier << neighbor
          came_from[neighbor] = current
        end
      end

      cost_so_far.each do |point, cost|
        next if wall_points[point]

        costs[point] += cost
      end

      {
        base_position: stage[:base_position],
        grid: grid,
        cost_so_far: costs,
        type: grid_type
      }
    end

    def direction_to_base(navigation_grid, position)
      grid_type = navigation_grid[:type]
      grid_point = grid_type.grid_point(navigation_grid[:grid], position)
      min_cost_neighbor = grid_type.neighbors(navigation_grid[:grid], grid_point).min_by { |neighbor|
        navigation_grid[:cost_so_far][neighbor] || 100_000_000
      }

      next_point_in_world = grid_type.world_coordinates(navigation_grid[:grid], min_cost_neighbor)

      to_base = Matrix.vec2(
        next_point_in_world[:x] - position[:x],
        next_point_in_world[:y] - position[:y]
      )
      Matrix.normalize! to_base
      to_base
    end
  end

  module RectGrid
    NEIGHBOR_OFFSETS = [
      { x:  0, y:  1 },
      { x:  1, y:  1 },
      { x:  1, y:  0 },
      { x:  1, y: -1 },
      { x:  0, y: -1 },
      { x: -1, y: -1 },
      { x: -1, y:  0 },
      { x: -1, y:  1 }
    ]

    class << self
      def build(bounds, spacing: 50)
        {
          bounds: bounds,
          spacing: spacing
        }
      end

      def neighbors(grid, point)
        result = []
        NEIGHBOR_OFFSETS.each do |offset|
          neighbor = { x: point[:x] + offset[:x], y: point[:y] + offset[:y] }
          neighbor_in_world = world_coordinates(grid, neighbor)
          next unless neighbor_in_world.inside_rect? grid[:bounds]

          result << neighbor
        end
        result
      end

      def world_coordinates(grid, grid_point)
        {
          x: grid_point[:x] * grid[:spacing],
          y: grid_point[:y] * grid[:spacing],
          # So it can work with intersect_rect?
          w: 0,
          h: 0
        }
      end

      def grid_point(grid, world_coordinates)
        {
          x: (world_coordinates[:x] / grid[:spacing]).round,
          y: (world_coordinates[:y] / grid[:spacing]).round
        }
      end

      def grid_points_in_rect(grid, rect)
        result = []
        bottom_left = grid_point(grid, x: rect.left, y: rect.bottom)
        top_right = grid_point(grid, x: rect.right, y: rect.top)
        (bottom_left[:x]..top_right[:x]).each do |x|
          (bottom_left[:y]..top_right[:y]).each do |y|
            result << { x: x, y: y }
          end
        end
        result
      end
    end
  end

  module HexGrid
    # This module uses axial coordinates as described here:
    # https://www.redblobgames.com/grids/hexagons/#coordinates-axial
    NEIGHBOR_OFFSETS = [
      { q:  1, r:  0 },
      { q:  1, r: -1 },
      { q:  0, r: -1 },
      { q: -1, r:  0 },
      { q: -1, r:  1 },
      { q:  0, r:  1 }
    ]

    SQRT_3 = Math.sqrt(3)

    class << self
      def build(bounds, spacing: 50)
        {
          bounds: bounds,
          spacing: spacing
        }
      end

      def neighbors(grid, point)
        result = []
        NEIGHBOR_OFFSETS.each do |offset|
          neighbor = { q: point[:q] + offset[:q], r: point[:r] + offset[:r] }
          neighbor_in_world = world_coordinates(grid, neighbor)
          next unless neighbor_in_world.inside_rect? grid[:bounds]

          result << neighbor
        end
        result
      end

      def world_coordinates(grid, grid_point)
        {
          x: grid[:spacing] * (3 / 2) * grid_point[:q],
          y: grid[:spacing] * SQRT_3 * (grid_point[:r] + grid_point[:q] / 2),
          # So it can work with intersect_rect?
          w: 0,
          h: 0
        }
      end

      def grid_point(grid, world_coordinates)
        q = ((2 / 3) * world_coordinates[:x]) / grid[:spacing]
        r = ((-(1 / 3) * world_coordinates[:x]) + ((SQRT_3 / 3) * world_coordinates[:y])) / grid[:spacing]
        s = 0 - q - r

        rounded_q = q.round
        rounded_r = r.round
        rounded_s = s.round

        q_diff = (rounded_q - q).abs
        r_diff = (rounded_r - r).abs
        s_diff = (rounded_s - s).abs

        if q_diff > r_diff && q_diff > s_diff
          rounded_q = 0 - rounded_r - rounded_s
        elsif r_diff > s_diff
          rounded_r = 0 - rounded_q - rounded_s
        else
          rounded_s = 0 - rounded_q - rounded_r
        end

        {
          q: rounded_q,
          r: rounded_r
        }
      end

      def grid_points_in_rect(grid, rect)
        result = []
        # lock position to the grid to not miss any points because of rounding errors
        bottom = world_coordinates(grid, grid_point(grid, { x: rect.left, y: rect.bottom }))
        top = world_coordinates(grid, grid_point(grid, { x: rect.left, y: rect.top }))
        while bottom.x <= rect.right
          bottom_grid_point = grid_point(grid, bottom)
          top_grid_point = grid_point(grid, top)
          q = bottom_grid_point[:q]
          (bottom_grid_point[:r]..top_grid_point[:r]).each do |r|
            result << { q: q, r: r }
          end
          bottom.x += grid[:spacing] * (3 / 2)
          top.x = bottom.x
        end
        result
      end
    end
  end
end
