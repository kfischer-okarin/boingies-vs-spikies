module Camera
  class << self
    def build(values = nil)
      {
        center_x: 0,
        center_y: 0,
        zoom: 1,
        half_w: 640,
        half_h: 360
      }.merge!(values || {})
    end

    def transform!(camera, rect)
      zoom = camera[:zoom]
      camera_bottom_left_x = camera[:center_x] - (camera[:half_w] / zoom)
      camera_bottom_left_y = camera[:center_y] - (camera[:half_h] / zoom)
      rect.merge!(
        x: (rect[:x] - camera_bottom_left_x) * zoom,
        y: (rect[:y] - camera_bottom_left_y) * zoom,
        w: rect[:w] * zoom,
        h: rect[:h] * zoom
      )
    end

    def transform(camera, rect)
      transform!(camera, rect.dup)
    end

    def to_world_coordinates!(camera, position)
      zoom = camera[:zoom]
      camera_bottom_left_x = camera[:center_x] - (camera[:half_w] / zoom)
      camera_bottom_left_y = camera[:center_y] - (camera[:half_h] / zoom)
      position.merge!(
        x: (position[:x] / zoom) + camera_bottom_left_x,
        y: (position[:y] / zoom) + camera_bottom_left_y
      )
    end

    def to_world_coordinates(camera, position)
      to_world_coordinates!(camera, position.dup)
    end
  end
end
