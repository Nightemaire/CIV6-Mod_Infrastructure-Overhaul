-- Tile Property Growth System
-- Author: Nightemaire
-- DateCreated: 6/20/2022 17:57:45
--------------------------------------------------------------
-- #region System Details
-- This system is intended to implement an efficient way of tracking properties that accumulate on tiles
-- with the intent of triggering events when they reach a specific threshold
--
--
-- #endregion

print("Loading tile growth system...")

Debug_Tile_Growth = false;

-- ===========================================================================
-- #region SYSTEM CORE
-- ===========================================================================

PropertyList = {};
-- #region PROPERTY LIST
-- The property list is a table that contains all properties registered by other functions.
-- These are not stored in the game properties because, as far as I can tell, you cannot store a function into a property, even if it's part of a table.
-- It may be possible to store the function name and look it up, but that seems unnecessarily clunky to me...also risky.
-- So to get around this, the property list is a table that gets initialized each game load. This makes it trickier to call different functions - but not impossible.
-- The best workaround I can think of is to have the growth calc function store a "CallbackMethodID" string, and have the callback function lookup the
-- function you actually want to call based on that.
-- #endregion
function GetPropertyList()
    --local List = Game:GetProperty("GrowthPropertyList")
    --if List == nil then List = {}; end
    return PropertyList
end
function NewGrowthProperty(ID : string, defaultThreshold : number, growthCalcFunc, defaultCallback, minVal, maxVal)
    DebugTileGrowth("// Creating growth property: "..ID)
    
    if growthCalcFunc == nil then
        growthCalcFunc = function()
            DebugTileGrowth(">> Growth function was nil")
            return 0;
        end
    end

    if growthCalcFunc ~= nil and defaultCallback ~= nil and ID ~= nil and defaultThreshold ~= nil then
        local PropertyList = GetPropertyList()

        if PropertyList[ID] == nil then
            PropertyList[ID] = {
                DefaultThreshold = defaultThreshold,
                GrowthCalcFunc = growthCalcFunc,
                DefaultCallback = defaultCallback,
                MinVal = minVal,
                MaxVal = maxVal
            }
        else
            print(">> Tried to add a property that already exists!")
        end

        --SetPropertyList(PropertyList)
        SetTurnTable(ID, {})
    else
        print("ERROR: Tried to create a new growth property but an arg was nil")
    end
end
function GetPropertyData(PropertyID)
    return GetPropertyList()[PropertyID]
end
function SetPropertyList(List)
    --Game:SetProperty("GrowthPropertyList", List)
	PropertyList = List;
end
function GetGrowthCalcFunc(PropertyID)
    return GetPropertyList()[PropertyID].GrowthCalcFunc
end
function GetCallbackFunc(PropertyID)
    return GetPropertyList()[PropertyID].DefaultCallback
end
function ChangeCallback(PropertyID : string, newCallback)
    if PropertyID ~= nil and newCallback ~= nil then
        PropertyList[PropertyID].DefaultCallback = newCallback
    end
end

-- #region TURN TABLES
-- Each property has an associated turn table. Basically this is a hash table, the key for each element corresponds to a turn number. Each element
-- is itself an array of key/val pairs, where the key is the plotID, and the value is irrelevant. The existance of the key is sufficient to represent the plot.
-- When the growth value of a plot property changes, the turn where it surpasses its threshold can be calculated, and this is used to update the appropriate
-- entry in the turn table, and the previous turn is used to remove that entry.
-- Each turn the game checks to see if there are any entries of plots that are scheduled to trigger, and checks to make sure they're ready before triggering them,
-- or recalculating the correct turn.
-- #endregion
function GetTurnTable(PropertyID : string) 
    return Game:GetProperty("GrowthTurnTable_"..PropertyID)
end
function SetTurnTable(PropertyID : string, TurnTable : table) 
    Game:SetProperty("GrowthTurnTable_"..PropertyID, TurnTable)
end
function UpdateTurnTable(PropertyID : string, plotID : number, newTurn, prevTurn : number)
    if PropertyID == nil or plotID == nil or prevTurn == nil then return; end

    local turnTable = GetTurnTable(PropertyID)
    
    if newTurn == nil then return; end

    if turnTable[prevTurn] ~= nil then
        turnTable[prevTurn][plotID] = nil
    end
    if turnTable[newTurn] == nil then turnTable[newTurn] = {}; end
    turnTable[newTurn][plotID] = true

    SetTurnTable(PropertyID, turnTable)
