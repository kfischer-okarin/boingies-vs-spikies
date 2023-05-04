def stage_walls
  [
    { x: 400, y: 100, w: 40, h: 520 },
    { x: 600, y: 0, w: 40, h: 400 },
    { x: 600, y: 570, w: 40, h: 150 },
    { x: 800, y: 220, w: 40, h: 500 },
    { x: 1000, y: 0, w: 40, h: 500 }
  ]
end

# Life update the stage walls without resetting the game
$state.walls = stage_walls if $state.walls
