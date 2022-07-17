-- AutoImprovements
-- Author: Nightemaire
-- DateCreated: 6/20/2022 17:57:45
--------------------------------------------------------------
-- TODO LIST:
-- - 
--
-- IDEA LIST:
-- - [DONE!] Notify player when a tile is automatically improved
--	- Settings for what can be auto-improved (Luxury, strategic, bonus, forest, hills)
--	-	- Maybe let cities prioritize different things?
--	- Slash utilization on pillage
--	- Slash utilization if improvement is removed
--  - Make configuration exposed somewhere
--------------------------------------------------------------
print("INITIATING IMPROVED IMPROVING IMPROVEMENTS IMMEDIATELY!");

include "AutoImprovements_Config.lua";
include "Automation_Utilities.lua";
include "Automation_Growth_Updates.lua";

-- ===========================================================================
-- DEFINITIONS
-- ===========================================================================
local GameSpeedType = GameConfiguration.GetGameSpeedType()
local SpeedMultiplier = GameInfo.GameSpeeds[GameSpeedType].CostMultiplier;

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

local AdjustRoads = false

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
local AutoImproveBase = Threshold_Scalar;				-- FROM CONFIG
local UtilizationWorked = Utilization_Bonus_If_Worked;	-- FROM CONFIG
local AllowAppealReduction = Allow_Appeal_Reduction;	-- FROM CONFIG

UtilizationMax = AutoImproveThreshold * 1.5

-- ===========================================================================
-- DEVELOPER CRAP
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
-- EVENT HANDLERS
-- ===========================================================================

function OnPlayerTurnActivate(playerID:number, isFirstTime)
	--UpdatePlayerCities(playerID);

	if Debugging then
		-- Pillage Testing
		if BurnMePlease and Barbing then
			if Game.GetCurrentGameTurn() >= BarbSpawnTurn then
				SpawnBarbOnPlot(BarbSpawnPlot);
				Barbing = false;
			end
		end
	end
end

function OnTurnBegin()
	-- Initialize the plots if this hasn't been done yet
	if Game.GetProperty("UTIL_IS_INIT") == nil then
		for iX = 0, g_iW - 1 do
			for iY = 0, g_iH - 1 do			
				local iPlotIndex = iY * g_iW + iX;
				local pPlot = Map.GetPlotByIndex(iPlotIndex);
				InitializePlotUtilization(pPlot)
			end
		end

		Game.SetProperty("UTIL_IS_INT", true)
	end

	-- Do all our utilization updates right at the start of the game turn
	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do

			local iPlotIndex = iY * g_iW + iX;
			local pPlot = Map.GetPlotByIndex(iPlotIndex);



			if pPlot:IsWater() then

			elseif pPlot:IsMountain() then

			elseif pPlot:IsImpassable() then

			else
				UpdatePlotUtilization(pPlot)
			end
		end
	end
end

-- ===========================================================================
-- UTILIZATION UPDATES AND INITIALIZATION
-- ===========================================================================

function InitializePlotUtilization(plot : object)
	RecalcPlotUtilGrowth(plot:GetX(), plot:GetY())
	UpdatePlotUtilization(plot)
end

function UpdatePlotUtilization(plot : object, CityData : table)
	local plotX = plot:GetX()
	local plotY = plot:GetY()
	local plotID = plot:GetIndex()

	if CityData == nil then
		CityData = GetCityDataForPlot(plot)
	end

	local ActionItems = {}

	-- Get some information about the plot
	local owner			= plot:GetOwner()
	local isCity		= plot:IsCity()
	local isDistrict	= plot:GetDistrictType() >= 0
	local isWonder		= plot:GetWonderType() >= 0
	local isPark		= plot:IsNationalPark()

	local PlotIsImprovable = not(isCity) and not(isDistrict) and not(isWonder) and not(isPark)

	-- If we can't figure out what else to do, we'll keep utilization the same
	local NewUtilization = getUtilization(plot)

	if PlotIsImprovable then		
		local growth = plot:GetProperty("PLOT_UTIL_GROWTH");
		if growth == nil then growth = 0; end
		NewUtilization = NewUtilization + growth

		if plot:GetImprovementType() < 0 then
			-- Unimproved			
			local AutoImprovement = GetAutoImprovementType(plot)
			if NewUtilization >= AutoImproveThreshold then
				QueueImprovement(plotID, AutoImprovement, CityData)
			end
		else
			-- Already improved
			if NewUtilization >= AutoImproveThreshold then
				QueueRepair(plotID)
			end
		end
	end
		
	setUtilization(plot, NewUtilization)

	return NewUtilization
