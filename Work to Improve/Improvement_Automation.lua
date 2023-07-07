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
print("IMPROVING IMPROVEMENTS!!! 062223_2234");

include("SupportFunctions.lua");
--include("TileGrowthSystem");
include("AutoImprovements_Config.lua");

local TG = ExposedMembers.TileGrowth

-- #endregion

-- ===========================================================================
-- #region STATIC DEFINITIONS
-- ===========================================================================
local DevPropertyID = "Development"

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
local iMeteor : number = GameInfo.Improvements["IMPROVEMENT_METEOR_GOODY"].Index
local iBarbCamp : number = GameInfo.Improvements["IMPROVEMENT_BARBARIAN_CAMP"].Index
local iGoodyHut : number = GameInfo.Improvements["IMPROVEMENT_GOODY_HUT"].Index
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

-- Yields
local iFood = GameInfo.Yields["YIELD_FOOD"].Index
local iProduction = GameInfo.Yields["YIELD_PRODUCTION"].Index
local iFaith = GameInfo.Yields["YIELD_FAITH"].Index
local iScience = GameInfo.Yields["YIELD_SCIENCE"].Index
local iCulture = GameInfo.Yields["YIELD_CULTURE"].Index

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

local AllowAppealReduction = WTI_Config.Allow_Appeal_Reduction		-- FROM CONFIG
local Threshold = WTI_Config.AutoImproveThreshold					-- FROM CONFIG

DevelopmentMax = WTI_Config.BuildCityThreshold * 1.5

-- #endregion

-- ===========================================================================
-- #region DEBUGGING
-- ===========================================================================
local Debugging = false;			-- Because sometimes you just need to...
local InstaImprove = true;			-- Supah speed
local BurnMePlease = false;			-- Will spawn barbarians on recent improvements to test pillaging

if Debugging then
	print("Debugging flag is enabled")
	if InstaImprove then
		WTI_Config.DevelopmentScalar = WTI_Config.DevelopmentScalar*4
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

print("Expansion Threshold = "..WTI_Config.ExpansionThreshold);
print("Improvement Threshold = "..WTI_Config.AutoImproveThreshold);
print("City Threshold = "..WTI_Config.BuildCityThreshold);

-- #endregion

-- ===========================================================================
-- #region DEVELOPMENT MANAGEMENT
-- ===========================================================================

function ImprovementTrigger(plotID : number, direction : number)
	if plotID ~= nil then
		local pPlot = Map.GetPlotByIndex(plotID)
		local CB_Method = pPlot:GetProperty("Development_CB_Method")

		local success = false;
		
		if CB_Method ~= nil & direction > 0 then
			print("Trigger method: "..CB_Method)
			if CB_Method == 1 then
				success = TryClaimTile(pPlot)
			elseif CB_Method == 2 then
				success = TryMakeImprovement(pPlot)
			elseif CB_Method == 3 then
				success = TryBuildCity(pPlot)
			else
				print("No callback method implemented");
			end
		else
			print("Callback method not defined")
		end

		if success then
			newMethod = DetermineMethod(pPlot)
			if newMethod == nil then return; end
			if newMethod ~= CB_Method then
				TG.ClearTrigger(DevPropertyID, plotID)
				TG.UpdatePlot(DevPropertyID, plotID)
			end
		end
	end
end

function CalculateDevGrowth(plotID : number)
	--print("Calculating Growth")
	if plotID == nil then return nil; end
	local plot = Map.GetPlotByIndex(plotID)
	
	-- Can't calc anything without a plot...
	if plot == nil then return nil; end

	-- Get plot details
	local owner			= plot:GetOwner()
	local workerCount	= plot:GetWorkerCount()
	local appeal		= plot:GetAppeal()
	local isFreshWater	= plot:IsFreshWater()
	local hasRoute		= plot:IsRoute()
	local yield			= plot:GetYield(iProduction) + plot:GetYield(iFood)
	local city 			= Cities.GetPlotWorkingCity(plotID)
	local distToCity = 5;
	if city ~= nil then
		distToCity	= Map.GetPlotDistance(plot:GetX(), plot:GetY(), city:GetX(), city:GetY())
	end

	-- Set the base growth to the tile's appeal (can be negative)
	-- If negative appeal, and unworked, utilization will drop back to zero
	local growth = appeal * WTI_Config.GROWTH_APPEAL

	-- Subtract how far the plot is from the city (if adjacent subtract nothing)
	-- << SHOULD REPLACE THIS WITH A PATH DISTANCE THAT ACCOUNTS FOR ROUTES >>
	growth = growth - (distToCity - 1)

	-- Growth from yields can be fractional, but so we should floor the value
	growth = growth + math.floor(yield * WTI_Config.GROWTH_YIELD)

	-- Check for some other growths
	if isFreshWater then growth = growth + WTI_Config.GROWTH_FRESHWATER; end
	if hasRoute then
		local subType = plot:GetProperty("RouteSubType")
		if subType == nil then subType = 1; end
		-- Subtract the route subtype, primary routes add the most benefit
		growth = growth + WTI_Config.GROWTH_HASROUTE - subType
	end
					
	-- Add to the growth if the tile is being worked
	if workerCount > 0 then growth = growth + WTI_Config.GROWTH_WORKED; end

	-- Scale the growth
	return growth * WTI_Config.DevelopmentScalar
