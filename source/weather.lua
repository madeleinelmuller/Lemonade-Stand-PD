local pd <const> = playdate
local gfx <const> = pd.graphics

Weather = {}

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