end

function getUtilization(plot : object)
	local util = plot:GetProperty("PLOT_UTILIZATION");
	if util == nil then util = 0; end
	return util;
end

function setUtilization(plot : object, value)
	if plot ~= nil then
		plot:SetProperty("PLOT_UTILIZATION", value);
	else
		print("Tried to set utilization but the plot was NIL");
	end
end

-- Action Queue
local ActionQueue = {}

function QueueAction(actionID, plotID, details)
	local newAction = {}
	newAction.ID = actionID
	newAction.plot = plotID
	newAction.details = details

	table.insert(ActionQueue, newAction)
end

function QueueImprovement(plotID, improvement, hasAquaculture)
	local details = {}
	details.improvement = improvement
	details.HasAquaculture = hasAquaculture

	QueueAction("IMPROVE", plotID, details)
end

function QueueRepair(plotID)
	QueueAction("REPAIR", plotID)
end

function PerformAllActions()
	local N_Actions = #(ActionQueue)
	--print("There are "..N_Actions.." Actions to execute")
	if N_Actions > 0 then
		for k,a in pairs(ActionQueue) do
			PerformAction(a)
		end
		ActionQueue = {}
	end
end

function PerformAction(action)
	if action ~= nil then
		local ID = action.ID
		local plot = Map.GetPlotByIndex(action.plot)
		local details = action.details
		if ID == "IMPROVE" then
			TryMakeImprovement(plot, details.improvement, details.HasAquaculture)
		elseif ID == "REPAIR" then
			TryRepairPlot(TryRepairPlot)
		else
			print("Action "..ID.." not found")
		end
	else
		print("Action was nil")
	end
end

-- ===========================================================================
-- AUTO IMPROVEMENTS AND MAINTENANCE
-- ===========================================================================
function UpdatePlayerCities(playerID)
	local cities = getAllCities(playerID)

	if cities ~= nil then
		-- Iterate over all cities
		for iCityIndex : number, city : object in cities:Members() do
			UpdateCityUtilizations(city)
		end
	end
	
	PerformAllActions()
end

function GetAutoImprovementType(pPlot : object)
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
	if isHills then return iMine; end
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

function IsAquacultureAvailable(cityID)
	local players = PlayerManager.GetAliveMajors()
	for _,player in pairs(players) do
		-- First check if the player promoted Liang for Aquaculture
		local Has_AC = player:GetProperty("HAS_AQUACULTURE")

		if Has_AC then
			-- Now see which city Liang is established in
			local AC_city = player:GetProperty("AQUACULTURE_CITY")

			if AC_city ~= nil then
				-- If the appointed city is this city, return true
				if cityID == AC_city then return true; end
			end
		end
	end

	return false;
end

function GetCityDataForPlot(plot : object)
	local owner = plot:GetOwner()

	local data = {}

	if notNilOrNegative(owner) then
		-- get the actual details
		data.cityID = -1
		data.plotX = -1
		data.plotY = -1
		data.HasAquaculture = false
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
end

-- ===========================================================================
-- UTILITY
-- ===========================================================================

-- DEBUG AND TEST FUNCTIONS
function SpawnBarbOnPlot(plot : object)
	local barbPlayer = PlayerManager.GetAliveBarbarians()[1];

	barbPlayer:GetUnits():Create(m_eWarrior, plot:GetX(), plot:GetY());
	print("YOU SHALL BURN FOR ETERNITY!");
end

-- ===========================================================================
-- EVENT SUBSCRIPTIONS
-- ===========================================================================

-- Turn Events
--Events.PlayerTurnActivated.Add(OnPlayerTurnActivate);
Events.TurnBegin.Add(OnTurnBegin);

print("AUTO IMPROVEMENTS LOAD COMPLETE!");