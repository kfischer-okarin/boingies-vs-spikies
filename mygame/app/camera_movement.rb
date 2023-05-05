module CameraMovement
  class << self
    def control_camera(mouse, camera)
      move_camera_with_mouse(mouse, camera)
      zoom_camera_with_mouse_wheel(mouse, camera)
    end

    private

    def move_camera_with_mouse(mouse, camera)
      return unless mouse.has_focus

      camera_move_area_x = 250
      camera_speed = 20
      if mouse.x <= camera_move_area_x
        camera_move_factor = (camera_move_area_x - mouse.x) / camera_move_area_x
        camera[:center_x] -= (camera_speed * camera_move_factor) / camera.zoom
      elsif mouse.x >= 1280 - camera_move_area_x
        camera_move_factor = ((mouse.x - (1280 - camera_move_area_x))) / camera_move_area_x
        camera[:center_x] += (camera_speed * camera_move_factor) / camera.zoom
      end

      camera_move_area_y = 125
      if mouse.y <= camera_move_area_y
        camera_move_factor = (camera_move_area_y - mouse.y) / camera_move_area_y
        camera[:center_y] -= (camera_speed * camera_move_factor) / camera.zoom
      elsif mouse.y >= 720 - camera_move_area_y
        camera_move_factor = ((mouse.y - (720 - camera_move_area_y))) / camera_move_area_y
        camera[:center_y] += (camera_speed * camera_move_factor) / camera.zoom
      end
    end

    def zoom_camera_with_mouse_wheel(mouse, camera)
      return unless mouse.wheel

      camera[:zoom] += mouse.wheel.y * 0.1 * camera[:zoom]
      camera[:zoom] = camera[:zoom].clamp(0.25, 4)
    end
  end
end
