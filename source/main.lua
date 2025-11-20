import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = pd.graphics

local uiState = {
    selectedAction = 1,
    phase = "planning", -- planning | selling | results
    news = {},
    lastSummary = {},
}

local world = {
    day = 1,
    cash = 120,
    price = 1.5,
    recipe = 0.6, -- 0..1 controls sweetness/strength
    marketing = 0,
    reputation = 0.45,
    morale = 0.75,
    inventory = { cups = 20, lemons = 18, sugar = 18 },
    forecast = "Sunny",
}

local costs <const> = { cups = 0.25, lemons = 0.35, sugar = 0.2 }
local actions <const> = {
    { id = "price", label = "Cup Price", min = 0.5, max = 4, step = 0.1 },
    { id = "recipe", label = "Recipe Balance", min = 0.1, max = 1, step = 0.05 },
    { id = "marketing", label = "Marketing Spend", min = 0, max = 25, step = 1 },
    { id = "cups", label = "Buy Cups", min = 0, max = 200, step = 1 },
    { id = "lemons", label = "Buy Lemons", min = 0, max = 120, step = 1 },
    { id = "sugar", label = "Buy Sugar", min = 0, max = 120, step = 1 },
}

local weatherModifiers <const> = {
    Sunny = { demand = 1.1, morale = 0.05 },
    Cloudy = { demand = 0.95, morale = -0.02 },
    Rainy = { demand = 0.65, morale = -0.05 },
    Hot = { demand = 1.25, morale = 0.08 },
}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function pushNews(message)
    table.insert(uiState.news, 1, message)
    if #uiState.news > 6 then
        table.remove(uiState.news)
    end
end

