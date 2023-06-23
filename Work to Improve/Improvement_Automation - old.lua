-- AutoImprovements
-- Author: Nightemaire
-- DateCreated: 6/20/2022 17:57:45
--------------------------------------------------------------
-- #region TODO LIST:
-- - 
--
-- IDEA LIST:
--	- Settings for what can be auto-improved (Luxury, strategic, bonus, forest, hills)
--	-	- Maybe let cities prioritize different things?
--	- Slash utilization on pillage
--	- Slash utilization if improvement is removed
--  - Make configuration exposed somewhere
-- #endregion --------------------------------------------------

-- ===========================================================================
-- #region INCLUDES
-- ===========================================================================
print("IMPROVING IMPROVEMENTS!!! 062223");

include("SupportFunctions.lua");
include("TileGrowthSystem.lua");
include("AutoImprovements_Config.lua");

-- #endregion

-- ===========================================================================
-- #region STATIC DEFINITIONS
-- ===========================================================================
local GameSpeedType = GameConfiguration.GetGameSpeedType()
local SpeedMultiplier = GameInfo.GameSpeeds[GameSpeedType].CostMultiplier;
local TurnMultiplier = math.floor(GameInfo.GameSpeeds[GameSpeedType].CostMultiplier / 50)

local NO_TEAM = -1;

-- Features
local iForest = GameInfo.Features["FEATURE_FOREST"].Index
local iJungle = GameInfo.Features["FEATURE_JUNGLE"].Index
local iMarsh = GameInfo.Features["FEATURE_MARSH"].Index
local iFloodplains = GameInfo.Features["FEATURE_FLOODPLAINS"].Index
-- Improvements
local iFarm : number = GameInfo.Improvements["IMPROVEMENT_FARM"].Index
local iLumberMill : number = GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"].Index
local iPasture : number = GameInfo.Improvements["IMPROVEMENT_PASTURE"].Index
local iFishery : number = GameInfo.Improvements["IMPROVEMENT_FISHERY"].Index
local iMine : number = GameInfo.Improvements["IMPROVEMENT_MINE"].Index
-- Governors
local m_eGovernorLiang : number = GameInfo.Governors["GOVERNOR_THE_BUILDER"].Index
local m_eAquaculturePromotion : number = GameInfo.GovernorPromotions["GOVERNOR_PROMOTION_AQUACULTURE"].Index
-- Units
local m_eWarrior : number = GameInfo.Units["UNIT_WARRIOR"].Index
local m_eTrader : number = GameInfo.Units["UNIT_TRADER"].Index

-- Route Types
local i_AncientRoad = GameInfo.Routes["ROUTE_ANCIENT_ROAD"].Index;
local i_MedievalRoad = GameInfo.Routes["ROUTE_MEDIEVAL_ROAD"].Index;
local i_IndustrialRoad = GameInfo.Routes["ROUTE_INDUSTRIAL_ROAD"].Index;
local i_ModernRoad = GameInfo.Routes["ROUTE_MODERN_ROAD"].Index;
local i_Railroad = GameInfo.Routes["ROUTE_RAILROAD"].Index;

-- Eras
local i_MedievalEra = GameInfo.Eras["ERA_MEDIEVAL"].Index;
local i_IndustrialEra = GameInfo.Eras["ERA_MEDIEVAL"].Index;
local i_Modern = GameInfo.Eras["ERA_MODERN"].Index;

-- Build Valid Resource Improvement Table
local ImprovementLUT = {}
local NValids = #(GameInfo.Improvement_ValidResources);
for i = 0, NValids-1 do
	local improvementType = GameInfo.Improvement_ValidResources[i].ImprovementType
	local resourceType = GameInfo.Improvement_ValidResources[i].ResourceType
    --print(i..": "..improvementType.." on "..resourceType);
	ImprovementLUT[GameInfo.Resources[resourceType].Index] = GameInfo.Improvements[improvementType].Index;
end

local g_iW, g_iH = Map.GetGridSize();

-- #endregion

-- ===========================================================================
-- #region PARAMETERS
-- ===========================================================================

local DevelopmentWorked = Development_Bonus_If_Worked	-- FROM CONFIG
local AllowAppealReduction = Allow_Appeal_Reduction		-- FROM CONFIG
local Threshold = AutoImproveThreshold					-- FROM CONFIG

DevelopmentMax = Threshold * 1.5

-- #endregion