end

-- #region PLOT PROPERTY DATA
-- 
-- #endregion
local datadef = {
    Value           = 0,
    Growth 		    = 0,
    LastUpdate 	    = 0,
    Threshold       = 0,
    TriggersOn 	    = 0,
    Triggered       = false
}
function InitPlotPropertyData(PropertyID, pPlot)
    if pPlot ~= nil then
        local PropertyData = GetPropertyData(PropertyID)
        local GrowthCalc = GetGrowthCalcFunc(PropertyID)
        local plotID = pPlot:GetIndex()
        DebugTileGrowth("Initializing plot: "..plotID)
        DebugTileGrowth(">> PlotID = "..plotID)

        local growth = GrowthCalc(plotID)
        DebugTileGrowth(">> Growth = "..growth)

        local CurrentTurn = Game.GetCurrentGameTurn()

        local TriggerTurn = EstimateTriggerTurn(growth, 0, PropertyData.DefaultThreshold, CurrentTurn)
        DebugTileGrowth(">> Trigger = "..TriggerTurn)

        DebugTileGrowth(">> Threshold = "..PropertyData.DefaultThreshold)

        local newPlotData = {
            Value           = 0,
            Growth 		    = growth,
            LastUpdate 	    = CurrentTurn,
            Threshold       = PropertyData.DefaultThreshold,
            TriggersOn 	    = TriggerTurn,
            Triggered       = false
            --CallbackFunc    = PropertyData.DefaultCallback,
        };

        SetPlotPropertyData(PropertyID, pPlot, newPlotData)
        UpdateTurnTable(PropertyID, plotID, TriggerTurn)

        LuaEvents.OnPlotPropertyInitialized(PropertyID, plotID)
    end
end
function PlotIsInitialized(PropertyID, plotID)
    local pPlot = Map.GetPlotByIndex(plotID)
    local Entry = pPlot:GetProperty("GP_"..PropertyID.."_Value")
    return Entry ~= nil
end

-- Not totally sure I need these yet...
-- Write Accessors
function WriteValue(PropertyID, pPlot, value)               pPlot:SetProperty("GP_"..PropertyID.."_Value", value);              end
function WriteGrowth(PropertyID, pPlot, growth)             pPlot:SetProperty("GP_"..PropertyID.."_Growth", growth);            end
function WriteLastUpdate(PropertyID, pPlot, update)         pPlot:SetProperty("GP_"..PropertyID.."_LastUpdate", update);        end
function WriteThreshold(PropertyID, pPlot, threshold)       pPlot:SetProperty("GP_"..PropertyID.."_Threshold", threshold);      end
function WriteTriggered(PropertyID, pPlot, triggered)       pPlot:SetProperty("GP_"..PropertyID.."_Triggered", triggered);      end
function WriteTriggerTurn(PropertyID, pPlot, newTriggerTurn)
    local previousTurn = ReadTriggerTurn(PropertyID, pPlot)
    if newTriggerTurn <= Game.GetCurrentGameTurn() then newTriggerTurn = Game.GetCurrentGameTurn() + 1; end
    pPlot:SetProperty("GP_"..PropertyID.."_TriggersOn", newTriggerTurn)
    UpdateTurnTable(PropertyID, pPlot:GetIndex(), newTriggerTurn, previousTurn)
end
-- Read Accessors
function ReadValue(PropertyID, pPlot)        if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_Value");         else return 0;     end; end
function ReadGrowth(PropertyID, pPlot)       if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_Growth");        else return 0;     end; end
function ReadLastUpdate(PropertyID, pPlot)   if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_LastUpdate");    else return 0;     end; end
function ReadThreshold(PropertyID, pPlot)    if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_Threshold");     else return 0;     end; end
function ReadTriggerTurn(PropertyID, pPlot)  if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_TriggersOn");    else return 0;     end; end
function ReadTriggered(PropertyID, pPlot)    if pPlot ~= nil then return pPlot:GetProperty("GP_"..PropertyID.."_Triggered");     else return false; end; end
--]]

function GetPlotPropertyData(PropertyID, pPlot)
    local thisPlot = nil
    if type(pPlot) == "number" then
        thisPlot = Map.GetPlotByIndex(pPlot);
    elseif type(pPlot) == "table" then
        thisPlot = pPlot;
    end

    local data = {};
    if thisPlot ~= nil then
        if thisPlot:GetProperty("GP_"..PropertyID.."_Value") == nil then
            InitPlotPropertyData(PropertyID, thisPlot);
        end
        for k,_ in pairs(datadef) do
            val = thisPlot:GetProperty("GP_"..PropertyID.."_"..k)
            if val ~= nil then data[k] = val; end
        end
        --local data = thisPlot:GetProperty("GP_"..PropertyID);

        return data;
    end

    return nil
