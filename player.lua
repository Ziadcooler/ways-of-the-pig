local Player = {}
Player.__index = Player

function Player.new(world, joystick, x, y, color)
    local self = setmetatable({}, Player)
    self.joystick = joystick
    self.speed = 300
    self.jumpForce = -400
    self.onGround = false
    self.color = color

    -- Create collider
    w, h = 50, 70
    self.collider = world:newRectangleCollider(x, y, w, h)
    self.collider:setFixedRotation(true)
    self.collider:setRestitution(0.4)
    self.collider:setFriction(0.9)
    self.collider:setLinearDamping(1)
    self.collider:setCollisionClass("Player")

    return self
end

function Player:update(dt)
    local col = self.collider

    -- Horizontal movement
    if self.joystick then
        local moveX = self.joystick:getAxis(1)
        local vx, vy = col:getLinearVelocity()
        col:setLinearVelocity(moveX * self.speed, vy)

        -- Jumping
        if self.joystick:isGamepadDown("a") and self:isGrounded() then
            col:setLinearVelocity(0, self.jumpForce)
            if sounds and sounds.jump then
                sounds.jump:play()
            end
        end
    end
end

function Player:isGrounded()
    local x, y = self.collider:getPosition()
    local vx, vy = self.collider:getLinearVelocity()

    -- small ground check box under the player
    local groundCheckHeight = 5
    local colliders = world:queryRectangleArea(
        x - w/2 + 1,
        y + h/2,
        w - 2,
        groundCheckHeight,
        { "Platform", "Player" } -- include other players too
    )

    for _, col in ipairs(colliders) do
        if col ~= self.collider then
            -- only count as grounded if falling or standing still
            if vy >= -10 then
                return true
            end
        end
    end

    return false
end



function Player:draw()
    love.graphics.setColor(self.color)
    local col = self.collider
    local x, y = col:getPosition()
    love.graphics.rectangle("fill", x - 25, y - 35, w, h)
end 

return Player