wf = require("libs.windfield")
local world = wf.newWorld(0, 1000, true)

sti = require("libs.sti")

Camera = require("libs.camera")

anim8 = require("libs.anim8")

Player = require("player")

local screenWidth = love.graphics.getWidth()
local screenHeight = love.graphics.getHeight()

local currentOS = love.system.getOS()
if currentOS == "iOS" or currentOS == "Android" then
    scale = 2
    miniScale = 1
else
    scale = 3
    miniScale = 2
end

font = love.graphics.newFont(30)
love.graphics.setFont(font)

local gameState
local previousGameState 
local pausedPlayerIndex

colors = {
    red = {1, 0, 0},
    blue = {0, 0, 1},
    green = {0, 1, 0},
    yellow = {1, 1, 0},
    white = {1, 1, 1},
    black = {0, 0, 0},
    pink = {1, 0.7, 0.7},
    cyan = {0, 1, 1},
}

availableColors = {
    colors.red,
    colors.blue,
    colors.green,
    colors.yellow,
    colors.white,
    colors.black,
    colors.pink,
    colors.cyan,
}

colorSelectionIndex = {
    {player = 1, colorIndex = 1},
    {player = 2, colorIndex = 2},
    {player = 3, colorIndex = 3},
    {player = 4, colorIndex = 4},
}

colorNames = {
    {name = "Red"},
    {name = "Blue"},
    {name = "Green"},
    {name = "Yellow"},
    {name = "White"},
    {name = "Black"},
    {name = "Pink"},
    {name = "Cyan"},
}

currentVolume = 0.5
love.audio.setVolume(currentVolume)

startMenuButtons = {
    {name = "Local"},
    {name = "Online"},
    {name = "Options"},
    {name = "Quit"},
}
startMenuIndex = 1

quitMenuButtons = {
    {name = "Yes"},
    {name = "No"},
}
quitMenuIndex = 1

settingsMenuButtons= {
    {name = "Volume: ", isOn = true},
    {name = "Hitbox: ", isOn = false},
    {name = "Back"},
}
settingsMenuIndex = 1

localSelectionButtons = {
    {name = "Start", isOn = false, msg = ": Requires at least 2 players"},
    {name = "Back"},
}
localSelectionIndex = 1

onlineSelectionButtons = {
    {name = "Host Room"},
    {name = "Join Room"},
    {name = "Back"},
}
onlineSelectionIndex = 1

pausedMenuButtons = {
    {name = "Unpause"},
    {name = "Settings"},
    {name = "Back to Main Menu"},
}
pausedMenuIndex = 1

function loadMap(mapFile)
    gameMap = sti(mapFile)
    mapWidth = gameMap.width * gameMap.tilewidth
    mapHeight = gameMap.height * gameMap.tileheight
    transitions = {}

    local mapName = mapFile:match("([^/]+)%.lua$") -- extracts "1-1" from "maps/1-1.lua"

local biomePrefix = mapName and mapName:match("^(%d+)%-%d+$")
if not biomePrefix then
    error("[ERROR] Invalid mapFile name:", mapFile)
    return
end


if biomePrefix then
    -- Check if the map should persist music (not ending in "-1")
    local persist = not mapFile:match("%-1$")

    if not persist or biomePrefix ~= currentBiomeMusic then
        if currentMapMusic then
            currentMapMusic:stop()
            currentMapMusic = nil
        end

        local musicPath = "sounds/music_for_biome_" .. biomePrefix .. ".mp3"
        currentMapMusic = love.audio.newSource(musicPath, "stream")
        currentMapMusic:setLooping(true)
        currentMapMusic:play()

        currentBiomeMusic = biomePrefix
    end
else
    -- Not a biome level, maybe it's "mainmenu", "hub", etc.
    if currentMapMusic then
        currentMapMusic:stop()
        currentMapMusic = nil
    end

    currentBiomeMusic = nil

    -- Optionally handle other music here like:
    -- if mapFile == "mainmenu" then sounds.main:play() end