-- ===========================================================================
-- #region DEBUGGING
-- ===========================================================================
local Debugging = false;			-- Because sometimes you just need to...
local InstaImprove = true;			-- Supah speed
local BurnMePlease = true;			-- Will spawn barbarians on recent improvements to test pillaging

if Debugging then
	print("Debugging flag is enabled")
	if InstaImprove then
		DevelopmentScalar = DevelopmentScalar*10
		print(" - Tiles will improve extra fast")
	end
	if BurnMePlease then
		print(" - A barb warrior will spawn on recently auto-improved player tiles")
	end
end
-- Pillage testing
local BarbSpawnDelay = 1;
local BarbSpawnTurn = 0;
local Barbing = false;
local BarbSpawnPlot = nil;

print("Improvement Threshold = "..AutoImproveThreshold);

-- #endregion

-- ===========================================================================
-- #region PRIMARY EVENT HANDLER
-- ===========================================================================

function OnPlayerTurnStarted(playerID:number, isFirstTime)
	local currentGameTurn = Game.GetCurrentGameTurn()

	if notNilOrNegative(playerID) then
		TryPlayerImprovements(playerID, currentGameTurn)
	end
end
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);

--[[
if Debugging then
	-- Pillage Testing
	if BurnMePlease and Barbing then
		if currentGameTurn >= BarbSpawnTurn then
			SpawnBarbOnPlot(BarbSpawnPlot);
			Barbing = false;
		end
	end
end
]]

-- #endregion

-- ===========================================================================
-- #region STATE TABLE MANAGEMENT
-- ===========================================================================

function GetTurnTable(player)
	return player:GetProperty("AUTO_IMPROVE_TURN_TABLE")
end
function GetPlotTable(player)
	return player:GetProperty("AUTO_IMPROVE_PLOT_TABLE")
end
function GetTables(player : object)
	--print("Getting Tables")
	if player ~= nil then
		return GetTurnTable(player), GetPlotTable(player)
	end
	return nil, nil
end

function SetTables(player, TurnTable, PlotTable)
	--print("Setting Tables")
	if player ~= nil then
		player:SetProperty("AUTO_IMPROVE_TURN_TABLE", TurnTable)
		player:SetProperty("AUTO_IMPROVE_PLOT_TABLE", PlotTable)
	end
end

function RemovePlotFromTables(playerID : number, plotID : number)
	printIfPlayer(playerID, "Removing Plot: "..plotID)
	if notNilOrNegative(plotID) and notNilOrNegative(playerID) then
		local player = Players[playerID]
		local TurnTable, PlotTable = GetTables(player)

		if PlotTable ~= nil and TurnTable ~= nil then
			if PlotTable[plotID] ~= nil then
				local turn = table.remove(PlotTable, plotID)
				if TurnTable[turn] ~= nil then
					if TurnTable[turn][plotID] ~= nil then TurnTable[turn][plotID] = nil; end
					SetTables(player, TurnTable, PlotTable)
				end
			end
		end
	end
end

function UpdateImprovementTables(playerID:number, plotID:number, turn:number)
	printIfPlayer(playerID, "Updating Tables")
	if notNilOrNegative(playerID) and notNilOrNegative(plotID) and notNilOrNegative(turn) then
		if turn == nil then print("Turn was nil, wtf"); end
		local player = Players[playerID]

		local TurnTable, PlotTable = GetTables(player)
		
		if TurnTable == nil then TurnTable = {}; end
		if PlotTable == nil then PlotTable = {}; end

		if PlotTable[plotID] ~= nil then
			-- Need to remove the old entry in the TurnTable first by setting it nil
			local OldTurn = PlotTable[plotID]
			if TurnTable[OldTurn] ~= nil then
				TurnTable[OldTurn][plotID] = nil
			end
		end

		PlotTable[plotID] = turn
		if TurnTable[turn] == nil then TurnTable[turn] = {}; end
		TurnTable[turn][plotID] = true

		SetTables(player, TurnTable, PlotTable)
	else
		print("Bad args to function: <UpdateImprovementTables>")
	end
end

