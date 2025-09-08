-- inputBar.lua
local utf8 = require("utf8")
local InputBar = {}
InputBar.__index = InputBar

function InputBar.new(x, y, w, h)
    local self = setmetatable({}, InputBar)
    self.x, self.y = x, y
    self.w, self.h = w, h
    self.text = ""
    self.active = true
    self.font = love.graphics.newFont(24)

    -- cursor blink state
    self.cursorTimer = 0
    self.cursorVisible = true
    self.cursorBlinkRate = 0.5 -- seconds

    return self
end

function InputBar:update(dt)
    if self.active then
        self.cursorTimer = self.cursorTimer + dt
        if self.cursorTimer >= self.cursorBlinkRate then
            self.cursorTimer = 0
            self.cursorVisible = not self.cursorVisible
        end
    else
        self.cursorVisible = false
    end
end

function InputBar:textinput(t)
    if self.active then
        self.text = self.text .. t
    end
end

function InputBar:keypressed(key)
    if not self.active then return end
    if key == "backspace" then
        local byteoffset = utf8.offset(self.text, -1)
        if byteoffset then
            self.text = string.sub(self.text, 1, byteoffset - 1)
        end
    elseif key == "return" then
        self.active = false
        if self.onEnter then
            self.onEnter(self.text) -- trigger callback
        end
    end
end

function InputBar:mousepressed(mx, my, button)
    if button == 1 then
        self.active = mx > self.x and mx < self.x + self.w and
        my > self.y and my < self.y + self.h
    end
end

function InputBar:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setFont(self.font)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(self.text, self.x + 5, self.y + 5)

    -- draw cursor if active
    if self.active and self.cursorVisible then
        local textWidth = self.font:getWidth(self.text)
        local textHeight = self.font:getHeight()
        local cx = self.x + 5 + textWidth + 2
        local cy = self.y + 5
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", cx, cy, 2, textHeight)
    end
end

return InputBar
