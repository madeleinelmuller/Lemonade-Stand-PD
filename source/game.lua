local pd <const> = playdate
Game = {}

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