function ChangePlotOwner(plotID, newOwnerID, oldOwnerID)
	printIfPlayer(oldOwnerID, "Changing Owner from "..newOwnerID.." to "..oldOwnerID)
	if not(plotID == nil or newOwnerID == nil or oldOwnerID == nil) then
		local newOwner = Players[newOwnerID]
		local oldOwner = Players[oldOwnerID]

		--local newTurnTable, newPlotTable = GetTables(newOwner)
		local oldTurnTable, oldPlotTable = GetTables(oldOwner)

		if oldPlotTable ~= nil then
			if oldPlotTable[plotID] ~= nil then
				-- Get the turn
				local turn = oldPlotTable[plotID]
				UpdateImprovementTables(newOwnerID, plotID, turn)
				RemovePlotFromTables(oldOwnerID, plotID)
			else
				-- Initialize the plot
				InitializePlot(Map.GetPlotByIndex(plotID))
			end
		end

		-- Update the current owner
		local plot = Map.GetPlotByIndex(plotID)
		local DevData = GetPlotDevData(plot)
		DevData.Owner = newOwner
		SetPlotDevData(plot, DevData)
	end
end

function RemoveCityFromPlayer(playerID : number, city : object)
	printIfPlayer(playerID, "Removing City")
	for k,plot in orderedPairs(city:GetOwnedPlots()) do
		RemovePlotFromTables(playerID, plot:GetIndex())
	end
end

function InitializePlotDevData(pPlot : object)
	--print("Initializing Dev Data")
	if pPlot ~= nil then
		--print("Initializing plot: "..pPlot:GetIndex())
		-- Initialize the table		
		local growth = CalculateDevGrowth(pPlot)

		newDevData = {
			Development = 0,
			Growth 		= growth,
			LastUpdate 	= Game.GetCurrentGameTurn(),
			ImprovesOn 	= -1,
			Owner		= pPlot:GetOwner()
		};

		newDevData = CalculateImprovementTurn(newDevData)
		
		SetPlotDevData(pPlot, newDevData)

		return newDevData
	end
end

function SetPlotDevData(pPlot:object, newData:table)
	--print("Setting Dev Data")
	if pPlot ~= nil then
		pPlot:SetProperty("DEVELOPMENT_DATA", newData)
	end
end

function GetPlotDevData(pPlot:object)
	--print("Getting Dev Data")
	if pPlot ~= nil then
		local data = pPlot:GetProperty("DEVELOPMENT_DATA")
		if data == nil then data = InitializePlotDevData(pPlot); end
		return data
	end
	return nil
end

-- #endregion

-- ===========================================================================
-- #region DEVELOPMENT MANIPULATION
-- ===========================================================================

function UpdatePlot(pPlot : object)
	if pPlot ~= nil then
		printIfPlayer(pPlot:GetOwner(), "Updating Plot "..pPlot:GetIndex())
		local DevData = GetPlotDevData(pPlot)
		DevData = CalculateImprovementTurn(DevData, CalculateDevGrowth(pPlot))
		SetPlotDevData(pPlot, DevData)

		local prevOwner = DevData.Owner
		local currOwner = pPlot:GetOwner()
		if prevOwner ~= currOwner then ChangePlotOwner(pPlot:GetIndex(), currOwner, prevOwner); end

		-- We can update the tables for the owning player as well
		if notNilOrNegative(currOwner) then
			UpdateImprovementTables(currOwner, pPlot:GetIndex(), DevData.ImprovesOn)
		else
			-- no owner, what should we do?
		end
	else
		print("ERROR!!! Tried to update a plot, but it was nil!")
	end
end

function GetTilesToImprove(playerID:number, turn:number)
	local player = Players[playerID]
	local TurnTable = GetTurnTable(player)
	
	local plots = {}
	if TurnTable ~= nil then
		if TurnTable[turn] ~= nil then
			local PlotTable = GetPlotTable(player)
			-- Remove the entry for this turn
			local TurnEntry = table.remove(TurnTable, turn)
			if TurnEntry ~= nil then
				for k,_ in pairs(TurnEntry) do
					table.insert(plots, Map.GetPlotByIndex(k))
					-- Remove the plot from the map
					table.remove(PlotTable, k)
				end
				-- Update the tables
				SetTables(player, TurnTable, PlotTable)
			else
				printIfPlayer(playerID, "Turn Entry was nil")
			end
		else
			printIfPlayer(playerID, "No entry found in the turn table for turn: "..turn)
		end
	else
		printIfPlayer(playerID, "Turn table was nil")
	end

	return plots
end