end
function SetPlotPropertyData(PropertyID, pPlot, data)
    if pPlot ~= nil and data ~= nil and type(pPlot) == "table" and type(data) == "table" then
        for k,v in pairs(data) do
            pPlot:SetProperty("GP_"..PropertyID.."_"..k, v)
        end
        --pPlot:SetProperty("GP_"..PropertyID, data)
    end
end
function GetPlotPropertyDataOnly(PropertyID, plotID)
    thisPlot = Map.GetPlotByIndex(plotID);

    local data = {};
    if thisPlot ~= nil then
        if thisPlot:GetProperty("GP_"..PropertyID.."_Value") == nil then return nil; end

        for k,_ in pairs(datadef) do
            val = thisPlot:GetProperty("GP_"..PropertyID.."_"..k)
            if val ~= nil then data[k] = val; end
        end
        
        return data;
    end

    return nil
end
function UI_GetData(PropertyID, pPlot)
    if pPlot ~= nil then
        local val = ReadValue(PropertyID, pPlot)
        if val ~= nil then
            local growth = ReadGrowth(PropertyID, pPlot)
            local updated = ReadLastUpdate(PropertyID, pPlot)
            local triggerTurn = ReadTriggerTurn(PropertyID, pPlot)
            local CurrentTurn = Game.GetCurrentGameTurn()
            local newVal = val + ( (CurrentTurn - updated) * growth)
            local thold = ReadThreshold(PropertyID, pPlot)

            return {newVal, growth, thold, triggerTurn}
        end
    end

    return {0,0,0,0}
end

-- Property modifiers
function SetGrowth(PropertyID : string, plotID : number, newGrowth : number)
    if PropertyID ~= nil and plotID ~= nil and newGrowth ~= nil then
        DebugTileGrowth("Setting Tile Growth: "..PropertyID..", "..plotID..", "..newGrowth);
        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end

        UpdatePlotProperties(PropertyID, pPlot)

        local CurrentValue = ReadValue(PropertyID, pPlot)
        local Threshold = ReadThreshold(PropertyID, pPlot)
        
        WriteTriggerTurn(PropertyID, pPlot, EstimateTriggerTurn(newGrowth, CurrentValue, Threshold))
    else
        DebugTileGrowth("Tried to set growth, but an arg was nil");
    end
end
function ChangeGrowth(PropertyID : string, plotID : number, adjustment : number)
    if PropertyID ~= nil and plotID ~= nil and adjustment ~= nil then
        DebugTileGrowth("Adjusting Tile Growth: "..PropertyID..", "..plotID..", "..adjustment);
        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end

        UpdatePlotProperties(PropertyID, pPlot)

        local CurrentValue = ReadValue(PropertyID, pPlot)
        local CurrentGrowth = ReadGrowth(PropertyID, pPlot)
        local Threshold = ReadThreshold(PropertyID, pPlot)

        local newGrowth = CurrentGrowth + adjustment;
        
        WriteTriggerTurn(PropertyID, pPlot, EstimateTriggerTurn(newGrowth, CurrentValue, Threshold))
    else
        DebugTileGrowth("Tried to adjust growth, but an arg was nil");
    end
end
function ChangeThreshold(PropertyID : string, plotID : number, newThreshold : number)
    if PropertyID ~= nil and plotID ~= nil and newThreshold ~= nil then
        DebugTileGrowth("Setting New Threshold: "..PropertyID..", "..plotID..", "..newThreshold);
        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end

        UpdatePlotProperties(PropertyID, pPlot)
        
        local CurrentValue = ReadValue(PropertyID, pPlot)
        local CurrentGrowth = ReadGrowth(PropertyID, pPlot)
        local NewTurn = EstimateTriggerTurn(CurrentGrowth, CurrentValue, newThreshold)
        
        WriteThreshold(PropertyID, pPlot, newThreshold)
        WriteTriggerTurn(PropertyID, pPlot, NewTurn)
    else
        DebugTileGrowth("Tried to adjust threshold, but an arg was nil");
    end
