import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"

local pd <const> = playdate
local gfx <const> = pd.graphics

-- ==========================================
-- WEATHER MODULE
-- ==========================================
local Weather = {}

-- Weather Types
Weather.SUNNY = 1
Weather.CLOUDY = 2
Weather.RAIN = 3
Weather.HEATWAVE = 4

Weather.names = {
    [Weather.SUNNY] = "Sunny",
    [Weather.CLOUDY] = "Cloudy",
    [Weather.RAIN] = "Rain",
    [Weather.HEATWAVE] = "Heatwave"
}

-- Base temperatures for each weather type
Weather.baseTemps = {
    [Weather.SUNNY] = 75,
    [Weather.CLOUDY] = 65,
    [Weather.RAIN] = 60,
    [Weather.HEATWAVE] = 90
}

function Weather.generateForecast()
    -- Simple random forecast
    local r = math.random()
    local type = Weather.SUNNY
    
    if r < 0.4 then type = Weather.SUNNY
    elseif r < 0.7 then type = Weather.CLOUDY
    elseif r < 0.9 then type = Weather.RAIN
    else type = Weather.HEATWAVE
    end
    
    local temp = Weather.baseTemps[type] + math.random(-5, 5)
    
    return {
        type = type,
        temp = temp,
        desc = Weather.names[type]
    }
end

function Weather.generateActual(forecast)
    -- 70% chance forecast is accurate
    -- 30% chance it changes
    local actualType = forecast.type
    local actualTemp = forecast.temp
    
    if math.random() > 0.7 then
        -- Weather changed!
        local r = math.random()
        if r < 0.4 then actualType = Weather.SUNNY
        elseif r < 0.7 then actualType = Weather.CLOUDY
        elseif r < 0.9 then actualType = Weather.RAIN
        else actualType = Weather.HEATWAVE
        end
        
        -- Recalculate temp based on new type, but keep it somewhat related to forecast to avoid wild jumps? 
        -- Actually, if it rains instead of heatwave, temp should drop.
        actualTemp = Weather.baseTemps[actualType] + math.random(-5, 5)
    else
        -- Accurate type, small temp variation
        actualTemp = actualTemp + math.random(-2, 2)
    end
    
    return {
        type = actualType,
        temp = actualTemp,
        desc = Weather.names[actualType]
    }
end

-- ==========================================
-- GAME MODULE
-- ==========================================
local Game = {}

-- Constants
Game.MAX_DAYS = 30
Game.STARTING_MONEY = 20.00

-- Prices for supplies
Game.COST_LEMONS = 0.50 -- per lemon? No, usually bulk. Let's say 0.25
Game.COST_SUGAR = 0.10 -- per cup worth? Let's say 0.05
Game.COST_ICE = 0.02 -- per cube
Game.COST_CUPS = 0.05 -- per cup

-- Bulk packs
Game.PACK_LEMONS_QTY = 10
Game.PACK_LEMONS_COST = 2.00 -- 0.20 each
Game.PACK_SUGAR_QTY = 20
Game.PACK_SUGAR_COST = 1.00 -- 0.05 each
Game.PACK_ICE_QTY = 50
Game.PACK_ICE_COST = 1.00 -- 0.02 each
Game.PACK_CUPS_QTY = 25
Game.PACK_CUPS_COST = 1.00 -- 0.04 each

function Game.init()
    Game.state = {
        day = 1,
        money = Game.STARTING_MONEY,
        inventory = {
            lemons = 0,
            sugar = 0,
            ice = 0,
            cups = 0
        },
        recipe = {
            lemonsPerPitcher = 4,
            sugarPerPitcher = 4,
            icePerCup = 3
        },
        pricePerCup = 0.25,
        weather = {
            forecast = Weather.generateForecast(),
            actual = nil
        },
        history = {}
    }
end

function Game.buy(item, qty, cost)
    if Game.state.money >= cost then
        Game.state.money = Game.state.money - cost
        Game.state.inventory[item] = Game.state.inventory[item] + qty
        return true
    end
    return false
end