function TryPlayerImprovements(playerID:number)
	printIfPlayer(playerID, "=====TRYING TO IMPROVE=====")
	local turn = Game.GetCurrentGameTurn()
	printIfPlayer(playerID, "Player: "..playerID.."   Turn: "..turn)

	local potentials = GetTilesToImprove(playerID, turn)
	if #(potentials) > 0 then
		for _,pPlot in pairs(potentials) do
			local plotID = pPlot:GetIndex()
			local city = Cities.GetPlotWorkingCity(plotID)
			local improved = TryMakeImprovement(pPlot, GetAutoImprovementType(pPlot), false)
			--local improved = TryMakeImprovement(pPlot, GetAutoImprovementType(pPlot), IsAquacultureAvailable(city))

			if not(improved) then
				-- Delay 5 turns (modified by game speed) before trying again
				local nextAttempt = turn + (5 * TurnMultiplier)
				UpdateImprovementTables(playerID, plotID, nextAttempt)
			end
		end
	else
		printIfPlayer(playerID, "No improvements to be made")
	end

	printIfPlayer(playerID, "=====DONE TRYING=====")
end

function CalculateDevGrowth(plot : object)
	--print("Calculating Growth")
	if plot ~= nil then
		-- Get plot details
		local owner			= plot:GetOwner()
		local workerCount	= plot:GetWorkerCount()
		local appeal		= plot:GetAppeal()
		local isFreshWater	= plot:IsFreshWater()
		local hasRoute		= plot:IsRoute()
		local yield			= plot:GetYield()	-- This sums all yields on the plot
		--local distToCity	= FindClosestCity(iX, iY, 10)

		-- Set the base growth to the tile's appeal (can be negative)
		-- If negative appeal, and unworked, utilization will drop back to zero
		local growth = appeal

		-- Subtract how far the plot is from the city (if adjacent subtract nothing)
		-- << SHOULD REPLACE THIS WITH A PATH DISTANCE THAT ACCOUNTS FOR ROUTES >>
		--growth = growth - (distToCity - 1)

		-- Growth from yields are fractional, but we want to take the floor anyway
		growth = growth + math.floor(yield * GROWTH_YIELD)

		-- Check for some other growths
		if isFreshWater then growth = growth + GROWTH_FRESHWATER; end
		if hasRoute then
			local subType = plot:GetProperty("RouteSubType")
			if subType == nil then subType = 3; end
			-- Subtract the route subtype, primary routes add the most benefit
			growth = growth + GROWTH_HASROUTE - subType
		end
						
		-- Add to the growth if the tile is being worked
		if workerCount > 0 then growth = growth + DevelopmentWorked; end

		-- Scale the growth so it is compatible with utilization
		return growth * DevelopmentScalar
	end

	return nil
end

function CalculateImprovementTurn(DevData, newGrowth)
	local currentTurn = Game.GetCurrentGameTurn()
	local growth = DevData.Growth

	-- Check to see if the Development value needs an update with the old growth value
	-- before checking to see if theres a change in growth
	if currentTurn ~= DevData.LastUpdate then
		local currentDev = DevData.Development;
		local timeSinceLastUpdate = currentTurn - DevData.LastUpdate;
		DevData.Development = currentDev + (timeSinceLastUpdate * growth);
		DevData.LastUpdate = currentTurn;
	end

	-- if the arg newGrowth is nil we just use the current growth
	if newGrowth ~= nil then growth = newGrowth; end

	local ImprovementTurn = nil
	if growth <= 0 then
		ImprovementTurn = math.huge
	else
		-- Get the difference between the improvement threshold and the current utilization
		local diff = Threshold - DevData.Development
		-- Number of turns is the diff divided by the growth rounded up
		local turns = math.ceil(diff / growth)
		-- And so the expected improvement turn is the number of turns plus the current turn
		ImprovementTurn = currentTurn + turns
	end

	DevData.ImprovesOn = ImprovementTurn
	DevData.Growth = growth

	return DevData
end

-- #endregion

-- ===========================================================================
-- #region AUTO IMPROVEMENTS AND MAINTENANCE
-- ===========================================================================