end

function DetermineMethod(pPlot)
	if pPlot == nil then
		print("Could not determine method for a nil plot")
		return
	end
	
	local plotID = pPlot:GetIndex()
	local newMethod = nil;

	if pPlot:GetOwner() < 0 then
		newMethod = 1
	else
		local dist, city = FindClosestCity(pPlot:GetX(), pPlot:GetY(), 5)
		--print("Closest City: "..dist)

		if dist <= 3 then
			-- This plot is owned, and in range of a city, so can only improve.
			newMethod = 2

			-- Iterate over the adjacent plots to initialize any plots that are on the boundary
			-- This is so they can be checked for building cities
			for i = 0, 5 do
				local adjPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i)
				if adjPlot ~= nil then
					local owner = adjPlot:GetOwner()
					if owner < 0 then
						TG.UpdatePlot(DevPropertyID, adjPlot:GetIndex())
					end
				end
			end
		else
			newMethod = 3
		end
	end

	if newMethod == 1 then
		pPlot:SetProperty("Development_CB_Method", newMethod)
		TG.ChangeThreshold(DevPropertyID, plotID, WTI_Config.ExpansionThreshold)
	elseif newMethod == 2 then
		pPlot:SetProperty("Development_CB_Method", newMethod)
		TG.ChangeThreshold(DevPropertyID, plotID, WTI_Config.AutoImproveThreshold)
	elseif newMethod == 3 then
		pPlot:SetProperty("Development_CB_Method", 3)
		TG.ChangeThreshold(DevPropertyID, plotID, WTI_Config.BuildCityThreshold)
	end

	return newMethod
end

function OnPlotInitialized(PropertyID, plotID : number)
	if PropertyID == DevPropertyID then
		--print("Plot Initialized: "..plotID)
		DetermineMethod(Map.GetPlotByIndex(plotID))
	end
end
LuaEvents.OnPlotPropertyInitialized.Add(OnPlotInitialized)
-- #endregion

-- ===========================================================================
-- #region AUTO IMPROVEMENTS AND MAINTENANCE
-- ===========================================================================

function GetAutoImprovementType(pPlot)

	if pPlot == nil then return -1; end

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

	-- Check for lumber mills
	if hasForest or hasJungle then return iLumberMill; end
	if isHills and WTI_Config.AllowAppealReduction then return iMine; end
	if isFlatland or hasFloodplains then return iFarm; end
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

function SumPlayersAdjacentDevelopment(pPlot)
	local AdjPlayerDev = {}
	
	for i = 0, 5 do
		local adjPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i)
		if adjPlot ~= nil then
			local owner = adjPlot:GetOwner()
			if owner >= 0 then
				local thisPlayer = AdjPlayerDev[owner]
				local playerDev = 0;
				local playerMaxPlotID = nil
				local maxPlotDev = -1
				if thisPlayer ~= nil then
					playerDev = thisPlayer[1]
					playerMaxPlotID = thisPlayer[3]
					maxPlotDev = thisPlayer[4]
				end
				
				local plotDev = TG.ReadValue(DevPropertyID, adjPlot)
				if plotDev ~= nil then
					if plotDev > maxPlotDev then
						maxPlotDev = plotDev
						playerMaxPlotID = adjPlot:GetIndex()
					end
					AdjPlayerDev[owner] = {playerDev + plotDev, owner, playerMaxPlotID, maxPlotDev}
				end
			end
		end
	end

	local maxDev = -1;
	local highestPlayer = -1
	local highestPlot = nil
	for k,v in pairs(AdjPlayerDev) do
		if k >= 0 then
			if v[1] > maxDev then
				highestPlayer = k
				highestPlot = v[3]
				maxDev = v[1]
			elseif v[1] == maxDev then
				highestPlayer = -1
				highestPlot = nil
			end
		end
	end

	return highestPlayer, highestPlot