end

    -- Reset world
    if world then world:destroy() end
    world = wf.newWorld(0, 1000)

    -- Transition to map
    if gameMap.layers["transition"] then
        for _, obj in ipairs(gameMap.layers["transition"].objects) do
            table.insert(transitions, obj)
        end
    end

    start = {}
    -- Send back to start menu block
    if gameMap.layers["start"] then
        for _, obj in ipairs(gameMap.layers["start"].objects) do
            table.insert(start, obj)
        end
    end

    -- Set player spawn pos
    if gameMap.layers["spawn"] and gameMap.layers["spawn"].type == "objectgroup" then

        for i, obj in pairs(gameMap.layers["spawn"].objects or {}) do 
            for i, joy in ipairs(joysticks) do 
                if obj.name == "player_spawn" then
                spawnX = obj.x
                spawnY = obj.y
                Player.new(world, joy, spawnX, spawnY, availableColors[colorSelectionIndex[i].colorIndex])
            break
                end
            end 
            break 
        end
    end 

    platform = {}
    if gameMap.layers["platform"] then 
        for i, obj in pairs(gameMap.layers["platform"].objects) do
            if obj.shape == "rectangle" then 
                local platform = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
                platform:setType("static")
                else
                print("⚠️ Skipping invalid platform at:", obj.name or "(unnamed)", obj.x, obj.y, obj.width, obj.height)
            end
        end
    end

world:setCallbacks(
    function (a, b, col)
        if a:getUserData() == "player" or b:getUserData() == "player" then 
            player.canJump = true
        end
    end,
    nil, nil, nil
)
fadeAlpha = 1 -- start map faded in
fadeDirection = -1 -- fade out to visible
isDead = false
fadeDuringTransition = false

currentMapName = mapFile:match("([^/]+)%.lua$") -- extracts "1-1" from "maps/1-1.lua"
end 

availableMaps = {
    {name = "1-1", file = "maps/1-1.lua", unlocked = true, place = 1},
}
selectedMapIndex = 1

function saveProgress()
    local unlocked = {}
    for _, map in ipairs(availableMaps) do
        if map.unlocked then
            table.insert(unlocked, map.name)
        end
    end
    love.filesystem.write("progress.dat", table.concat(unlocked, ","))
end

function loadProgress()
    if love.filesystem.getInfo("progress.dat") then
        local data = love.filesystem.read("progress.dat")
        local unlockedMaps = {}
        for name in string.gmatch(data, "([^,]+)") do
            unlockedMaps[name] = true
        end 
        for _, map in ipairs(availableMaps) do
            map.unlocked = unlockedMaps[map.name] or false 
        end
    end
end

function unlockNextMap(currentMapName)
    for i, map in ipairs(availableMaps) do
        if map.name == currentMapName and i < #availableMaps then
            availableMaps[i + 1].unlocked = true
            saveProgress()
            break 
        end
    end
end

function resetProgress()
    if love.filesystem.getInfo("progress.dat") then
        love.filesystem.remove("progress.dat")
    end

    -- Re-lock all maps except the first one
    for i, map in ipairs(availableMaps) do
        map.unlocked = (i == 1)
    end

    selectedMapindex = 1
end

function love.load()
    gameState = "startMenu"

    joysticks = love.joystick.getJoysticks()

    loadMap(availableMaps[1].file)

    platform = {}
    if gameMap.layers["platform"] and gameMap.layers["platform"].type == "objectgroup" then
        for i, obj in ipairs(gameMap.layers["platform"].objects) do
            if obj.shape == "rectangle" then
                local platform = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
                platform:setType("static")
            else
                print("⚠️ Skipping invalid platform at:", obj.name or "(unnamed)", obj.x, obj.y, obj.width, obj.height)
            end
        end 
    end
end

function love.update(dt)

    local joyCount = love.joystick.getJoystickCount()
    for i, btn in ipairs(localSelectionButtons) do
        if btn.name == "Start" then
            if joyCount >= 2 then
                btn.isOn = true 
                btn.msg = ""
            elseif joyCount > 4 then
                btn.msg = ": Remember, max of 4 players"
            end
        end
    end
    if gameState ~= "game" then return end 

    world:update(dt)
end 

