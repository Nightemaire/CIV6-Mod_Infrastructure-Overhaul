-- AutoImprovements
-- Author: Nightemaire
-- DateCreated: 6/20/2022 17:57:45
--------------------------------------------------------------
-- TODO LIST:
-- - 
--
-- IDEA LIST:
--	- Settings for what can be auto-improved (Luxury, strategic, bonus, forest, hills)
--	-	- Maybe let cities prioritize different things?
--	- Slash utilization on pillage
--	- Slash utilization if improvement is removed
--  - Make configuration exposed somewhere
--------------------------------------------------------------
print("IMPROVING IMPROVEMENTS!!! 16:16");

include("SupportFunctions");
include "AutoImprovements_Config.lua";

-- ===========================================================================
-- STATIC DEFINITIONS
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

g_iW, g_iH = Map.GetGridSize();

-- ===========================================================================
-- PARAMETERS
-- ===========================================================================

local UtilizationWorked = Utilization_Bonus_If_Worked	-- FROM CONFIG
local AllowAppealReduction = Allow_Appeal_Reduction		-- FROM CONFIG
local Threshold = AutoImproveThreshold					-- FROM CONFIG

UtilizationMax = Threshold * 1.5


-- ===========================================================================
-- DEBUGGING
-- ===========================================================================
local Debugging = false;			-- Because sometimes you just need to...
local InstaImprove = true;			-- Supah speed
local BurnMePlease = true;			-- Will spawn barbarians on recent improvements to test pillaging

if Debugging then
	print("Debugging flag is enabled")
	if InstaImprove then
		UtilizationScalar = UtilizationScalar*10
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

-- LOCAL TABLES
local pillagedPlots = {};

print("Improvement Threshold = "..AutoImproveThreshold);

-- ===========================================================================
-- PRIMARY EVENT HANDLERS
-- ===========================================================================

function OnPlayerTurnStarted(playerID:number, isFirstTime)
	local currentGameTurn = Game.GetCurrentGameTurn()
	TryPlayerImprovements(playerID, currentGameTurn)

	if Debugging then
		-- Pillage Testing
		if BurnMePlease and Barbing then
			if currentGameTurn >= BarbSpawnTurn then
				SpawnBarbOnPlot(BarbSpawnPlot);
				Barbing = false;
			end
		end
	end
end
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);

-- ===========================================================================
-- OPTIMIZATION
-- ===========================================================================

-- Store the utilization data as a struct for efficiency
hstructure UtilizationData
	Utilization		:number;
	Growth			:number;
	LastUpdate		:number;
	ImprovesOn		:number;
end

-- Table Management
function GetTables(player)
	return player:GetProperty("AUTO_IMPROVE_TURN_TABLE"), player:GetProperty("AUTO_IMPROVE_PLOT_TABLE")
end
function SetTables(player, TurnTable, PlotTable)
	if player ~= nil then
		player:SetProperty("AUTO_IMPROVE_TURN_TABLE", TurnTable)
		player:SetProperty("AUTO_IMROVE_PLOT_TABLE", PlotTable)
	end
end
function RemovePlotFromTables(playerID : number, plotID : number)
	if notNilOrNegative(plotID) then
		local player = Players[playerID]
		local TurnTable, PlotTable = GetTables(player)

		local turn = table.remove(PlotTable, plotID)
		TurnTable[turn][plotID] = nil

		SetTables(player, TurnTable, PlotTable)
	end
end
function UpdateImprovementTables(playerID:number, plotID:number, turn:number)
	if not(playerID == nil or plotID == nil or turn == nil) then
		local player = Players[playerID]

		local TurnTable, PlotTable = GetTables(player)
		
		if TurnTable == nil then TurnTable = {}; end
		if PlotTable == nil then PlotTable = {}; end

		if PlotTable[plotID] ~= nil then
			-- Need to remove the old entry first by setting it nil
			local OldTurn = PlotTable[plotID]
			TurnTable[OldTurn][plotID] = nil
		end

		PlotTable[plotID] = turn
		TurnTable[turn][plotID] = true

		SetTables(player, TurnTable, PlotTable)
	else
		print("Bad args to function: <UpdateImprovementTables>")
	end
end
function ChangePlotOwner(plotID : number, newOwnerID : number, oldOwnerID : number)
	if not(plotID == nil or newOwnerID == nil or oldOwnerID == nil) then
		local newOwner = Players[newOwnerID]
		local oldOwner = Players[oldOwnerID]

		local newTurnTable, newPlotTable = GetTables(newOwner)
		local oldTurnTable, oldPlotTable = GetTables(oldOwner)

		-- Transfer the plot table entry
		local turn = oldPlotTable[plotID]
		newPlotTable[plotID] = turn
		oldPlotTable[plotID] = nil

		-- Remove the old turn table entry and add the new
		oldTurnTable[turn][plotID] = nil
		newTurnTable[turn][plotID] = true

		SetTables(newOwner, newTurnTable, newPlotTable)
		SetTables(oldOwner, oldTurnTable, oldPlotTable)
	end
