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

-- ===========================================================================
-- #region ACCESS
-- ===========================================================================

-- Property list accessors
function GetPropertyList()
    local List = Game:GetProperty("GrowthPropertyList")
    if List == nil then List = {}; end
    return List
end
function SetPropertyList(List)
    Game:SetProperty("GrowthPropertyList", List)
end

-- Turn table accessors
function GetTurnTable(PropertyID : string) 
    return Game:GetProperty("GrowthTurnTable_"..PropertyID)
end
function SetTurnTable(PropertyID : string, TurnTable : table) 
    Game:SetProperty("GrowthTurnTable_"..PropertyID, TurnTable)
end

-- Property data accessors
function GetPlotPropertyData(PropertyID : string, pPlot : object) 
    return pPlot:GetProperty("GP_"..PropertyID)
end
function SetPlotPropertyData(PropertyID : string, pPlot : object, data : table) 
    pPlot:SetProperty("GP_"..PropertyID, data)
end

-- Property modifiers
function ChangeGrowth(PropertyID : string, plotID : number, newGrowth : number)
    if PropertyID ~= nil and plotID ~= nil and newGrowth ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        local Entry = GetPlotPropertyData(PropertyID, pPlot)
        Entry, triggered = UpdatePropertyEntry(Entry, true, newGrowth)
        SetPlotPropertyData(PropertyID, pPlot, Entry)
    end
end
function ChangeThreshold(PropertyID : string, plotID : number, newThreshold : number)
    if PropertyID ~= nil and plotID ~= nil and newThreshold ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        local Entry = GetPlotPropertyData(PropertyID, pPlot)
        Entry.Threshold = newThreshold
        Entry, triggered = UpdatePropertyEntry(Entry, true)
        SetPlotPropertyData(PropertyID, pPlot, Entry)
    end
end
function ChangeCallback(PropertyID : string, plotID : number, newCallback : function)
    if PropertyID ~= nil and plotID ~= nil and newCallback ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        local Entry = GetPlotPropertyData(PropertyID, pPlot)
        Entry.CallbackFunc = newCallback
        SetPlotPropertyData(PropertyID, pPlot, Entry)
    end
end
function SetValue(PropertyID : string, plotID : number, newValue : function)
    if PropertyID ~= nil and plotID ~= nil and newValue ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)
        local Entry = GetPlotPropertyData(PropertyID, pPlot)
        Entry.Value = newValue
        Entry.LastUpdate = Game.GetCurrentGameTurn()
        CheckTrigger(Entry, true)
        SetPlotPropertyData(PropertyID, pPlot, Entry)
    end
end

-- #endregion

-- ===========================================================================
-- #region INITIALIZATION
-- ===========================================================================

function NewGrowthProperty(ID : string, defaultThreshold : number, growthCalcFunc : function, defaultCallback : function)
    if growthCalcFunc == nil then
        growthCalcFunc = function(plotID)
            return 0;
        end
    end

    if growthCalcFunc ~= nil and defaultCallback ~= nil and ID ~= nil and defaultThreshold ~= nil then
        local PropertyList = GetPropertyList()

        if PropertyList[ID] == nil then
            PropertyList[ID] = {
                DefaultThreshold = defaultThreshold,
                GrowthCalcFunc = growthCalcFunc,
                DefaultCallback = defaultCallback
            }
        else
            print("Tried to add a property that already exists!")
        end

        SetPropertyList(PropertyList)
        SetTurnTable(ID, {})
    else
        print("ERROR: Tried to create a new growth property but an arg was nil")
    end
end

function InitPlotPropertyData(PropertyID : string, plotID : number )
    if plotID ~= nil then
        local pPlot = Map.GetPlotByIndex(plotID)

        local PropertyData = GetPropertyList()
        
        local Growth = PropertyData.GrowthCalcFunc(plotID)
        local TriggerTurn = EstimateTriggerTurn(Growth, 0, PropertyData.DefaultThreshold, Game.GetCurrentGameTurn())

        local newPlotData = {
            Value           = 0,
            Growth 		    = Growth,
            LastUpdate 	    = Game.GetCurrentGameTurn(),
            Threshold       = PropertyData.DefaultThreshold,
            TriggersOn 	    = TriggerTurn,
            CallbackFunc    = PropertyData.DefaultCallback,
        };


        local turnTable = GetTurnTable(PropertyID)

        SetPlotPropertyData(PropertyID, pPlot, newPlotData)
        turnTable[TriggerTurn][plotID] = true

        SetTurnTable(PropertyID, turnTable)
    end