function love.draw()
    love.graphics.setBackgroundColor(0.2, 0.7, 1)

    images = {
        dpad = love.graphics.newImage("assets/images/dpad.png"),
        ps_X = love.graphics.newImage("assets/images/ps_X.png"),
        xbox_A = love.graphics.newImage("assets/images/xbox_A.png"),
        rb = love.graphics.newImage("assets/images/rb.png"),
        lb = love.graphics.newImage("assets/images/lb.png"),
    }

    if gameState == "startMenu" then
       love.graphics.setColor(0.7, 0.5, 0.4)
       love.graphics.print("Ways of the", screenWidth / 2 - 350, screenHeight / 2 - 300, nil, scale) 
       love.graphics.setColor(1, 0.4, 0.5)
       love.graphics.print("PIG", screenWidth / 2 + 200, screenHeight / 2 - 315, nil, scale + 1)
       
        love.graphics.setColor(1,1,1,1)

       love.graphics.print("Navigate", screenWidth / 2 - 800, screenHeight / 2 + 300, nil, miniScale)
       love.graphics.print("Select", screenWidth / 2 - 800, screenHeight / 2 + 200, nil, miniScale)
       love.graphics.draw(images.dpad, screenWidth / 2 - 530, screenHeight / 2 + 280, nil, 0.5)
       love.graphics.draw(images.xbox_A, screenWidth / 2 - 600, screenHeight / 2 + 205, nil, 0.33)
       love.graphics.draw(images.ps_X, screenWidth / 2 - 530, screenHeight / 2 + 195, nil, 0.4)

       for i, btn in ipairs(startMenuButtons) do
        local y = screenHeight / 2 + (i - startMenuIndex) * 40
        if i == startMenuIndex then
            love.graphics.setColor(0, 1, 0)
            love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(btn.name, 0, y, screenWidth, "center")
        end
       end
       love.graphics.setColor(1,1,1,1)
    elseif gameState == "quitMenu" then
        love.graphics.print("Are you sure you want to quit?", screenWidth / 2 - 350, screenHeight / 2 - 300, nil, miniScale)
        for i, btn in ipairs(quitMenuButtons) do
            local y = screenHeight / 2 + (i - quitMenuIndex) * 40

            if i == quitMenuIndex then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(btn.name, 0, y, screenWidth, "center")
            end
        end
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "settingsMenu" then
        love.graphics.print("Options", screenWidth / 2 - 150, screenHeight / 2 - 500, nil, scale)

        for i, btn in ipairs(settingsMenuButtons) do
            local y = screenHeight / 2 + (i - settingsMenuIndex) * 40

            if i == settingsMenuIndex then
                if btn.name == "Hitbox: " then
                    if btn.isOn then
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.printf("> " .. btn.name .. "ON", 0, y, screenWidth, "center")
                    else
                        love.graphics.setColor(1, 0, 0)
                        love.graphics.printf("> " .. btn.name .. "OFF", 0, y, screenWidth, "center")
                    end
                elseif btn.name == "Volume: " then
                    if btn.isOn then
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.printf("> " .. btn.name .. math.floor(currentVolume * 100) .. "%", 0, y, screenWidth, "center")
                    else
                        love.graphics.setColor(1, 0, 0)
                        love.graphics.printf("> " .. btn.name .. "MUTED", 0, y, screenWidth, "center")
                    end 
                else
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center") 
                end 
            else
                love.graphics.setColor(1, 1, 1)
                if btn.name == "Hitbox: " then
                    if btn.isOn then
                        love.graphics.printf("> " .. btn.name .. "ON", 0, y, screenWidth, "center")
                    else
                        love.graphics.printf("> " .. btn.name .. "OFF", 0, y, screenWidth, "center")
                    end
                elseif btn.name == "Volume: " then
                    if btn.isOn then
                        love.graphics.printf("> " .. btn.name .. math.floor(currentVolume * 100) .. "%", 0, y, screenWidth, "center")
                    else
                        love.graphics.printf("> " .. btn.name .. "MUTED", 0, y, screenWidth, "center")
                    end 
                else
                    love.graphics.printf(btn.name, 0, y, screenWidth, "center")
                end 
            end
            love.graphics.setColor(1,1,1,1)
        end
    elseif gameState == "localSelection" then
        local joysticks = love.joystick.getJoysticks()
        local joyCount = #joysticks
        local maxPlayers = 4
        local screenWidth = screenWidth
        local screenHeight = screenHeight
        if joyCount > maxPlayers then
            joyCount = maxPlayers
        end
        love.graphics.print("Local Coop", screenWidth / 2 - 210, screenHeight / 2 - 500, nil, scale)
        love.graphics.print("Players: (" .. joyCount .. "/" .. maxPlayers .. ")", screenWidth / 2 - 240, screenHeight / 2 - 400, nil, scale)
        love.graphics.print("Navigate", screenWidth / 2 - 800, screenHeight / 2 + 300, nil, miniScale)
        love.graphics.print("Select", screenWidth / 2 - 800, screenHeight / 2 + 200, nil, miniScale)
        love.graphics.print("Change Color", screenWidth / 2 - 800, screenHeight / 2 + 400, nil, miniScale)
        love.graphics.draw(images.dpad, screenWidth / 2 - 530, screenHeight / 2 + 280, nil, 0.5)
        love.graphics.draw(images.xbox_A, screenWidth / 2 - 600, screenHeight / 2 + 205, nil, 0.33)
        love.graphics.draw(images.ps_X, screenWidth / 2 - 530, screenHeight / 2 + 195, nil, 0.4)
        love.graphics.draw(images.lb, screenWidth / 2 - 360, screenHeight / 2 + 400, nil, 0.4)
        love.graphics.draw(images.rb, screenWidth / 2 - 240, screenHeight / 2 + 397, nil, 0.4)
        for i, _ in ipairs(joysticks) do
            screenHeight = screenHeight - 100
            love.graphics.setColor(availableColors[colorSelectionIndex[i].colorIndex])
            love.graphics.print("Player " .. i .. ": " .. colorNames[colorSelectionIndex[i].colorIndex].name, screenWidth / 2 - 500, screenHeight / 2)
        end
        for i, btn in ipairs(localSelectionButtons) do
            local y = screenHeight / 2 + (i - localSelectionIndex) * 40

            if i == localSelectionIndex then
                if btn.name == "Start" then 
                    if not btn.isOn then
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.printf("> " .. btn.name .. ": Requires 2 players, max of 4", 0, y, screenWidth, "center")
                    else
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
                    end 
                else
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
                end
            else
                love.graphics.setColor(1, 1, 1)
                if btn.name == "Start" then
                    if not btn.isOn then
                        love.graphics.printf(btn.name .. ": Requires 2 players, max of 4", 0, y, screenWidth, "center")
                    else
                        love.graphics.printf(btn.name, 0, y, screenWidth, "center")
                    end 
                else
                    love.graphics.printf(btn.name, 0, y, screenWidth, "center")
                end
            end
        end
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "onlineSelection" then
        love.graphics.print("Under construction!", screenWidth / 2 - 150, screenHeight / 2 - 500, nil, scale)
        for i, btn in ipairs(onlineSelectionButtons) do
            local y = screenHeight / 2 + (i - onlineSelectionIndex) * 40
            if i == onlineSelectionIndex then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(btn.name, 0, y, screenWidth, "center")
            end
        end
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "mapSelection" then
        local joysticks = love.joystick.getJoysticks()
        local joyCount = #joysticks
        local maxPlayers = 4
        if joyCount > maxPlayers then
            joyCount = maxPlayers
        end

        love.graphics.print("Select a Map", screenWidth / 2 - 210, screenHeight / 2 - 500, nil, scale)
        love.graphics.print("Players: (" .. joyCount .. "/" .. maxPlayers .. ")", screenWidth / 2 - 240, screenHeight / 2 - 400, nil, scale)
        love.graphics.print("Navigate", screenWidth / 2 - 800, screenHeight / 2 + 300, nil, miniScale)
        love.graphics.print("Select", screenWidth / 2 - 800, screenHeight / 2 + 200, nil, miniScale)
        love.graphics.draw(images.dpad, screenWidth / 2 - 530, screenHeight / 2 + 280, nil, 0.5)
        love.graphics.draw(images.xbox_A, screenWidth / 2 - 600, screenHeight / 2 + 205, nil, 0.33)
        love.graphics.draw(images.ps_X, screenWidth / 2 - 530, screenHeight / 2 + 195, nil, 0.4)

        for i, map in ipairs(availableMaps) do
            local y = screenHeight / 2 + (i - selectedMapIndex) * 40

            if map.unlocked then
                if i == selectedMapIndex then
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.printf("> " .. map.name, 0, y, screenWidth, "center")
                else
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.printf(map.name, 0, y, screenWidth, "center")
                end
            end 
        end
    elseif gameState == "pauseMenu" then
        love.graphics.print("Paused", screenWidth / 2 - 200, screenHeight / 2 - 500, nil, scale)
        
        love.graphics.print("Player " .. pausedPlayerIndex .. " Paused", screenWidth / 2 - 230, screenHeight / 2 - 450, nil, miniScale)

        for i, btn in ipairs(pausedMenuButtons) do
            local y = screenHeight / 2 + (i - pausedMenuIndex) * 40

            if i == pausedMenuIndex then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("> " .. btn.name, 0, y, screenWidth, "center")
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(btn.name, 0, y, screenWidth, "center")
            end
        end
        love.graphics.setColor(1,1,1,1)
    elseif gameState == "game" then 

        local groundX, groundY = ground:getPosition()
        local groundW, groundH = 3000, 50
        love.graphics.setColor(0, 0, 1)
        love.graphics.rectangle("fill", groundX, groundY, groundW, groundH)
        love.graphics.setColor(1,1,1,1)
    end 
