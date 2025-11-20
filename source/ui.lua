local pd <const> = playdate
local gfx <const> = pd.graphics

UI = {}

-- Fonts
local fontBold = gfx.font.new('font/kRoobert10Bold') -- Assuming default system font if not found, but usually need to load. 
-- Actually, let's use the system default for now to avoid path issues if I don't have the font file in the right place.
-- Playdate has built-in fonts accessible via system.

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
    
    for i, item in ipairs(items) do
        local y = yStart + (i-1)*lineHeight
        
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