function GetAutoImprovementType(pPlot)
	local ePlotResource = pPlot:GetResourceType();
	local ePlotFeature = pPlot:GetFeatureType();
	local ePlotTerrain = pPlot:GetTerrainType();

	-- Check if there's a resource on the tile first
	if notNilOrNegative(ePlotResource) then
		-- Lookup the improvement type associated with this resource
		eImprovement = ImprovementLUT[ePlotResource]

		-- If it exists, check to see if the tile can have this improvement
		if notNilOrNegative(eImprovement) then
			if (ImprovementBuilder.CanHaveImprovement(pPlot, eImprovement , NO_TEAM)) then
				-- If it can be improved with this improvement, we return the index
				return eImprovement
			end
		end
		-- It can't be improved, we don't want to remove the resource, so go no further
		return -1;
	end

	-- Go through terrain and features in prioritized order
	local terrain = GameInfo.Terrains[ePlotTerrain].Name;
	local isHills = pPlot:IsHills();
	local isFlatland = pPlot:IsFlatlands();
	local isMountain = pPlot:IsMountain();
	local isWater = pPlot:IsWater();

	-- get features
	local hasForest = false;
	local hasJungle = false;
	local hasMarsh = false;
	local hasFloodplains = false;
	if notNilOrNegative(ePlotFeature) then
		hasForest = ePlotFeature == iForest;
		hasJungle = ePlotFeature == iJungle;
		hasMarsh = ePlotFeature == iMarsh;
		hasFloodplains = ePlotFeature == iFloodplains;
	end
	

	-- Skip mountains and marsh
	-- Could change marsh to have it clear the tile automatically
	-- or make a new improvement type for marsh tiles specifically?
	if isMountain or hasMarsh then return -1; end
	if hasForest or hasJungle then return iLumberMill; end
	if isHills and AllowAppealReduction then return iMine; end
	if isFlatland then return iFarm; end
	if isWater then return iFishery; end

	return -1;
end

function PlayerKnowsImprovement(iPlayer, eImprovementType)
	local player = Players[iPlayer]
	if player ~= nil and notNilOrNegative(eImprovementType) then
		local PrereqTech = GameInfo.Improvements[eImprovementType].PrereqTech;
		local PrereqCivic = GameInfo.Improvements[eImprovementType].PrereqCivic;
		
		local HasTech = true;
		local HasCivic = true;

		if (PrereqTech ~= nil) then
			if player:GetTechs():HasTech(GameInfo.Technologies[PrereqTech].Index) then
				--print("     "..PrereqTech.." is completed.");
			else
				--print("     "..PrereqTech.." is missing.");
				HasTech = false;
			end
		else
			--print("No Prereq Technology");
		end

		if (PrereqCivic ~= nil) then
			if player:GetCulture():HasCivic(GameInfo.Civics[PrereqCivic].Index) then
				--print("     "..PrereqCivic.." is completed.");
			else
				--print("     "..PrereqCivic.." is missing.");
				HasCivic = false;
			end
		else
			--print("No Prereq Civic");
		end

		return (HasTech and HasCivic);
	else
		--printIfPlayer(iPlayer, "Improvement type is nil or negative");
	end

	return false;
end

function IsAquacultureAvailable(City)
	if City ~= nil then
		local gov = City:GetAssignedGovernor()
		if notNilOrNegative(gov) then
			return (gov:IsEstablished() and gov:HasPromotion(m_eAquaculturePromotion))
		end
	end

	return false
end

function TryMakeImprovement(pPlot, eImprovementType, cityHasAquaculture)
	if notNilOrNegative(eImprovementType) and pPlot ~= nil then
		local plotX = pPlot:GetX()
		local plotY = pPlot:GetY()
		local iPlayer = pPlot:GetOwner()
		
		local PlotCanHave = ImprovementBuilder.CanHaveImprovement(pPlot, eImprovementType , NO_TEAM);
		local PlayerHasReqs = PlayerKnowsImprovement(iPlayer, eImprovementType);

		if PlotCanHave and PlayerHasReqs then
			CanBuildImprovement = true;

			-- If a fishery, make sure it's available
			if GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_FISHERY" then
				if not(cityHasAquaculture) then CanBuildImprovement = false; end
			end

			if CanBuildImprovement then
				--print("Good to go!");
				ImprovementBuilder.SetImprovementType(pPlot, eImprovementType, iPlayer);

				-- Notify the player
				local improvementName =  Locale.Lookup(GameInfo.Improvements[eImprovementType].Name)
				local msgString = Locale.Lookup("LOC_PLOT_AUTO_IMPROVED_MESSAGE_TEXT")
				local sumString = Locale.Lookup("LOC_PLOT_AUTO_IMPROVED_SUMMARY_TEXT", improvementName)
				local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
				NotificationManager.SendNotification(iPlayer, type, msgString, sumString, plotX, plotY);
				
				print("Auto-Improved <"..plotX..","..plotY.."> belonging to Player "..iPlayer.." with a "..improvementName);
				
				-- Setup barbarian spawn if debugging...
				if Debugging and BurnMePlease and not(Barbing) and iPlayer == 0 then
					print("You better watch out...")
					Barbing = true;
					BarbSpawnPlot = plot;
					BarbSpawnTurn = Game.GetCurrentGameTurn() + BarbSpawnDelay;
				end
				return true;
			else
				printIfPlayer(iPlayer, "Failed to improve...");
			end
		else
			--printIfPlayer(iPlayer, "Plot cannot be improved");
		end
	else
		printIfPlayer(iPlayer, "Improvement or plot wasn't defined properly");
	end
	
	return false;
