module Collisions
  class << self
    def line_intersect_rect?(line, rect)
      rect_to_lines(rect).detect do |rect_line|
        line_intersect_line?(line, rect_line)
      end
    end

    def rect_to_lines(rect)
      x = rect[:x]
      y = rect[:y]
      x2 = rect[:x] + rect[:w]
      y2 = rect[:y] + rect[:h]
      [
        {x: x, y: y, x2: x2, y2: y},
        {x: x, y: y, x2: x, y2: y2},
        {x: x2, y: y, x2: x2, y2: y2},
        {x: x, y: y2, x2: x2, y2: y2}
      ]
    end

    def line_intersect_line?(line_one, line_two)
      x1 = line_one[:x]
      y1 = line_one[:y]
      x2 = line_one[:x2]
      y2 = line_one[:y2]

      x3 = line_two[:x]
      y3 = line_two[:y]
      x4 = line_two[:x2]
      y4 = line_two[:y2]

      uA = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / ((y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1))
      uB = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / ((y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1))

      uA >= 0 && uA <= 1 && uB >= 0 && uB <= 1
    end
  end
end