end

function TryClaimTile(pPlot)
	--print("Claiming a tile!")
	local HighestPlayerAdjDev, HighestPlot = SumPlayersAdjacentDevelopment(pPlot)
	success = false

	-- Claim the tile for whoever has the most adjacent development
	if HighestPlayerAdjDev < 0 then
		print("The tile could not be claimed by one player!")
		local plotID = pPlot:GetIndex()
		TG.SnoozeTrigger(DevPropertyID, plotID, 2 * TurnMultiplier)
	else
		if HighestPlot ~= nil then
			local city = Cities.GetPlotWorkingCity(HighestPlot)

			if city ~= nil then
				local distToCity = Map.GetPlotDistance(pPlot:GetX(), pPlot:GetY(), city:GetX(), city:GetY())
				--print("Claim dist = "..distToCity)
				if distToCity <= 3 then
					WorldBuilder.CityManager():SetPlotOwner(pPlot, city)
				else
					pPlot:SetOwner(city:GetOwner())
				end

				success = true
			end
		end
	end

	return success
end

function TryMakeImprovement(pPlot)
	local builtImprovement = false

	if pPlot == nil then
		print("Plot was nil, can't improve")
		return false
	end
		
	local eImprovementType = GetAutoImprovementType(pPlot)
	if eImprovementType < 0 then
		print("Improvement couldn't be identified, can't improve, snoozing")
		TG.SnoozeTrigger(DevPropertyID, pPlot:GetIndex(), 1 * TurnMultiplier)
		return false
	end

	local plotX = pPlot:GetX()
	local plotY = pPlot:GetY()
	local iPlayer = pPlot:GetOwner()
	
	local PlotCanHave = ImprovementBuilder.CanHaveImprovement(pPlot, eImprovementType , NO_TEAM);
	local PlayerHasReqs = PlayerKnowsImprovement(iPlayer, eImprovementType);

	if PlotCanHave and PlayerHasReqs then
		CanBuildImprovement = true;

		-- If a fishery, make sure it's available
		if GameInfo.Improvements[eImprovementType].ImprovementType == "IMPROVEMENT_FISHERY" then
			if not(IsAquacultureAvailable(Cities.GetPlotWorkingCity(pPlot:GetIndex()))) then
				printIfPlayer(iPlayer, "Cannot build fisheries in this city");
				TG.SnoozeTrigger(DevPropertyID, pPlot:GetIndex(), 1 * TurnMultiplier)
				return false
			end
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

			builtImprovement = true
		else
			printIfPlayer(iPlayer, "Failed to improve...");
			TG.SnoozeTrigger(DevPropertyID, pPlot:GetIndex(), 1 * TurnMultiplier)
			return false
		end
	else
		printIfPlayer(iPlayer, "Plot cannot have the improvement, or player is missing a requirement");
		TG.SnoozeTrigger(DevPropertyID, pPlot:GetIndex(), 1 * TurnMultiplier)
		return false
	end
	
	return builtImprovement;
end

function TryRepairPlot(pPlot : object)
	printIfPlayer(0, "Repaired pillaged tile");
	ImprovementBuilder.SetImprovementPillaged(pPlot, false)
end

function TryBuildCity(pPlot)
	print("Making a new city!")

	local owner = pPlot:GetOwner();
	if owner < 0 then
		local plotID = pPlot:GetIndex()
		TG.SnoozeTrigger(DevPropertyID, plotID, 2 * TurnMultiplier)
		return false
	else
		Players[owner]:GetCities():Create(pPlot:GetX(), pPlot:GetY())
		return true
	end
end

-- #endregion

-- ===========================================================================
-- #region EVENT HANDLERS
-- ===========================================================================

function RegisterAllEvents()
	-- Several events call the same function, so we can set them in a loop
	local PlotRecalcGrowthEvents = {
		Events.PlotAppealChanged,
		--Events.PlotPropertyChanged,
		Events.PlotYieldChanged,
		Events.FeatureRemovedFromMap,
		--Events.FeatureAddedToMap,
		--Events.ResourceAddedToMap,
		Events.ResourceRemovedFromMap
	}

	if #PlotRecalcGrowthEvents > 0 then
		for _,event in pairs(PlotRecalcGrowthEvents) do
			event.Add(OnPlotChangeEvent)
		end
	end

	Events.CityAddedToMap.Add(CityAdded)
	Events.CityWorkerChanged.Add(OnCityTileChanged)
	Events.CityTileOwnershipChanged.Add(OnCityTileChanged)

	--Events.DistrictRemovedFromMap.Add(OnDistrictChanged)
	--Events.DistrictAddedToMap.Add(OnDistrictChanged)

	Events.ImprovementAddedToMap.Add(OnImprovementAdded)

	--Events.NationalParkAdded.Add(OnNationalParkAdded)