end
function SetValue(PropertyID : string, plotID : number, newValue)
    if PropertyID ~= nil and plotID ~= nil and newValue ~= nil then

        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end
        
        local CurrentGrowth = ReadGrowth(PropertyID, pPlot)
        local Threshold = ReadThreshold(PropertyID, pPlot)

        WriteTriggerTurn(PropertyID, pPlot, EstimateTriggerTurn(CurrentGrowth, newValue, Threshold))
    end
end

-- Trigger Management
function SnoozeTrigger(PropertyID : string, plotID : number, delay)
    local pPlot = Map.GetPlotByIndex(plotID)
    if pPlot == nil then return; end

    UpdatePlotProperties(PropertyID, pPlot)

    local currentTriggerTurn = ReadTriggerTurn(PropertyID, pPlot)
    local currentGameTurn = Game.GetCurrentGameTurn()
    local newTurn = currentTriggerTurn + delay;
    if newTurn <= currentGameTurn then newTurn = currentGameTurn + 1; end

    WriteTriggerTurn(PropertyID, pPlot, newTurn)

    print("Snoozing plot: "..plotID..", from "..currentTriggerTurn.." to "..newTurn)
end
function ClearTrigger(PropertyID, plotID)
    if PropertyID ~= nil and plotID ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end

        WriteTriggered(PropertyID, pPlot, false)
        
        UpdatePlotProperties(PropertyID, Entry)
    end
end
function SetTrigger(PropertyID, plotID)
    if PropertyID ~= nil and plotID ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        if pPlot == nil then return; end
        
        WriteTriggered(PropertyID, pPlot, true)
    end
end

-- Entry Utiltiies/Calculations
function UpdatePlotProperties(PropertyID, pPlot : object)
    if pPlot ~= nil then
        local PropertyData = PropertyList[PropertyID]
        local CurrentTurn = Game.GetCurrentGameTurn()

        local LastUpdated = ReadLastUpdate(PropertyID, pPlot)
        if LastUpdated == nil then return; end

        local CurrentValue = ReadValue(PropertyID, pPlot)

        -- Check to see if we've updated this turn already
        if LastUpdated ~= CurrentTurn then
            local CurrentGrowth = ReadGrowth(PropertyID, pPlot)
            -- Update the value to be current
            local NewValue = CurrentValue + ( (CurrentTurn - LastUpdated) * CurrentGrowth)
            if NewValue < PropertyData.MinVal then NewValue = PropertyData.MinVal; end
            if NewValue > PropertyData.MaxVal then NewValue = PropertyData.MaxVal; end
            
            WriteValue(PropertyID, pPlot, NewValue)
            CurrentValue = NewValue
            WriteLastUpdate(PropertyID, pPlot, CurrentTurn)
        end
        
        local Threshold = ReadThreshold(PropertyID, pPlot)
        local Triggered = CurrentValue >= Threshold
        
        return Triggered;
    end
end
function GetEntry(PropertyID, plot)
    local pPlot = nil
    if type(plot) == "number" then
        pPlot = Map.GetPlotByIndex(plot)
    elseif type(plot) == "table" then
        pPlot = plot
    end
    local entry = pPlot:GetPlotPropertyData(PropertyID, pPlot)
    
    return pPlot, entry
end
function EstimateTriggerTurn(Growth : number, Value : number, Threshold : number)
    local triggerTurn = math.huge
    local CurrentTurn = Game.GetCurrentGameTurn()
    if Growth > 0 then
        -- Get the difference between the trigger threshold and the current value
        local diff = Threshold - Value
        -- Number of turns is the diff divided by the growth rounded up
        local turns = math.ceil(diff / Growth)

        -- We never want to set a trigger to be less than or equal to the current turn, because then it would never trigger
        if turns <= 0 then
            triggerTurn = CurrentTurn + 1;
        else
        -- And so the expected improvement turn is the number of turns plus the current turn
            triggerTurn = CurrentTurn + turns
        end
    end

    return triggerTurn
end

-- #endregion

-- ===========================================================================
-- #region DEBUGGING
-- ===========================================================================

function DebugTileGrowth(msg)
    if Debug_Tile_Growth then print(msg); end
end

-- #endregion

-- ===========================================================================
-- #region GAMEPLAY
-- ===========================================================================

function OnGameTurnStarted()
    for p,_ in pairs(GetPropertyList()) do
        CheckTurnTable(p, Game.GetCurrentGameTurn())
    end
end
GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted)