end

function TryRepairPlot(plot : object)
	printIfPlayer(playerID, "Repaired pillaged tile");
	ImprovementBuilder.SetImprovementPillaged(pPlot, false)
end

-- #endregion

-- ===========================================================================
-- #region SECONDARY EVENT HANDLERS
-- ===========================================================================

-- CITY EVENTS

Events.CityTileOwnershipChanged.Add( function (ownerID, cityID, iX, iY)
	--print("City Tile Ownership Changed")
	UpdatePlot(Map.GetPlot(iX, iY))
end );
--]]

Events.CityTransfered.Add( function (newOwner, newCityID, oldOwner)
	RemoveCityFromPlayer(oldOwner, CityManager.GetCity(newOwner, newCityID))
end );

GameEvents.CityConquered.Add( function (newOwner, oldOwner, newCityID)
	RemoveCityFromPlayer(oldOwner, CityManager.GetCity(newOwner, newCityID))
end );

Events.CityWorkerChanged.Add( function(ownerID, cityID, iX, iY)
	print("Worker Changed")
	local plot = Map.GetPlot(iX, iY)
	UpdatePlot(plot)
end );

-- DISTRICT UPDATES
function OnDistrictAdded (playerID, districtID, cityID, X, Y, districtIndex, percentComplete)
	print("District Added")
	RemovePlotFromTables(playerID, Map.GetPlot(X, Y):GetIndex())
end

Events.DistrictRemovedFromMap.Add(function (playerID, districtID, cityID, X, Y, districtIndex)
	print("District Removed")
	--tprint(arg)
	UpdatePlot(playerID, Map.GetPlot(X, Y):GetIndex())
end)

Events.BuildingAddedToMap.Add(function (X, Y, buildingID, playerID, cityID, percentComplete, isPillaged)
	-- Mostly interested in checking for a wonder here to remove the tile
	--print("Building Added!")
	RemovePlotFromTables(playerID, Map.GetPlot(X, Y):GetIndex())
	--tprint(arg)
end)

function OnNationalParkAdded(playerID, X, Y)
	print("National Park Added!")
	-- Provided tile is the bottom of the diamond, so the coordinates should be explicit
	for _, plotID in ipairs(Game.GetNationalParks():GetAtLocation(X, Y)) do
		RemovePlotFromTables(playerID, Map.GetPlotByIndex(plotID))
	end
end

Events.NationalParkRemoved.Add(function (...)
	print("National Park Removed!")
	--tprint(arg)
end)


-- PLOT CHANGES
function OnPlotChangeEvent(iX:number, iY:number)
	--print("Plot Changed!")
	UpdatePlot(Map.GetPlot(iX, iY))
end
-- Several events call the same function, so we can set them in a loop
local PlotRecalcGrowthEvents = {
	Events.PlotAppealChanged,
	--Events.PlotPropertyChanged,
	Events.PlotYieldChanged,
	Events.FeatureRemovedFromMap,
	Events.FeatureAddedToMap,
	Events.ResourceAddedToMap,
	Events.ResourceRemovedFromMap
}

-- IMPROVEMENTS
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	print("Improvement Added")
	-- If an improvement is added by the player, the utilization should be set to at least the threshold
	local plot = Map.GetPlot(iX, iY)
	if notNilOrNegative(playerID) and plot ~= nil then
		local DevData = GetPlotDevData(plot)

		if DevData.Development < Threshold then
			-- Only care if the utilization is below threshold
			DevData.Development = Threshold
			SetPlotDevData(plot, DevData)
		end

		-- Need to remove this plot index from the update tables
		RemovePlotFromTables(playerID, plot:GetIndex())
	end
end

Events.ImprovementRemovedFromMap.Add(function (iX, iY, eImprovement, playerID)
	print("Improvement Removed")
	-- halve the utilization so it doesn't re-improve immediately
	local plot = Map.GetPlot(iX, iY)

	if notNilOrNegative(playerID) then
		local DevData = GetPlotDevData(plot)
		if DevData ~= nil then
			if notNilOrNegative(plot:GetOwner()) then
				local newVal = DevData.Development / 2
				DevData.Development = newVal
				SetPlotDevData(plot, DevData)
				UpdatePlot(plot)
			else
				RemovePlotFromTables(DevData.Owner, plot:GetIndex())
			end
		end
	end
end );