end

function GameLoaded()
	print("Game load complete")

	TG.DefineGrowthProperty(
		hmake PropertyListData {
			ID				= DevPropertyID,
			Threshold		= WTI_Config.ExpansionThreshold,
			GrowthFunc      = CalculateDevGrowth,
			Callback        = ImprovementTrigger,
			MinVal          = -WTI_Config.ExpansionThreshold,
			MaxVal          = WTI_Config.BuildCityThreshold * 1.2,
			TriggerMode     = "ONCE",
			TriggerTest     = nil,
			ShowLens		= true,
			ShowTooltip		= true
		}
	)

	RegisterAllEvents()
end
Events.LoadGameViewStateDone.Add(GameLoaded)

-- CITY EVENTS
function OnCityTileChanged(ownerID, cityID, iX, iY)
	print("City Tile Changed: "..cityID)
	local plotID = Map.GetPlot(iX, iY):GetIndex()

	TG.UpdatePlot(DevPropertyID, plotID)
end
function CityAdded(playerID, cityID, iX, iY)
	print("City Added: "..cityID)
	local plotID = Map.GetPlot(iX, iY):GetIndex()
	local city = Cities.GetCityInPlot(iX, iY)

	local plots = city:GetOwnedPlots()

	for k,plot in pairs(plots) do
		TG.UpdatePlot(DevPropertyID, plot:GetIndex())
	end
end
function PopulationChanged(playerID, cityID, newPop)

end

-- DISTRICT UPDATES
function OnDistrictChanged (playerID, districtID, cityID, X, Y, districtIndex)
	print("District Added")
	
	local plotID = Map.GetPlot(X, Y):GetIndex()

	TG.UpdatePlot(DevPropertyID, plotID)
end

Events.BuildingAddedToMap.Add(function (X, Y, buildingID, playerID, cityID, percentComplete, isPillaged)
	-- Mostly interested in checking for a wonder here to remove the tile
	--print("Building Added!")
	--RemovePlotFromTables(playerID, Map.GetPlot(X, Y):GetIndex())
	--tprint(arg)
end)

function OnNationalParkAdded(playerID, X, Y)
	print("National Park Added!")
	-- Provided tile is the bottom of the diamond, so the coordinates should be explicit
	for _, plotID in ipairs(Game.GetNationalParks():GetAtLocation(X, Y)) do
		
	end
end

Events.NationalParkRemoved.Add(function (...)
	print("National Park Removed!")
	--tprint(arg)
end)


-- PLOT CHANGES
function OnPlotChangeEvent(iX:number, iY:number)
	--print("Plot Changed!")
	TG.UpdatePlot(DevPropertyID, Map.GetPlot(iX, iY):GetIndex())
end

-- IMPROVEMENTS
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	-- If an improvement is added by the player, the utilization should be set to at least the threshold
	local plotID  = Map.GetPlot(iX, iY):GetIndex()
	if notNilOrNegative(playerID) and plot ~= nil and eImprovement ~= iMeteor and eImprovement ~= iBarbCamp then
		--print("Improvement Added")
		local val = ReadValue(DevPropertyID, Map.GetPlotByIndex(plotID))
		if val < WTI_Config.AutoImproveThreshold then
			TG.SetValue(DevPropertyID, plotID, WTI_Config.AutoImproveThreshold)
		end
		TG.UpdatePlot(DevPropertyID, plotID)
	end
end

Events.ImprovementRemovedFromMap.Add(function (iX, iY, eImprovement, playerID)
	-- halve the utilization so it doesn't re-improve immediately
	local plot = Map.GetPlot(iX, iY)

	if notNilOrNegative(playerID) and eImprovement ~= iBarbCamp and eImprovement ~= iGoodyHut then
		print("Improvement Removed")
		TG.UpdatePlot(DevPropertyID, plot:GetIndex())
	end
end );

-- PLAYER DEFEATS
Events.PlayerDestroyed.Add(function (...)
	print("Player Destroyed")
	tprint(arg)
end)

Events.PlayerRevived.Add(function (...)
	print("PLayer Revived")
	tprint(arg)
end)

-- OTHER
Events.WMDDetonated.Add(function (X, Y, playerID, WMDIndex)
	
end)

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
        if pAdjacencyPlot:IsCity() then
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

--GameTurnStart()

print("IMPROVEMENTS IMPROVED.");