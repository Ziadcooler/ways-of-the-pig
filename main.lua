wf = require("libs.windfield")
local world = wf.newWorld(0, 1000, true)

Camera = require("libs.camera")

anim8 = require("libs.anim8")

Player = require("player")
local player1, player2

screenWidth = love.graphics.getWidth()
screenHeight = love.graphics.getHeight()

currentOS = love.system.getOS()
if currentOS == "iOS" or currentOS == "Android" then
    scale = 2
    miniScale = 1
else
    scale = 3
    miniScale = 2
end

sharpFont = love.graphics.newFont(24)
love.graphics.setFont(sharpFont)


startMenuButtons = {
    {name = "Start"},
    {name = "Options"},
    {name = "Quit"}
}
startMenuIndex = 1

function love.load()
    gameState = "startMenu"

    ground = world:newRectangleCollider(0, 500, 3000, 50)
    ground:setType("static")

    joysticks = love.joystick.getJoysticks()
    player1 = Player.new(world, joysticks[1], 100, 100)
end

function love.update(dt)
    if gameState ~= "game" then return end 

    player1:update(dt)
    world:update(dt)
end 

function love.draw()
    love.graphics.setBackgroundColor(0.2, 0.7, 1)
    if gameState == "startMenu" then
        love.graphics.setColor(0.7, 0.5, 0.4)
       love.graphics.print("Ways of the", screenWidth / 2 - 250, screenHeight / 2 - 300, nil, scale) 
       love.graphics.setColor(1, 0.4, 0.5)
       love.graphics.print("PIG", screenWidth / 2 + 200, screenHeight / 2 - 315, nil, scale + 1)
    end

    if gameState == "game" then 
    player1:draw()
        local groundX, groundY = ground:getPosition()
        local groundW, groundH = 3000, 50
        love.graphics.setColor(0, 0, 1)
        love.graphics.rectangle("fill", groundX - 25, groundY - 25, groundW, groundH)
        love.graphics.setColor(1,1,1,1)
    end 
end 