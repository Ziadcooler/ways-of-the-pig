local Player = {}
Player.__index = Player

function Player.new(world, joystick, x, y, color)
    local self = setmetatable({}, Player)
    self.joystick = joystick
    self.speed = 300
    self.jumpForce = -2000
    self.onGround = false
    self.color = color

    -- Create collider
    local w, h = 50, 70
    self.collider = world:newRectangleCollider(x, y, w, h)
    self.collider:setFixedRotation(true)
    self.collider:setRestitution(0.4)
    self.collider:setFriction(0.9)
    self.collider:setLinearDamping(1)

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
            col:applyLinearImpulse(0, self.jumpForce)
        end
    end
end

function Player:isGrounded()
    local col = self.collider
    local contacts = col:getContacts()
    for _, contact in ipairs(contacts) do
        if contact:isTouching() then
            local nx, ny = contact:getNormal()
            if ny < 0 then return true end
        end
    end
    return false 
end 

function Player:draw()
    love.graphics.setColor(self.color)
    local col = self.collider
    local w, h = 50, 70
    local x, y = col:getPosition()
    love.graphics.rectangle("fill", x - 25, y- 25, w, h)
end 

return Player