end

-- ===========================================================================
-- UTILIZATION UPDATES AND INITIALIZATION
-- ===========================================================================

function InitializePlot(plotID)	
	local pPlot = Map.GetPlotByIndex(plotID);

	-- Initialize the struct
	local newUtilData = hmake UtilizationData {
		Utilization = 0,
		Growth = 0,
		LastUpdate = 0,
		ImprovesOn = 0,
	};

	pPlot:SetProperty("UTILIZATION_DATA", newUtilData)

	-- Calculate the growth and update the utilization
	local growth = CalculatePlotGrowth(plotID)
	UpdatePlotUtilData(plotID, growth)
end

function UpdatePlotUtilData(plotID : number, newGrowth : number)
	local pPlot = Map.GetPlotByIndex(plotID)
	local UtilData = pPlot:GetProperty("UTILIZATION_DATA")
	local currentTurn = Game.GetCurrentGameTurn()

	-- Check to see if the Utilization value needs an update
	if not(currentTurn == UtilData.LastUpdate) then
		local currentUtil = UtilData.Utilization;
		local timeSinceLastUpdate = currentTurn - UtilData.LastUpdate;
		UtilData.Utilization = currentUtil + (timeSinceLastUpdate * UtilData.Growth);
		UtilData.LastUpdate = currentTurn;
	end

	-- Get the growth, if the arg newGrowth is nil we just use the current growth
	local growth = UtilData.Growth
	if newGrowth ~= nil then growth = newGrowth; end

	-- Get the difference between the improvement threshold and the current utilization
	local diff = Threshold - UtilData.Utilization
	-- Number of turns is the diff divided by the growth rounded up
	local turns = math.ceil(diff / growth)
	-- And so the expected improvement turn is the number of turns plus the current turn
	local ImprovementTurn = currentTurn + turns

	UtilData.ImprovesOn = ImprovementTurn
	UtilData.Growth = growth

	pPlot:SetProperty("UTILIZATION_DATA", UtilData)

	-- We can update the tables for the owning player as well
	local owner = pPlot:GetOwner()
	if notNilOrNegative(owner) then
		UpdateImprovementTables(pPlot:GetOwner(), plotID, ImprovementTurn)
	end

	return UtilData
end

function GetTilesToImprove(playerID:number, turn:number)
	local player = Players[playerID]
	local TurnTable, PlotTable = GetTables(player)

	local plots = {}

	if TurnTable[turn] ~= nil then
		-- Remove the entry for this turn
		local TurnEntry = table.remove(TurnTable, turn)
		for k,v in orderedPairs(TurnEntry) do
			table.insert(plots, Map.GetPlotByIndex(k))
			-- Remove the plot from the map
			table.remove(PlotTable, k)
		end
		-- Update the tables
		SetTables(player, TurnTable, PlotTable)
	end

	return plots
end

function TryPlayerImprovements(playerID:number, turn:number)
	local potentials = GetTilesToImprove(playerID, turn)
	if #potentials > 0 then
		for _,pPlot in orderedPairs(potentials) do
			local plotID = pPlot:GetIndex()
			local city = Cities.GetPlotWorkingCity(plotID)
			local improved = TryMakeImprovement(pPlot, GetAutoImprovementType(pPlot), IsAquacultureAvailable(city))

			if not(improved) then
				-- Delay 5 turns (modified by game speed) before trying again
				local nextAttempt = turn + (5 * TurnMultiplier)
				UpdateImprovementTables(playerID, plotID, nextAttempt)
			end
		end
	end
end

function CalculatePlotGrowth(plotID: number)
	local plot = Map.GetPlotByIndex(plotID)

	if plot ~= nil then
		-- Get plot details
		local owner			= plot:GetOwner()
		local workerCount	= plot:GetWorkerCount()
		local appeal		= plot:GetAppeal()
		local isFreshWater	= plot:IsFreshWater()
		local hasRoute		= plot:IsRoute()
		local yield			= plot:GetYield()	-- This sums all yields on the plot
		local distToCity	= FindClosestCity(iX, iY, 10)

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
		if workerCount > 0 then growth = growth + UtilizationWorked; end

		-- Scale the growth so it is compatible with utilization
		return growth * UtilizationScalar
	end

	return nil
end

-- ===========================================================================
-- AUTO IMPROVEMENTS AND MAINTENANCE
-- ===========================================================================