function Game.simulateDay()
    local s = Game.state
    
    -- Generate actual weather
    s.weather.actual = Weather.generateActual(s.weather.forecast)
    local w = s.weather.actual
    
    -- Calculate Demand based on Weather/Temp
    -- Base customers: ~30-100 depending on weather
    local baseCustomers = 30
    if w.type == Weather.SUNNY then baseCustomers = 60
    elseif w.type == Weather.HEATWAVE then baseCustomers = 100
    elseif w.type == Weather.CLOUDY then baseCustomers = 40
    elseif w.type == Weather.RAIN then baseCustomers = 15
    end
    
    -- Temp bonus
    if w.temp > 70 then
        baseCustomers = baseCustomers + (w.temp - 70) * 2
    end
    
    -- Price Factor
    -- Standard price is ~0.25. Higher price reduces customers.
    local priceFactor = 1.0
    if s.pricePerCup > 0.25 then
        local diff = s.pricePerCup - 0.25
        -- Every 10 cents over reduces customers by 20%?
        priceFactor = math.max(0, 1.0 - (diff * 4)) 
    elseif s.pricePerCup < 0.25 then
        -- Cheaper brings more
        local diff = 0.25 - s.pricePerCup
        priceFactor = 1.0 + (diff * 2)
    end
    
    -- Recipe Quality
    -- Ideal: 4 lemons, 4 sugar.
    -- Too sour: > lemons, < sugar.
    -- Too sweet: < lemons, > sugar.
    -- Diluted: < 4 lemons, < 4 sugar.
    local r = s.recipe
    local quality = 1.0
    
    local lemonRatio = r.lemonsPerPitcher / 4.0
    local sugarRatio = r.sugarPerPitcher / 4.0
    
    if lemonRatio < 1.0 or sugarRatio < 1.0 then
        quality = math.min(lemonRatio, sugarRatio) -- Diluted penalty
    end
    
    if math.abs(lemonRatio - sugarRatio) > 0.5 then
        quality = quality * 0.8 -- Imbalanced penalty
    end
    
    -- Potential Customers
    local potential = math.floor(baseCustomers * priceFactor * math.random(80, 120) / 100)
    
    -- Simulation Loop
    local cupsSold = 0
    local customersUnsatisfied = 0 -- Sold out
    local customersDisliked = 0 -- Bad recipe (maybe they buy but don't return? simplified: they buy based on quality chance)
    
    -- Pitcher management
    -- 1 Pitcher = 10 cups (standard)
    local cupsInPitcher = 0
    
    for i = 1, potential do
        -- Do we have stock to sell?
        -- Need cup + ice.
        -- Need pitcher content (lemons + sugar made into juice).
        
        if s.inventory.cups < 1 or s.inventory.ice < r.icePerCup then
            customersUnsatisfied = customersUnsatisfied + 1
            -- Sold out of basics
        else
            -- Check pitcher
            if cupsInPitcher == 0 then
                -- Make new pitcher
                if s.inventory.lemons >= r.lemonsPerPitcher and s.inventory.sugar >= r.sugarPerPitcher then
                    s.inventory.lemons = s.inventory.lemons - r.lemonsPerPitcher
                    s.inventory.sugar = s.inventory.sugar - r.sugarPerPitcher
                    cupsInPitcher = 10
                else
                    -- Cannot make pitcher
                    customersUnsatisfied = customersUnsatisfied + 1
                    goto continue_sim
                end
            end
            
            -- Sell cup
            -- Quality check: if quality is low, maybe they don't buy? 
            -- Or maybe they buy but we get bad rep? 
            -- Let's say quality affects purchase chance slightly if it's REALLY bad, 
            -- but mostly price/weather drives traffic.
            -- Let's assume they buy if they are in line, but maybe complain.
            
            s.inventory.cups = s.inventory.cups - 1
            s.inventory.ice = s.inventory.ice - r.icePerCup
            cupsInPitcher = cupsInPitcher - 1
            cupsSold = cupsSold + 1
            s.money = s.money + s.pricePerCup
        end
        
        ::continue_sim::
    end
    
    -- End of day logic
    -- Ice melts!
    s.inventory.ice = 0 
    
    -- Record history
    local profit = (cupsSold * s.pricePerCup) -- Gross profit, not net (expenses happened earlier)
    -- Actually we want daily P&L. 
    -- We don't track daily expenses easily unless we store "money at start of day".
    
    local result = {
        day = s.day,
        weather = w,
        sold = cupsSold,
        potential = potential,
        unsatisfied = customersUnsatisfied,
        income = cupsSold * s.pricePerCup,
        moneyEnd = s.money
    }
    
    table.insert(s.history, result)
    
    -- Prepare next day
    s.day = s.day + 1
    s.weather.forecast = Weather.generateForecast()
    
    return result
end

-- ==========================================
-- UI MODULE
-- ==========================================
local UI = {}

-- Fonts
-- Using system default for simplicity and robustness in single-file mode
-- local fontBold = gfx.font.new('font/kRoobert10Bold') 

function UI.init()
    -- Load fonts if needed, or just use default
    gfx.setFont(gfx.font.kVariantBold)
end

function UI.drawTitle()
    gfx.clear()
    gfx.drawTextAligned("*LEMONADE STAND*", 200, 80, kTextAlignment.center)
    gfx.drawTextAligned("Press A to Start", 200, 140, kTextAlignment.center)
    gfx.drawTextAligned("(Crank to adjust settings in game)", 200, 200, kTextAlignment.center)
end

function UI.drawPrep(gameState, selectionIndex)
    gfx.clear()
    
    -- Top Bar
    gfx.fillRect(0, 0, 400, 30)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("Day " .. gameState.day, 10, 8)
    gfx.drawTextAligned(string.format("$%.2f", gameState.money), 390, 8, kTextAlignment.right)
    
    local w = gameState.weather.forecast
    gfx.drawTextAligned("Forecast: " .. w.desc .. " " .. w.temp .. "F", 200, 8, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    
    -- Main Content
    local yStart = 40
    local lineHeight = 20
    
    local items = {
        {label="Lemons", inv=gameState.inventory.lemons, type="buy", cost=2.00, qty=10},
        {label="Sugar", inv=gameState.inventory.sugar, type="buy", cost=1.00, qty=20},
        {label="Ice", inv=gameState.inventory.ice, type="buy", cost=1.00, qty=50},
        {label="Cups", inv=gameState.inventory.cups, type="buy", cost=1.00, qty=25},
        {label="----------------", type="sep"},
        {label="Lemons/Pitcher", val=gameState.recipe.lemonsPerPitcher, type="setting"},
        {label="Sugar/Pitcher", val=gameState.recipe.sugarPerPitcher, type="setting"},
        {label="Ice/Cup", val=gameState.recipe.icePerCup, type="setting"},
        {label="Price/Cup", val=gameState.pricePerCup, type="price"},
        {label="----------------", type="sep"},
        {label="START DAY", type="action"}
    }
    
    -- Scrolling Logic
    local scrollOffset = 0
    if selectionIndex > 7 then
        scrollOffset = (selectionIndex - 7) * lineHeight
    end
    
    -- Clip to main content area (below top bar)
    gfx.setClipRect(0, 30, 400, 210)
    
    for i, item in ipairs(items) do
        local y = yStart + (i-1)*lineHeight - scrollOffset
        
        -- Only draw if visible (optimization + cleanliness)
        if y > 10 and y < 240 then
            -- Highlight selection
            if i == selectionIndex then
                gfx.fillRoundRect(10, y-2, 380, lineHeight, 4)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            else
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            end
            
            if item.type == "buy" then
                gfx.drawText(item.label .. ": " .. item.inv, 20, y)
                gfx.drawTextAligned("Buy " .. item.qty .. " ($" .. string.format("%.2f", item.cost) .. ")", 380, y, kTextAlignment.right)
            elseif item.type == "setting" then
                gfx.drawText(item.label, 20, y)
                gfx.drawTextAligned("< " .. item.val .. " >", 380, y, kTextAlignment.right)
            elseif item.type == "price" then
                gfx.drawText(item.label, 20, y)
                gfx.drawTextAligned("< $" .. string.format("%.2f", item.val) .. " >", 380, y, kTextAlignment.right)
            elseif item.type == "sep" then
                gfx.drawLine(20, y+10, 380, y+10)
            elseif item.type == "action" then
                gfx.drawTextAligned(item.label, 200, y, kTextAlignment.center)
            end
        end
    end
    
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function UI.drawSim(gameState, simState)
    gfx.clear()
    
    -- Sky
    local w = gameState.weather.actual
    if w.type == 1 or w.type == 4 then -- Sunny/Heatwave
        gfx.fillCircleAtPoint(350, 50, 30) -- Sun
    elseif w.type == 2 then -- Cloudy
        gfx.fillEllipseInRect(320, 30, 60, 30)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillEllipseInRect(325, 35, 50, 20)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawEllipseInRect(320, 30, 60, 30)
    elseif w.type == 3 then -- Rain
        -- Draw rain drops
        for i=1, 20 do
            local rx = math.random(0, 400)
            local ry = math.random(0, 240)
            gfx.drawLine(rx, ry, rx-5, ry+10)
        end
    end
    
    -- Ground
    gfx.fillRect(0, 180, 400, 60)
    
    -- Stand
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(150, 120, 100, 60) -- Booth body
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(150, 120, 100, 60)
    gfx.drawLine(150, 120, 150, 80) -- Poles
    gfx.drawLine(250, 120, 250, 80)
    gfx.fillRect(140, 80, 120, 10) -- Roof
    
    -- Text Info
    gfx.drawText("Selling...", 20, 20)
    gfx.drawText("Temp: " .. w.temp .. "F", 20, 40)
    gfx.drawText("Sold: " .. (simState.sold or 0), 20, 200)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("Money: $" .. string.format("%.2f", gameState.money), 250, 200)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function UI.drawResult(gameState, lastResult)
    gfx.clear()
    
    gfx.drawTextAligned("DAY " .. lastResult.day .. " RESULTS", 200, 20, kTextAlignment.center)
    
    local y = 60
    gfx.drawText("Weather: " .. lastResult.weather.desc .. " (" .. lastResult.weather.temp .. "F)", 40, y); y=y+25
    gfx.drawText("Cups Sold: " .. lastResult.sold, 40, y); y=y+25
    gfx.drawText("Potential Customers: " .. lastResult.potential, 40, y); y=y+25
    gfx.drawText("Missed Sales (Stock): " .. lastResult.unsatisfied, 40, y); y=y+25
    gfx.drawText("Income: $" .. string.format("%.2f", lastResult.income), 40, y); y=y+25
    
    gfx.drawLine(40, y, 360, y); y=y+10
    
    gfx.drawText("Current Money: $" .. string.format("%.2f", lastResult.moneyEnd), 40, y)
    
    gfx.drawTextAligned("Press A to Continue", 200, 210, kTextAlignment.center)
end

function UI.drawGameOver(gameState)
    gfx.clear()
    gfx.drawTextAligned("GAME OVER", 200, 100, kTextAlignment.center)
    gfx.drawTextAligned("You ran out of money!", 200, 130, kTextAlignment.center)
    gfx.drawTextAligned("Press A to Restart", 200, 160, kTextAlignment.center)
end

-- ==========================================
-- MAIN LOGIC
-- ==========================================

-- Game States
local STATE_TITLE = 1
local STATE_PREP = 2
local STATE_SIM = 3
local STATE_RESULT = 4
local STATE_GAMEOVER = 5

local currentState = STATE_TITLE
local selectionIndex = 1
local simTimer = nil
local lastResult = nil
local simDisplayState = { sold = 0 }
local crankAccumulator = 0

function startSimulation()
    currentState = STATE_SIM
    lastResult = Game.simulateDay()
    
    -- Setup animation
    simDisplayState.sold = 0
    
    -- Timer to animate the day
    simTimer = pd.timer.new(3000, 0, lastResult.sold, pd.easingFunctions.linear)
    simTimer.updateCallback = function(timer)
        simDisplayState.sold = math.floor(timer.value)
    end
    simTimer.timerEndedCallback = function()
        currentState = STATE_RESULT
    end
end

function handlePrepInput()
    -- Navigation
    if pd.buttonJustPressed(pd.kButtonUp) then
        selectionIndex = selectionIndex - 1
        if selectionIndex < 1 then selectionIndex = 11 end -- Wrap
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        selectionIndex = selectionIndex + 1
        if selectionIndex > 11 then selectionIndex = 1 end -- Wrap
    end
    
    -- Actions
    if pd.buttonJustPressed(pd.kButtonA) then
        if selectionIndex <= 4 then -- Buy items
            local items = {"lemons", "sugar", "ice", "cups"}
            local costs = {Game.PACK_LEMONS_COST, Game.PACK_SUGAR_COST, Game.PACK_ICE_COST, Game.PACK_CUPS_COST}
            local qtys = {Game.PACK_LEMONS_QTY, Game.PACK_SUGAR_QTY, Game.PACK_ICE_QTY, Game.PACK_CUPS_QTY}
            
            Game.buy(items[selectionIndex], qtys[selectionIndex], costs[selectionIndex])
        elseif selectionIndex == 11 then -- Start Day
            startSimulation()
        end
    end
    
    -- Crank for settings
    local change, acceleratedChange = pd.getCrankChange()
    
    if selectionIndex == 9 then -- Price
        -- For price, allow finer control
        if math.abs(change) > 0 then
            -- Sensitivity: 1 full turn = $1.00?
            -- 360 degrees. 
            -- Let's just add change/100
            Game.state.pricePerCup = Game.state.pricePerCup + (change / 360.0)
            if Game.state.pricePerCup < 0.01 then Game.state.pricePerCup = 0.01 end
        end
    else
        -- For integers, use ticks manually
        crankAccumulator = crankAccumulator + change
        local degreesPerTick = 30 -- 360 / 12
        local ticks = 0
        
        if math.abs(crankAccumulator) >= degreesPerTick then
            ticks = math.floor(crankAccumulator / degreesPerTick)
            -- If negative, math.floor works differently (-35/30 = -1.16 -> -2). 
            -- We want truncation towards zero or just simple handling.
            -- Let's use simple subtraction for single ticks or just cast to int.
            -- Actually, math.floor(35/30) = 1. math.floor(-35/30) = -2.
            -- We want -1.
            if crankAccumulator < 0 then
                ticks = math.ceil(crankAccumulator / degreesPerTick)
            end
            
            crankAccumulator = crankAccumulator - (ticks * degreesPerTick)
        end

        if ticks ~= 0 then
            if selectionIndex == 6 then -- Lemons/Pitcher
                Game.state.recipe.lemonsPerPitcher = math.max(1, Game.state.recipe.lemonsPerPitcher + ticks)
            elseif selectionIndex == 7 then -- Sugar/Pitcher
                Game.state.recipe.sugarPerPitcher = math.max(1, Game.state.recipe.sugarPerPitcher + ticks)
            elseif selectionIndex == 8 then -- Ice/Cup
                Game.state.recipe.icePerCup = math.max(0, Game.state.recipe.icePerCup + ticks)
            end
        end
    end
end

function pd.update()
    if currentState == STATE_TITLE then
        UI.drawTitle()
        if pd.buttonJustPressed(pd.kButtonA) then
            Game.init()
            currentState = STATE_PREP
            selectionIndex = 1
        end
        
    elseif currentState == STATE_PREP then
        UI.drawPrep(Game.state, selectionIndex)
        handlePrepInput()
        
    elseif currentState == STATE_SIM then
        UI.drawSim(Game.state, simDisplayState)
        pd.timer.updateTimers()
        
    elseif currentState == STATE_RESULT then
        UI.drawResult(Game.state, lastResult)
        if pd.buttonJustPressed(pd.kButtonA) then
            if Game.state.money < 0 then
                currentState = STATE_GAMEOVER
            else
                currentState = STATE_PREP
                selectionIndex = 1
            end
        end
        
    elseif currentState == STATE_GAMEOVER then
        UI.drawGameOver(Game.state)
        if pd.buttonJustPressed(pd.kButtonA) then
            currentState = STATE_TITLE
        end
    end
end