end

-- #endregion

-- ===========================================================================
-- #region GAMEPLAY
-- ===========================================================================

function OnGameTurnStarted()
	local currentGameTurn = Game.GetCurrentGameTurn()

    for p,_ in pairs(GetPropertyList()) do
        CheckTurnTable(p, currentGameTurn)
    end
end
GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted);

function CheckTurnTable(PropertyID : string, Turn : number)
    local TurnTable = GetTurnTable(PropertyID)

    if TurnTable ~= nil and Turn ~= nil then
        local TurnData = TurnTable[Turn]

        -- Check if there are plot entries for this turn
        if TurnData ~= nil then
            -- Clear the entry from the table
            TurnTable[Turn] = nil

            -- Iterate over the keys of TurnData (which are the plot IDs scheduled to trigger this turn)
            for plotID,_ in pairs(TurnData) do
                local ThisPlot = Map.GetPlotByIndex(plotID)
                local PlotEntry = GetPlotPropertyData(PropertyID, ThisPlot)
                PlotEntry, Triggered = UpdatePlotPropertyEntry(PlotEntry)
                SetPlotPropertyData(PropertyID, ThisPlot, PlotEntry)

                -- If this plot triggered, attempt to invoke the callback function if it exists
                if Triggered then
                    if PlotEntry.CallbackFunc ~= nil and type(PlotEntry.CallbackFunc) == "function" then
                        PlotEntry.Callback(plotID)
                    else
                        print("ERROR: Invalid callback function")
                    end
                end
            end
            
            -- Make sure to update the turn table at the end
            SetTurnTable(PropertyID, TurnTable)
        end
    end
end

function UpdatePropertyEntry(PlotEntry : table, newGrowth : number)
    if PlotEntry ~= nil then
        local CurrentTurn = Game.GetCurrentGameTurn()
        local Triggered = false

        -- Check to see if we've updated this turn already
        if PlotEntry.LastUpdate ~= CurrentTurn then
            -- Update the value to be current
            PlotEntry.Value = PlotEntry.Value + ( (CurrentTurn - PlotEntry.LastUpdate) * PlotEntry.Growth)
            PlotEntry.LastUpdate = CurrentTurn
        end
        
        Triggered = CheckTrigger(PlotEntry)

        -- Modify the growth after checking for triggers
        if newGrowth ~= nil then
            PlotEntry.Growth = newGrowth
        end

        if not(Triggered) then
            -- If this plot hasn't triggered, then calculate the estimated trigger turn
            PlotEntry.TriggersOn = EstimateTriggerTurn(PlotEntry.Growth, PlotEntry.Value, PlotEntry.Threshold, CurrentTurn)
        end

        return PlotEntry, Triggered
    else
        return PlotEntry, false
    end
end

function EstimateTriggerTurn(Growth : number, Value : number, Threshold : number, CurrentTurn : number)
    local triggerTurn = math.huge
    if Growth > 0 then
        -- Get the difference between the trigger threshold and the current value
        local diff = Threshold - Value
        -- Number of turns is the diff divided by the growth rounded up
        local turns = math.ceil(diff / Growth)
        -- And so the expected improvement turn is the number of turns plus the current turn
        triggerTurn = CurrentTurn + turns
    end

    return triggerTurn
end

function CheckTrigger(PlotEntry : table)
    if PlotEntry == nil then return false; end

    return PlotEntry.Value >= PlotEntry.Threshold
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
-- #region TEST
-- ===========================================================================

local enableTest = true

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
                InitPlotPropertyData("Test1", plotIndex)
            end
        end
    end)
end

-- #endregion