function UpdatePlayerCities(playerID)
	local cities = getAllCities(playerID)

	if cities ~= nil then
		-- Iterate over all cities
		for iCityIndex, city in cities:Members() do
			local data = GetCityData(city)
			for k,plot in orderedPairs(city:GetOwnedPlots()) do
				CalculateUtilGrowth(plot:GetX(), plot:GetY())
				UpdatePlotUtilization(plot, data)
			end
		end
	end

	PerformAllActions()
end

function RecacheImprovableTiles(playerID, cityID)
	local PlotCache = {}
	local city = CityManager.GetCity(playerID, cityID)

	for k,plot in orderedPairs(city:GetOwnedPlots()) do
		repeat
			if plot:IsCity() then break; end
			if plot:GetDistrictType() >= 0 then break; end
			if plot:GetWonderType() >= 0 then break; end
			if plot:IsNationalPark() then break; end
			if plot:IsWater() and not(plot:IsShallowWater()) then break; end

			PlotCache.Add(plot)
		until true
	end
	city.SetProperty("CACHED_PLOTS", PlotCache)
end

function RecalcUtilizationInCity(playerID, cityID)
	local city = CityManager.GetCity(playerID, cityID)
	local plots = city.GetProperty("CACHED_PLOTS")
	local data = GetCityData(city)

	for k,plot in orderedPairs(plots) do
		UpdatePlotUtilization(plot, data)
	end
end

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
	if notNilOrNegative(eImprovementType) then
		local PrereqTech = GameInfo.Improvements[eImprovementType].PrereqTech;
		local PrereqCivic = GameInfo.Improvements[eImprovementType].PrereqCivic;
		
		local HasTech = true;
		local HasCivic = true;

		if (PrereqTech ~= nil) then
			if getPlayer(iPlayer):GetTechs():HasTech(GameInfo.Technologies[PrereqTech].Index) then
				--print("     "..PrereqTech.." is completed.");
			else
				--print("     "..PrereqTech.." is missing.");
				HasTech = false;
			end
		else
			--print("No Prereq Technology");
		end

		if (PrereqCivic ~= nil) then
			if getPlayer(iPlayer):GetCulture():HasCivic(GameInfo.Civics[PrereqCivic].Index) then
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
	local gov = City:GetAssignedGovernor()
	return (gov:IsEstablished() and gov:HasPromotion(m_eAquaculturePromotion))
end

function GetCityData(city : object)
	
	local data = {}

	if city ~= nil then
		-- get the actual details
		data.plotX = city:GetX()
		data.plotY = city:GetY()
		data.cityID = city:GetID()
		data.HasAquaculture = IsAquacultureAvailable(city)
	else
		data.cityID = -1
		data.plotX = -1
		data.plotY = -1
		data.HasAquaculture = false
	end

	return data
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


-- ===========================================================================
-- OTHER EVENT HANDLERS
-- ===========================================================================

local InitGrowthEvents = {
	-- Events.CityAddedToMap,		-- playerID, cityID, x, y
}

-- Single plot recalc events
local PlotRecalcGrowthEvents = {
	Events.PlotAppealChanged,
	Events.PlotPropertyChanged,
	Events.PlotYieldChanged,
	--GameEvents.PlotOwnershipChanged,		-- Need to find args
	Events.FeatureRemovedFromMap,
	Events.FeatureAddedToMap
}

local CityRecalcGrowthEvents = {
	Events.CityWorkerChanged,			-- playerID, cityID, x, y
	Events.CityTileOwnershipChanged,	-- ownerID, cityID
}

local RecalcUtilEvents = {
	Events.CityInitialized,				-- playerID, cityID, x, y
	Events.CityPopulationChanged,		--playerID, cityID, cityPopulation
}

if #InitGrowthEvents > 0 then
	for i,event in orderedPairs(InitGrowthEvents) do
		event.Add(InitializePlotUtilization)
	end
end

if #PlotRecalcGrowthEvents > 0 then
	for i,event in orderedPairs(PlotRecalcGrowthEvents) do
		event.Add(CalculateUtilGrowth)
	end
end

if #RecalcUtilEvents > 0 then
	for i,event in orderedPairs(RecalcUtilEvents) do
		event.Add(UpdatePlotUtilization)
	end
end

-- IMPROVEMENTS

--Events.ImprovementChanged.Add(OnImprovementChanged);
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	local plot = Map.GetPlot(iX, iY)
	local util = getUtilization(plot)

	-- the utilization should be at least the threshold with an improvement
	setUtilization(plot, math.max(util, Threshold))
end
Events.ImprovementAddedToMap.Add(OnImprovementAdded);

