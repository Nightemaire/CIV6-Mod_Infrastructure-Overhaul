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
include("TileGrowthSystem");
include("AutoImprovements_Config.lua");

--ExposedMembers.GameplayContext.TileGrowth

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
		DevelopmentScalar = DevelopmentScalar*5
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

print("Improvement Threshold = "..WTI_Config.AutoImproveThreshold);

-- #endregion

-- ===========================================================================
-- #region DEVELOPMENT MANAGEMENT
-- ===========================================================================

function ImprovementTrigger(plotID : number)
	if plotID ~= nil then
		pPlot = Map.GetPlotByIndex(plotID)
		CB_Method = pPlot:GetProperty("Development_CB_Method")
		
		if CB_Method ~= nil then
			print("Trigger method: "..CB_Method)
			if CB_Method == "ClaimTile" then
				TryClaimTile(pPlot, playerID)
			elseif CB_Method == "ImproveTile" then
				TryMakeImprovement(pPlot, GetAutoImprovementType(pPlot), false)
			elseif CB_Method == "BuildCity" then
				TryBuildCity(pPlot, playerID)
			else
				print("No callback method implemented");
			end
		else
			print("Callback method not defined")
		end
	end
end

function CalculateDevGrowth(plotID : number)
	--print("Calculating Growth")
	if plotID ~= nil then
		plot = Map.GetPlotByIndex(plotID)
		
		if plot ~= nil then
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
			local growth = appeal

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

			-- Scale the growth so it is compatible with utilization
			return growth * WTI_Config.DevelopmentScalar
		end
	end

	return nil
end

function OnPlotInitialized(PropertyID, plotID : number)
	if PropertyID == DevPropertyID then
		print("Responding to plot init")

		local pPlot = Map.GetPlotByIndex(plotID)
		-- Some simple cases to handle
		if pPlot == nil then return; end
		if pPlot:GetOwner() < 0 then 
			plot:SetProperty("Development_CB_Method", "ClaimTile")
			ChangeThreshold(PropertyID, plotID, WTI_Config.ExpansionThreshold)
			return; 
		end
		if pPlot:GetOwner() > 0 then
			for i = 0, 5 do
				local adjPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i)
				if adjPlot ~= nil then
					local owner = adjPlot:GetOwner()
					if owner < 0 then
						UpdatePlot(PropertyID, adjPlot:GetIndex())
					end
				end
			end
		end`	
	end
end
LuaEvents.OnPlotPropertyInitialized.Add(OnPlotInitialized)
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

function TryClaimTile(pPlot)
	local AdjPlayerDev = {}
	for i = 0, 5 do
		local adjPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i)
		local owner = adjPlot:GetOwner()
		if owner >= 0 then
			local playerDev = AdjPlayerDev[owner]
			local plotDev = ReadValue(DevPropertyID)
			if plotDev ~= nil then
				if playerDev ~= nil then
					AdjPlayerDev[owner] = plotDev
				else
					AdjPlayerDev[owner] = playerDev + plotDev
				end
			end
		end
	end

	-- Claim the tile for whoever has the most adjacent development
	local N_AdjPlayers = #AdjPlayerDev
	if N_AdjPlayers == 0 then
		return nil
	elseif N_AdjPlayers == 1 then
		pPlot:SetOwner(AdjPlayerDev[1])
	else
		print("There was a tie as to who claims the tile, it goes unclaimed!")
		local plotID = pPlot:GetIndex()
		SnoozeTrigger(DevPropertyID, plotID, 1)
	end
end

function TryMakeImprovement(pPlot, eImprovementType, cityHasAquaculture)
	local builtImprovement = false
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
				builtImprovement = true
			else
				printIfPlayer(iPlayer, "Failed to improve...");
			end
		else
			--printIfPlayer(iPlayer, "Plot cannot be improved");
		end
	else
		printIfPlayer(iPlayer, "Improvement or plot wasn't defined properly");
	end

	if not(builtImprovement) then
		-- Delay 5 turns (modified by game speed) before trying again
		SnoozeTrigger(DevPropertyID, plotID, 5 * TurnMultiplier)
	end
	
	return builtImprovement;
end

function TryRepairPlot(plot : object)
	printIfPlayer(playerID, "Repaired pillaged tile");
	ImprovementBuilder.SetImprovementPillaged(pPlot, false)
end

function TryBuildCity(pPlot, playerID)
	
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
		Events.FeatureAddedToMap,
		Events.ResourceAddedToMap,
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

improvements_initialized = false;
function GameLoaded()
	print("Game load complete")
	if not(improvements_initialized) then
		print("Initializing improvements")
		NewGrowthProperty(DevPropertyID, Threshold, CalculateDevGrowth, ImprovementTrigger)
		RegisterAllEvents()
		improvements_initialized = true
	end
end
Events.LoadGameViewStateDone.Add(GameLoaded)

-- CITY EVENTS
function OnCityTileChanged(ownerID, cityID, iX, iY)
	print("City Tile Changed: "..cityID)
	local plotID = Map.GetPlot(iX, iY):GetIndex()

	UpdatePlot(DevPropertyID, plotID)
end
function CityAdded(playerID, cityID, iX, iY)
	print("City Added: "..cityID)
	local plotID = Map.GetPlot(iX, iY):GetIndex()
	local city = Cities.GetCityInPlot(iX, iY)

	local plots = city:GetOwnedPlots()

	for k,plot in pairs(plots) do
		UpdatePlot(DevPropertyID, plot:GetIndex())
	end
end
function PopulationChanged(playerID, cityID, newPop)

end

-- DISTRICT UPDATES
function OnDistrictChanged (playerID, districtID, cityID, X, Y, districtIndex)
	print("District Added")
	
	local plotID = Map.GetPlot(X, Y):GetIndex()

	UpdatePlot(DevPropertyID, plotID)
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
	UpdatePlot(DevPropertyID, Map.GetPlot(iX, iY):GetIndex())
end

-- IMPROVEMENTS
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	print("Improvement Added")
	-- If an improvement is added by the player, the utilization should be set to at least the threshold
	local plotID  = Map.GetPlot(iX, iY):GetIndex()
	if notNilOrNegative(playerID) and plot ~= nil then
		SetValue(DevPropertyID, plotID, WTI_Config.AutoImproveThreshold)
		--UpdatePlot(DevPropertyID, plotID)
	end
end

Events.ImprovementRemovedFromMap.Add(function (iX, iY, eImprovement, playerID)
	print("Improvement Removed")
	-- halve the utilization so it doesn't re-improve immediately
	local plot = Map.GetPlot(iX, iY)

	if notNilOrNegative(playerID) then
		UpdatePlot(DevPropertyID, plot:GetIndex())
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

--GameTurnStart()

print("IMPROVEMENTS IMPROVED.");