local function nextForecast()
    local pool = { "Sunny", "Cloudy", "Rainy", "Hot" }
    world.forecast = pool[math.random(#pool)]
end

local function drawHeader()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 26)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFontTracking(1)
    gfx.drawText("Lemonade Atelier", 10, 5)
    gfx.drawTextRightAligned(string.format("Day %d", world.day), 390, 5)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function drawMeters()
    local y = 36
    local function meter(label, value, maxValue)
        local width = 160
        gfx.drawText(label, 12, y)
        gfx.drawRoundRect(10, y + 12, width, 10, 3)
        local filledWidth = width * clamp(value / maxValue, 0, 1)
        gfx.fillRoundRect(10, y + 12, filledWidth, 10, 3)
        y = y + 28
    end
    meter("Cash", world.cash, 400)
    meter("Reputation", world.reputation, 1)
    meter("Morale", world.morale, 1)
end

local function drawForecast()
    gfx.drawText("Forecast", 216, 36)
    gfx.drawRoundRect(214, 50, 176, 36, 5)
    gfx.drawTextInRect(world.forecast .. " skies", 220, 56, 166, 28, nil, "...")
end

local function drawInventory()
    local y = 96
    gfx.drawText("Inventory", 216, y)
    y = y + 14
    for _, key in ipairs({ "cups", "lemons", "sugar" }) do
        local label = key:sub(1, 1):upper() .. key:sub(2)
        gfx.drawText(string.format("%s: %d", label, world.inventory[key]), 222, y)
        y = y + 16
    end
end

local function drawNews()
    local y = 170
    gfx.drawText("City Buzz", 216, y)
    y = y + 12
    gfx.drawRoundRect(214, y, 176, 110, 6)
    local textY = y + 6
    for i = 1, math.min(6, #uiState.news) do
        gfx.drawText(uiState.news[i], 220, textY)
        textY = textY + 18
    end
end

local function drawActions()
    local y = 176
    for index, action in ipairs(actions) do
        local isSelected = uiState.selectedAction == index
        local label = action.label
        local value

        if action.id == "price" then
            value = string.format("$%.2f", world.price)
        elseif action.id == "recipe" then
            value = string.format("%.0f%% tart", world.recipe * 100)
        elseif action.id == "marketing" then
            value = string.format("$%d", math.floor(world.marketing))
        elseif action.id == "cups" then
            value = string.format("%d (%.2f ea)", world.inventory.cups, costs.cups)
        elseif action.id == "lemons" then
            value = string.format("%d (%.2f ea)", world.inventory.lemons, costs.lemons)
        elseif action.id == "sugar" then
            value = string.format("%d (%.2f ea)", world.inventory.sugar, costs.sugar)
        end

        if isSelected then
            gfx.fillRoundRect(10, y - 4, 192, 26, 6)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.drawRoundRect(10, y - 4, 192, 26, 6)
        end
        gfx.drawText(label, 16, y)
        gfx.drawTextRightAligned(value or "", 194, y)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        y = y + 30
    end

    local hint = "↑↓ select  ←→ tune   A:Open stand"
    if uiState.phase == "selling" then
        hint = "Selling..."
    elseif uiState.phase == "results" then
        hint = "A:Next day  B:Adjust"
    end
    gfx.drawText(hint, 12, 280)
end

local function applyPurchase(resource, delta)
    local cost = costs[resource] * delta
    if delta > 0 then
        if world.cash >= cost then
            world.cash = world.cash - cost
            world.inventory[resource] = world.inventory[resource] + delta
            pushNews(string.format("Bought %d %s", delta, resource))
        else
            pushNews("Not enough cash for that order")
        end
    elseif delta < 0 then
        local actual = math.min(-delta, world.inventory[resource])
        local refund = costs[resource] * actual * 0.5
        world.inventory[resource] = world.inventory[resource] - actual
        world.cash = world.cash + refund
        pushNews(string.format("Sold %d %s back (%.2f)", actual, resource, refund))
    end
end

local function adjustAction(action, direction)
    if action.id == "price" then
        world.price = clamp(world.price + action.step * direction, action.min, action.max)
    elseif action.id == "recipe" then
        world.recipe = clamp(world.recipe + action.step * direction, action.min, action.max)
    elseif action.id == "marketing" then
        world.marketing = clamp(world.marketing + action.step * direction, action.min, action.max)
    else
        applyPurchase(action.id, direction * action.step)
    end
end

local function satisfactionModifier()
    local ideal = 0.55
    local distance = math.abs(world.recipe - ideal)
    local mod = clamp(1 - distance * 1.3, 0.6, 1.2)
    return mod
end

local function simulateDay()
    local weather = weatherModifiers[world.forecast]
    local baseDemand = 40 + math.random(0, 35)
    local marketingBonus = world.marketing * 0.9
    local priceImpact = clamp(1.6 - world.price * 0.35, 0.3, 1.4)
    local reputationImpact = 0.6 + world.reputation * 0.8
    local moraleImpact = 0.5 + world.morale * 0.6
    local sweetnessImpact = satisfactionModifier()

    local demand = baseDemand * weather.demand * priceImpact * reputationImpact * moraleImpact * sweetnessImpact
    demand = demand + marketingBonus
    demand = math.floor(demand)

    local cupsPossible = math.min(world.inventory.cups, world.inventory.lemons, world.inventory.sugar)
    local customers = math.min(demand, cupsPossible)

    local costPerCup = (costs.cups + costs.lemons + costs.sugar) * 1.05
    local revenue = customers * world.price
    local costsToday = customers * costPerCup + world.marketing
    local profit = revenue - costsToday

    world.inventory.cups = world.inventory.cups - customers
    world.inventory.lemons = world.inventory.lemons - customers
    world.inventory.sugar = world.inventory.sugar - customers
    world.cash = world.cash + profit

    local satisfaction = clamp(sweetnessImpact * weather.demand * 0.8, 0, 1)
    world.reputation = clamp(world.reputation + (customers / 120) * (satisfaction - 0.5), 0, 1)
    world.morale = clamp(world.morale + (profit >= 0 and 0.04 or -0.08), 0, 1)

    uiState.lastSummary = {
        customers = customers,
        demand = demand,
        revenue = revenue,
        costsToday = costsToday,
        profit = profit,
        costPerCup = costPerCup,
        satisfaction = satisfaction,
    }

    pushNews(string.format("Sold %d/%d cups @ $%.2f", customers, demand, world.price))
    pushNews(string.format("Profit %s$%.2f", profit >= 0 and "+" or "-", math.abs(profit)))
end

local function drawResults()
    local summary = uiState.lastSummary
    local y = 120
    gfx.drawText("Day Results", 12, 96)
    gfx.drawRoundRect(10, 116, 192, 90, 6)
    gfx.drawText(string.format("Customers: %d (demand %d)", summary.customers, summary.demand), 16, y)
    gfx.drawText(string.format("Revenue: $%.2f", summary.revenue), 16, y + 18)
    gfx.drawText(string.format("Costs: $%.2f", summary.costsToday), 16, y + 36)
    gfx.drawText(string.format("Profit: $%.2f", summary.profit), 16, y + 54)
    gfx.drawText(string.format("Recipe appeal: %.0f%%", summary.satisfaction * 100), 16, y + 72)
end

local function startSelling()
    uiState.phase = "selling"
    simulateDay()
    uiState.phase = "results"
    world.day = world.day + 1
    nextForecast()
end

local function updatePlanningInputs()
    if pd.buttonJustPressed(pd.kButtonUp) then
        uiState.selectedAction = clamp(uiState.selectedAction - 1, 1, #actions)
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        uiState.selectedAction = clamp(uiState.selectedAction + 1, 1, #actions)
    end

    local direction = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then direction = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then direction = 1 end
    if direction ~= 0 then
        adjustAction(actions[uiState.selectedAction], direction)
    end

    if pd.buttonJustPressed(pd.kButtonA) then
        startSelling()
    end
end

local function updateResultsInputs()
    if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
        uiState.phase = "planning"
    end
end

function pd.update()
    gfx.clear(gfx.kColorWhite)
    drawHeader()
    drawMeters()
    drawForecast()
    drawInventory()
    drawNews()

    if uiState.phase == "planning" then
        drawActions()
        updatePlanningInputs()
    elseif uiState.phase == "selling" then
        drawActions()
    elseif uiState.phase == "results" then
        drawActions()
        drawResults()
        updateResultsInputs()
    end

    pd.timer.updateTimers()
end

pushNews("Morning deliveries arrive")
nextForecast()