-- Improvement Removed
function OnImprovementRemoved(iX, iY, eImprovement, playerID)
	-- halve the utilization so it doesn't re-improve immediately
	setUtilization(Map.GetPlot(iX, iY), Threshold/2)
end
Events.ImprovementRemovedFromMap.Add(OnImprovementRemoved);



-- City Initialized
function OnCityInitialized(cityOwner, cityID, iX, iY)

end
Events.CityInitialized.Add(OnCityInitialized);					-- (playerID, cityID, iX, iY)

-- City Focus Changed
function OnCityFocusChanged(cityOwner, cityID)
	local pPlayer = PlayerManager.GetPlayer(cityOwner)
	local city = pPlayer:GetCities():FindID(cityID)

	local favoredYields = {}
	local disfavoredYields = {}

	--for yield in GameInfo.YieldTypes do
		--local isFavored = city:GetCitizens():IsFavoredYield(yield)
		--local isDisfavored = city:GetCitizens():IsDisfavoredYield(yield)
--
		--if isFavored then
			--table.insert(favoredYields, yield)
		--end
--
		--if isDisfavored then
			--table.insert(disfavoredYields, yield)
		--end
	--end
end
--Events.CityFocusChanged.Add(OnCityFocusChanged);				-- (playerID, cityID)

-- Population Changed
function OnCityPopChanged(cityOwner, cityID, ChangeAmount)
	local city = CityManager.GetCity(cityOwner, getCity)
	local data = GetCityData(city)
	for k,plot in orderedPairs(city:GetOwnedPlots()) do
		UpdatePlotUtilization(plot, data)
	end
end
GameEvents.OnCityPopulationChanged.Add(OnCityPopChanged);		-- (cityOwner, cityID, ChangeAmount)

-- Worker Changed
function OnWorkerChanged(cityOwner, cityID, iX, iY)
	--local pPlayer = PlayerManager.GetPlayer(cityOwner)
	--local city = pPlayer:GetCities():FindID(cityID)

	--for k,plot in orderedPairs(city:GetOwnedPlots()) do
	local plot = Map.GetPlot(iX, iY)
	CalculateUtilGrowth(plot:GetX(), plot:GetY())
		--UpdatePlotUtilization(plot, CityData)
	--end
end
Events.CityWorkerChanged.Add(OnWorkerChanged);					-- (owner, cityID, iX, iY)

-- Tile Ownership Changed
function OnTileOwnershipChanged(cityOwner, cityID)
	--CalculateUtilGrowth(plot:GetX(), plot:GetY())
end
Events.CityTileOwnershipChanged.Add(OnTileOwnershipChanged);	-- (owner, cityID)

-- City Removed
function OnCityRemoved(cityOwner, cityID)
	
end
Events.CityRemovedFromMap.Add(OnCityRemoved);					-- (playerID, cityID)

-- City Conquered
function OnCityConquered(newOwner, oldOwner, newCityID, iX, iY)
	local pPlayer = PlayerManager.GetPlayer(newOwner)
	local city = pPlayer:GetCities():FindID(newCityID)

	for k,plot in orderedPairs(city:GetOwnedPlots()) do
		CalculateUtilGrowth(plot:GetX(), plot:GetY())
		--UpdatePlotUtilization(plot, CityData)
	end
end
--Events.CityConquered.Add(OnCityConquered);						--(newPlayerID,oldPlayerID,newCityID,x,y)

-- MISCELLANEOUS

-- Need to readjust route types to account for sub-type when a player era changes
function OnPlayerEraChange(playerID:number, eraID)
	
end
Events.PlayerEraChanged.Add(OnPlayerEraChange);



-- ===========================================================================
-- UTILITY FUNCTIONS
-- ===========================================================================

-- CITY MANAGEMENT

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

-- Get all cities belonging to a player
function getAllCities(playerID)
	local cities = getPlayer(playerID):GetCities();
	local cityCount = cities:GetCount();

	if cityCount > 0 then
		--print("Player has "..cityCount.." cities");
		return cities;
	else
		--print("Player has no cities")
	end

	return nil;
end

-- Get a single city from the playerID and city ID
function getCity(playerID, cityID)
	return getPlayer(playerID):GetCities():FindID(cityID);
end


-- PLAYER MANAGEMENT
function getPlayer(playerID)
	return PlayerManager.GetPlayer(playerID)
end

-- MISCELLANEOUS

function notNilOrNegative(val)
	if val ~= nil then
		if val >= 0 then
			return true;
		end
	end
	return false;
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

--------------------------------------------
-- Plot Iterator, Author: whoward69; URL: https://forums.civfanatics.com/threads/border-and-area-plot-iterators.474634/
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
-- End of iterator code --------------------




print("IMPROVEMENTS IMPROVED.");