end 

function love.gamepadpressed(joystick, btn)
    if gameState == "startMenu" then
        local option = startMenuButtons[startMenuIndex]
        if btn == "dpup" then
            startMenuIndex = startMenuIndex - 1

            if startMenuIndex < 1 then startMenuIndex = #startMenuButtons end
        elseif btn == "dpdown" then
            startMenuIndex = startMenuIndex + 1

            if startMenuIndex > #startMenuButtons then startMenuIndex = 1 end
        elseif btn == "a" then
            startMenuIndex = 1
            if option.name == "Local" then
                previousGameState = gameState
                gameState = "localSelection"
            elseif option.name == "Online" then
                previousGameState = gameState
                gameState = "onlineSelection"
            elseif option.name == "Options" then
                previousGameState = gameState 
                gameState = "settingsMenu"
            elseif option.name == "Quit" then
                previousGameState = gameState
                gameState = "quitMenu"
            end 
        end
    elseif gameState == "localSelection" then
        local option = localSelectionButtons[localSelectionIndex]
        local joysticks = love.joystick.getJoysticks()
        player = {}
        if btn == "dpup" then
            localSelectionIndex = localSelectionIndex - 1

            if localSelectionIndex < 1 then localSelectionIndex = #localSelectionButtons end 
        elseif btn == "dpdown" then
            localSelectionIndex = localSelectionIndex + 1
            
            if localSelectionIndex > #localSelectionButtons then localSelectionIndex = 1 end
        elseif btn == "rightshoulder" or btn == "leftshoulder" then
            for i, joy in ipairs(joysticks) do
                if joy == joystick then 
                    if btn == "rightshoulder" then
                        local p = colorSelectionIndex[i]
                        p.colorIndex = p.colorIndex + 1
                        if p.colorIndex > #availableColors then p.colorIndex = 1 end
                    elseif btn == "leftshoulder" then
                        local p = colorSelectionIndex[i]
                        p.colorIndex = p.colorIndex - 1
                        if p.colorIndex < 1 then p.colorIndex = #availableColors end
                    end 
                end 
            end 
        elseif btn == "a" then 
            if option.name == "Start" then
                if option.isOn then
                    localSelectionIndex = 1

                    local maxPlayers = 4
                    for i = 1, math.min(#joysticks, maxPlayers) do
                        local x, y = 100 + i * 100, 100
                        local joy = joysticks[i]
                        player[i] = Player.new(world, joy, x, y, availableColors[colorSelectionIndex[i].colorIndex])
                    end
                    gameState = "mapSelection"
                end
            elseif option.name == "Back" then
                localSelectionIndex = 1
                gameState = previousGameState
            end
        end
    elseif gameState == "onlineSelection" then
        local option = onlineSelectionButtons[onlineSelectionIndex]
        if btn == "dpup" then
            onlineSelectionIndex = onlineSelectionIndex - 1

            if onlineSelectionIndex < 1 then onlineSelectionIndex = #onlineSelectionButtons end
        elseif btn == "dpdown" then
            onlineSelectionIndex = onlineSelectionIndex + 1

            if onlineSelectionIndex > #onlineSelectionButtons then onlineSelectionIndex = 1 end
        elseif btn == "a" then
            if option.name == "Back" then
                gameState = previousGameState
            end 
        end
    elseif gameState == "mapSelection" then
        local option = availableMaps[selectedMapIndex]

        if btn == "dpup" then
            selectedMapIndex = selectedMapIndex - 1

            if selectedMapIndex < 1 then selectedMapIndex = #availableMaps end 
        elseif btn == "dpdown" then
            selectedMapIndex = selectedMapIndex + 1
            if selectedMapIndex > #availableMaps then selectedMapIndex = 1 end 
        elseif btn == "a" then
            if option.unlocked then
                local mapFile = option.file
                local maxPlayers = 4
                for i = 1, math.min(#joysticks, maxPlayers) do
                    local x, y = 100 + i * 100, 100
                    local joy = joysticks[i]
                    player[i] = Player.new(world, joy, x, y, availableColors[colorSelectionIndex[i].colorIndex])
                end
                loadMap(loadMap)
                gameState = "game"
            end 
        end
    elseif gameState == "quitMenu" then
        local option = quitMenuButtons[quitMenuIndex]

        if btn == "dpup" then
            quitMenuIndex = quitMenuIndex - 1

            if quitMenuIndex < 1 then quitMenuIndex = #quitMenuButtons end 
        elseif btn == "dpdown" then
            quitMenuIndex = quitMenuIndex + 1

            if quitMenuIndex > #quitMenuButtons then quitMenuIndex = 1 end
        elseif btn == "a" then
            quitMenuIndex = 1
            if option.name == "Yes" then
                love.event.quit()
            elseif option.name == "No" then
                gameState = previousGameState 
            end
        end 
    elseif gameState == "settingsMenu" and (not pausedPlayer or (pausedPlayer.paused and pausedPlayer.joystick == joystick)) then
        local option = settingsMenuButtons[settingsMenuIndex]
        if btn == "dpup" then
            settingsMenuIndex = settingsMenuIndex - 1

            if settingsMenuIndex < 1 then settingsMenuIndex = #settingsMenuButtons end
        elseif btn == "dpdown" then
            settingsMenuIndex = settingsMenuIndex + 1
            if settingsMenuIndex > #settingsMenuButtons then settingsMenuIndex = 1 end
        elseif btn == "dpleft" then
            if option.name == "Volume: " and option.isOn then
                currentVolume = currentVolume - 0.02
            end
        elseif btn == "dpright" then
            if option.name == "Volume: " and option.isOn then
                currentVolume = currentVolume + 0.02
            end
        elseif btn == "a" then
            if option.name == "Volume: " then
                if option.isOn then
                    previousVolume = currentVolume
                    currentVolume = 0
                elseif not option.isOn then
                    currentVolume = previousVolume
                end

                option.isOn = not option.isOn
            elseif option.name == "Hitbox: " then
                option.isOn = not option.isOn
            elseif option.name == "Back" then
                settingsMenuIndex = 1
                if previousGameState == "pauseMenu" then
                    previousGameState = "game"
                    gameState = "pauseMenu"
                    return 
                end
                gameState = previousGameState 
            end
        end
        love.audio.setVolume(currentVolume)
        if currentVolume > 1 then currentVolume = 1 end
        if currentVolume < 0 then currentVolume = 0 end 
    elseif gameState == "pauseMenu" then
        local option = pausedMenuButtons[pausedMenuIndex]
        pausedPlayer = player[pausedPlayerIndex] 

        if pausedPlayer.joystick == joystick and pausedPlayer.paused then
            if btn == "dpup" then
                pausedMenuIndex = pausedMenuIndex - 1

                if pausedMenuIndex < 1 then pausedMenuIndex = #pausedMenuButtons end
            elseif btn == "dpdown" then
                pausedMenuIndex = pausedMenuIndex + 1

                if pausedMenuIndex > #pausedMenuButtons then pausedMenuIndex = 1 end       
            elseif btn == "start" then
                pausedPlayerIndex = 0
                pausedPlayer.paused = false 
                gameState = previousGameState
            elseif btn == "a" then
                pausedMenuIndex = 1
                if option.name == "Unpause" then
                    pausedPlayerIndex = 0
                    pausedPlayer.paused = false 
                    gameState = previousGameState
                elseif option.name == "Settings" then
                    previousGameState = "pauseMenu"
                    gameState = "settingsMenu"
                elseif option.name == "Back to Main Menu" then
                    pausedPlayerIndex = 0
                    pausedPlayer.paused = false
                    gameState = "startMenu"
                    player = {}
                end
            end
        end 
    elseif gameState == "game" then
        if btn == "start" then
            for i, p in ipairs(player) do
                if p.joystick == joystick then
                    p.paused = true 
                    pausedPlayerIndex = i 
                    previousGameState = gameState
                    gameState = "pauseMenu"
                    break 
                end
            end
        end
    end
end