function CheckTurnTable(PropertyID : string, Turn : number)
    local TurnTable = GetTurnTable(PropertyID)

    local PlotsToTrigger = {}

    if TurnTable ~= nil and Turn ~= nil then
        local TurnData = TurnTable[Turn]

        -- Check if there are plot entries for this turn
        if TurnData ~= nil then
            -- Clear the entry from the table
            TurnTable[Turn] = nil

            -- Iterate over the keys of TurnData (which are the plot IDs scheduled to trigger this turn)
            for plotID,_ in pairs(TurnData) do
                local ThisPlot = Map.GetPlotByIndex(plotID)
                if ThisPlot ~= nil then
                    local Triggered = UpdatePlotProperties(PropertyID, ThisPlot)

                    -- If this plot triggered, attempt to invoke the callback function if it exists
                    if Triggered and not(ReadTriggered(PropertyID, thisPlot)) then
                        table.insert(PlotsToTrigger, {PropertyID, plotID})
                    end
                end
            end
            
            -- Make sure to update the turn table at the end
            SetTurnTable(PropertyID, TurnTable)
        end
    end

    -- We trigger outside the checking loop so that if needed, the triggers can update the turn table without it getting overwritten
    for k,trigger in pairs(PlotsToTrigger) do
        PlotTrigger(trigger[1], trigger[2])
    end

end

function UpdatePlot(PropertyID : string, plotID : number)
    if PropertyID ~= nil and plotID ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)

		if not(PlotIsInitialized(PropertyID, plotID)) then
			InitPlotPropertyData(PropertyID, pPlot)
		end

        GrowthCalc = GetGrowthCalcFunc(PropertyID)
        newGrowth = GrowthCalc(plotID)
        UpdatePlotProperties(PropertyID, pPlot)
    end
end

function PlotTrigger(PropertyID, plotID)
    --print("Plot growth triggered: "..PropertyID..", "..plotID)
    local CallbackFunc = GetCallbackFunc(PropertyID)
    if CallbackFunc ~= nil and type(CallbackFunc) == "function" then
        CallbackFunc(plotID)
    else
        print("ERROR: Invalid callback function")
    end

    SetTrigger(PropertyID, plotID)
end

-- #endregion

-- ===========================================================================
-- #region UTILITY
-- ===========================================================================

function notNilOrNegative(val)
	if val == nil then return false; end
	if val < 0 then return false; end

	return true
end

-- #endregion

-- ===========================================================================
-- #region EXPOSED MEMBERS
-- ===========================================================================

TileGrowth = {}

TileGrowth.NewGrowthProperty = NewGrowthProperty
TileGrowth.GetPropertyList = GetPropertyList
TileGrowth.GetPropertyData = GetPropertyData
TileGrowth.GetGrowthCalcFunc = GetGrowthCalcFunc

TileGrowth.GetPlotPropertyData = GetPlotPropertyData
TileGrowth.GetPlotPropertyDataOnly = GetPlotPropertyDataOnly
TileGrowth.SetGrowth = SetGrowth
TileGrowth.ChangeGrowth = ChangeGrowth
TileGrowth.ChangeThreshold = ChangeThreshold
TileGrowth.ChangeCallback = ChangeCallback
TileGrowth.SetValue = SetValue

TileGrowth.UpdatePlot = UpdatePlot

TileGrowth.UI_GetData = UI_GetData

ExposedMembers.TileGrowth = TileGrowth

-- #endregion

-- ===========================================================================
-- #region TEST
-- ===========================================================================

local enableTest = false

function Test1GrowthCalc(plotID)
    return Map.GetPlotByIndex(plotID):GetAppeal()
end

function OnTest1Trigger(plotID)
    print("Property Test 1 Triggered on plot: "..plotID)
end

if enableTest then
    NewGrowthProperty("Test1", 10, Test1GrowthCalc, OnTest1Trigger)

    

    Events.CityAddedToMap.Add(function (playerID, cityID, X, Y)
        local city = CityManager.GetCity(Players[playerID], cityID)
        local plots = city:GetOwnedPlots()
        local cityPlot = Map.GetPlot(X, Y)
        local cityPlotIndex = cityPlot:GetIndex()

        for k,plot in ipairs(city:GetOwnedPlots()) do
            local plotIndex = plot:GetIndex()
            if plotIndex ~= cityPlotIndex then
                InitPlotPropertyData("Test1", plot)
            end
        end
    end)
end

-- #endregion

print("Tile growth loaded!")