-- PLAYER DEFEATS
Events.PlayerDestroyed.Add(function (...)
	print("Player Destoryed")
	tprint(arg)
end)

Events.PlayerRevived.Add(function (...)
	print("PLayer Revived")
	tprint(arg)
end)

-- OTHER
Events.WMDDetonated.Add(function (X, Y, playerID, WMDIndex)
	
end)

Events.LoadComplete.Add(
	function()
		if #PlotRecalcGrowthEvents > 0 then
			for _,event in orderedPairs(PlotRecalcGrowthEvents) do
				event.Add(OnPlotChangeEvent)
			end
		end

		Events.DistrictAddedToMap.Add(OnDistrictAdded)
		Events.ImprovementAddedToMap.Add(OnImprovementAdded)
		Events.NationalParkAdded.Add(OnNationalParkAdded)
	end
)

-- #endregion

-- ===========================================================================
-- #region UTILITY FUNCTIONS
-- ===========================================================================

-- Find closest city of this tile
function FindClosestCity(iStartX, iStartY, range)

    local pCity = nil;
    local iShortestDistance = 100;

	local pPlot = Map.GetPlot(iStartX, iStartY)

	for pAdjacencyPlot in PlotAreaSpiralIterator(pPlot, range, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
        if pPlot:IsCity() then
			local thisX = pAdjacencyPlot:GetX();
			local thisY = pAdjacencyPlot:GetY();
            local iDistance = Map.GetPlotDistance(iStartX, iStartY, thisX, thisY);

			if (iDistance < iShortestDistance) then
				pCity = Cities.GetCityInPlot(thisX, thisY);
				iShortestDistance = iDistance;
			end
        end
    end

    return iShortestDistance, pCity;
end

function GetCityFavoredYields(city:object)

	local favoredYields = {}
	local disfavoredYields = {}

	if city ~= nil then

		for yield in GameInfo.YieldTypes do
			local isFavored = city:GetCitizens():IsFavoredYield(yield)
			local isDisfavored = city:GetCitizens():IsDisfavoredYield(yield)

			if isFavored then
				table.insert(favoredYields, yield)
			end

			if isDisfavored then
				table.insert(disfavoredYields, yield)
			end
		end
	end
	return favoredYields, disfavoredYields
end

-- MISCELLANEOUS

function notNilOrNegative(val)
	if val == nil then return false; end
	if val < 0 then return false; end

	return true
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
		print(formatting .. tostring(v));
    end
  end
end

function printIfPlayer(ID, text)
	local turnText = "Turn "..Game.GetCurrentGameTurn()..": "
	if ID == 0 then print(turnText..text); end
end

-- DEBUG AND TEST FUNCTIONS
function SpawnBarbOnPlot(plot : object)
	local barbPlayer = PlayerManager.GetAliveBarbarians()[1];

	barbPlayer:GetUnits():Create(m_eWarrior, plot:GetX(), plot:GetY());
	print("YOU SHALL BURN FOR ETERNITY!");
end

-- #region Plot Iterator Functions
-- Author: whoward69; URL: https://forums.civfanatics.com/threads/border-and-area-plot-iterators.474634/
-- convert funcs odd-r offset to axial. URL: http://www.redblobgames.com/grids/hexagons/
-- here grid == offset; hex == axial
    function ToHexFromGrid(grid)
        local hex = {
            x = grid.x - (grid.y - (grid.y % 2)) / 2;
            y = grid.y;
        }
        return hex
    end
    function ToGridFromHex(hex_x, hex_y)
        local grid = {
            x = hex_x + (hex_y - (hex_y % 2)) / 2;
            y = hex_y;
        }
        return grid.x, grid.y
    end

    SECTOR_NONE = nil
    SECTOR_NORTH = 1
    SECTOR_NORTHEAST = 2
    SECTOR_SOUTHEAST = 3
    SECTOR_SOUTH = 4
    SECTOR_SOUTHWEST = 5
    SECTOR_NORTHWEST = 6

    DIRECTION_CW = false
    DIRECTION_CCW = true

    DIRECTION_OUT = false
    DIRECTION_IN = true

    CENTRE_INCLUDE = true
    CENTRE_EXCLUDE = false

    function PlotRingIterator(pPlot, r, sector, anticlock)
        -- print(string.format("PlotRingIterator((%i, %i), r=%i, s=%i, d=%s)", pPlot:GetX(), pPlot:GetY(), r, (sector or SECTOR_NORTH), (anticlock and "rev" or "fwd")))
        -- The important thing to remember with hex-coordinates is that x+y+z = 0
        -- so we never actually need to store z as we can always calculate it as -(x+y)
        -- See http://keekerdc.com/2011/03/hexagon-grids-coordinate-systems-and-distance-calculations/

        if (pPlot ~= nil and r > 0) then
            local hex = ToHexFromGrid({x=pPlot:GetX(), y=pPlot:GetY()})
            local x, y = hex.x, hex.y

            -- Along the North edge of the hex (x-r, y+r, z) to (x, y+r, z-r)
            local function north(x, y, r, i) return {x=x-r+i, y=y+r} end
            -- Along the North-East edge (x, y+r, z-r) to (x+r, y, z-r)
            local function northeast(x, y, r, i) return {x=x+i, y=y+r-i} end
            -- Along the South-East edge (x+r, y, z-r) to (x+r, y-r, z)
            local function southeast(x, y, r, i) return {x=x+r, y=y-i} end
            -- Along the South edge (x+r, y-r, z) to (x, y-r, z+r)
            local function south(x, y, r, i) return {x=x+r-i, y=y-r} end
            -- Along the South-West edge (x, y-r, z+r) to (x-r, y, z+r)
            local function southwest(x, y, r, i) return {x=x-i, y=y-r+i} end
            -- Along the North-West edge (x-r, y, z+r) to (x-r, y+r, z)
            local function northwest(x, y, r, i) return {x=x-r, y=y+i} end

            local side = {north, northeast, southeast, south, southwest, northwest}
            if (sector) then
                for i=(anticlock and 1 or 2), sector, 1 do
                    table.insert(side, table.remove(side, 1))
                end
            end

            -- This coroutine walks the edges of the hex centered on pPlot at radius r
            local next = coroutine.create(function ()
                if (anticlock) then
                    for s=6, 1, -1 do
                        for i=r, 1, -1 do
                            coroutine.yield(side[s](x, y, r, i))
                        end
                    end
                else
                    for s=1, 6, 1 do
                        for i=0, r-1, 1 do
                            coroutine.yield(side[s](x, y, r, i))
                        end
                    end
                end

                return nil
            end)

            -- This function returns the next edge plot in the sequence, ignoring those that fall off the edges of the map
            return function ()
                local pEdgePlot = nil
                local success, hex = coroutine.resume(next)
                -- if (hex ~= nil) then print(string.format("hex(%i, %i, %i)", hex.x, hex.y, -1 * (hex.x+hex.y))) else print("hex(nil)") end

                while (success and hex ~= nil and pEdgePlot == nil) do
                    pEdgePlot = Map.GetPlot(ToGridFromHex(hex.x, hex.y))
                    if (pEdgePlot == nil) then success, hex = coroutine.resume(next) end
                end

                return success and pEdgePlot or nil
            end
        else
            -- Iterators have to return a function, so return a function that returns nil
            return function () return nil end
        end
    end


    function PlotAreaSpiralIterator(pPlot, r, sector, anticlock, inwards, centre)
        -- print(string.format("PlotAreaSpiralIterator((%i, %i), r=%i, s=%i, d=%s, w=%s, c=%s)", pPlot:GetX(), pPlot:GetY(), r, (sector or SECTOR_NORTH), (anticlock and "rev" or "fwd"), (inwards and "in" or "out"), (centre and "yes" or "no")))
        -- This coroutine walks each ring in sequence
        local next = coroutine.create(function ()
            if (centre and not inwards) then
                coroutine.yield(pPlot)
            end

            if (inwards) then
                for i=r, 1, -1 do
                    for pEdgePlot in PlotRingIterator(pPlot, i, sector, anticlock) do
                        coroutine.yield(pEdgePlot)
                    end
                end
            else
                for i=1, r, 1 do
                    for pEdgePlot in PlotRingIterator(pPlot, i, sector, anticlock) do
                        coroutine.yield(pEdgePlot)
                    end
                end
            end

            if (centre and inwards) then
                coroutine.yield(pPlot)
            end

            return nil
        end)

        -- This function returns the next plot in the sequence
        return function ()
            local success, pAreaPlot = coroutine.resume(next)
            return success and pAreaPlot or nil
        end
    end
-- #endregion End of iterator code --------------------
-- #endregion 


print("IMPROVEMENTS IMPROVED.");