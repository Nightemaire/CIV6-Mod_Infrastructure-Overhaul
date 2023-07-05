--------------------------------------------------------------
-- Railway Engineering
-- Author: Nightemaire
-- DateCreated: 6/18/2022
--------------------------------------------------------------

print("ENGINEERING RAILWAYS!!! 062323")

-- ===========================================================================
-- #region Constants and Definitions
-- ===========================================================================
include("SupportFunctions.lua");

-- Features
local iForest = GameInfo.Features["FEATURE_FOREST"].Index
local iJungle = GameInfo.Features["FEATURE_JUNGLE"].Index
local iMarsh = GameInfo.Features["FEATURE_MARSH"].Index
local iFloodplains = GameInfo.Features["FEATURE_FLOODPLAINS"].Index
local iVolcano = GameInfo.Features["FEATURE_VOLCANO"].Index
-- Terrains
local iSnow = GameInfo.Terrains["TERRAIN_SNOW"].Index
local iSnowHills = GameInfo.Terrains["TERRAIN_SNOW_HILLS"].Index
local iSnowMountain = GameInfo.Terrains["TERRAIN_SNOW_MOUNTAIN"].Index

local iRailroad = GameInfo.Routes["ROUTE_RAILROAD"].Index
local iTunnel = GameInfo.Improvements["IMPROVEMENT_MOUNTAIN_TUNNEL"].Index

local iIron = GameInfo.Resources["RESOURCE_IRON"].Index
local iCoal = GameInfo.Resources["RESOURCE_COAL"].Index

local iRailBuilder = GameInfo.Units["UNIT_RAILWAY_ENGINEER"].Index

local iRailyard = GameInfo.Buildings["BUILDING_RAILYARD"].Index
local iTCStation = GameInfo.Buildings["BUILDING_TCRR_STATION"].Index
local iSubway = GameInfo.Buildings["BUILDING_SUBWAY_NETWORK"].Index
local iFactory = GameInfo.Buildings["BUILDING_FACTORY"].Index
local iWorkshop = GameInfo.Buildings["BUILDING_WORKSHOP"].Index

local iTheodoreJudah = GameInfo.GreatPersonIndividuals["GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH"].Index

local iIndustrialZone = GameInfo.Districts["DISTRICT_INDUSTRIAL_ZONE"].Index
-- Need to get all districts that replace the industrial zone
function GetDistrictTypes(dist_name)
	local dist_index = GameInfo.Districts[dist_name].Index
	local NReplacements = #(GameInfo.DistrictReplaces);
	local Replacements = {dist_index}
	for i = 0, NReplacements-1 do
		local replacementType = GameInfo.DistrictReplaces[i].ReplacesDistrictType

		if replacementType == dist_name then
			local replacement = GameInfo.DistrictReplaces[i].CivUniqueDistrictType
			local replacement_index = GameInfo.Districts[replacement].Index
			table.insert(Replacements, replacement_index)
		end
	end
	return Replacements
end
local IZ_Types = GetDistrictTypes("DISTRICT_INDUSTRIAL_ZONE")
local Campus_Types = GetDistrictTypes("DISTRICT_CAMPUS")
local Theater_Types = GetDistrictTypes("DISTRICT_THEATER")
local Commercial_Types = GetDistrictTypes("DISTRICT_COMMERCIAL_HUB")
local Holysite_Types = GetDistrictTypes("DISTRICT_HOLY_SITE")
local Neighborhood_Types = GetDistrictTypes("DISTRICT_NEIGHBORHOOD")
local Encampment_Types = GetDistrictTypes("DISTRICT_ENCAMPMENT")
local Entertainment_Types = GetDistrictTypes("DISTRICT_ENTERTAINMENT_COMPLEX")

local validSubwayStations = {}
for k,i in pairs(IZ_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Campus_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Theater_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Commercial_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Holysite_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Neighborhood_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Encampment_Types) do table.insert(validSubwayStations, i); end
for k,i in pairs(Entertainment_Types) do table.insert(validSubwayStations, i); end

local GameSpeedType = GameConfiguration.GetGameSpeedType()
local RsrcMultiplier = math.floor(GameInfo.GameSpeeds[GameSpeedType].CostMultiplier / 50)

local RR_ResourceCost = RsrcMultiplier

print("Resource Multiplier = "..RsrcMultiplier)

-- #endregion

-- ===========================================================================
-- #region Event Handling
-- ===========================================================================

local function DebugTCRR(msg)
	local debug = true
	if debug then print(msg); end
end

function OnUnitAdded(playerID : number, unitID : number)
	local unit = Players[playerID]:GetUnits():FindID(unitID)
	if unit ~= nil then
		local unitType = unit:GetType()
		local tileX = unit:GetX()
		local tileY = unit:GetY()

		if (unitType == iRailBuilder) then
			print("Railway Engineer added at <"..tileX..","..tileY..">")

			unit:ChangeActionCharges(10)

			-- get the industrial zone tile and move the unit there
			local city = CityManager.GetCityAt(tileX, tileY)
			--CreateRailroadAt(Map.GetPlot(tileX, tileY))
			print("City ID: "..city:GetID())
			local IZ_X, IZ_Y = getIndustrialZoneTile(city)

			-- Build a railroad on the industrial zone (just in case it wasn't already built) and move the builder there
			if IZ_X == -1 then
				IZ_X = tileX
				IZ_Y = tileY
			end
			local plot = Map.GetPlot(IZ_X, IZ_Y);
			CreateRailroadAt(plot)
			UnitManager.PlaceUnit(unit, IZ_X, IZ_Y)
		elseif unit:IsGreatPerson() then
			if unit:GetGreatPerson():GetIndividual() == iTheodoreJudah then
				Players[playerID]:SetProperty("JUDAH_LOC", Map.GetPlot(tileX, tileY):GetIndex())
			end
		end
	end
end

function OnUnitMoved(playerID:number, unitID, tileX, tileY)
	local unit = Players[playerID]:GetUnits():FindID(unitID)
	if unit ~= nil then
		local unitType = unit:GetType()

		if (unitType == iRailBuilder) then
			local plot = Map.GetPlot(tileX, tileY);
			
			if plot ~= nil then
				local routeType = plot:GetRouteType();

				if unit:GetActionCharges() > 0 then
					if (not(plot:IsWater()) and not(routeType == iRailroad) and HasAdjacentRailroad(plot)) then
						CreateRailroadAt(plot)
						unit:ChangeActionCharges(-1)
					end
				end
			end

			if unit:GetActionCharges() <= 0 then
				print("Charges gone, firing the Railway Engineer");
				UnitManager.Kill(unit);
			end
		elseif unit:IsGreatPerson() then
			if unit:GetGreatPerson():GetIndividual() == iTheodoreJudah then
				Players[playerID]:SetProperty("JUDAH_LOC", Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex())
			end
		end
	end
end

function OnGreatPersonActivation(unitOwner, unitID, greatPersonClassID, greatPersonIndividualID)
	if greatPersonIndividualID == iTheodoreJudah then
		local plotID = Players[unitOwner]:GetProperty("JUDAH_LOC")
		--print("Judah Activated!")
		if plotID ~= nil then
			local pCity = Cities.GetPlotWorkingCity(plotID)
			if pCity ~= nil then
				print("Creating TC Station!")
				pCity:GetBuildQueue():CreateIncompleteBuilding(iTCStation, pCity:GetPlot(), 100)
			else
				print("Tried to make the TC Station, but city was nil!")
			end
		else
			print("Activated Judah, but the plot was nil...why!?")
		end
	end
end

function OnBuildingConstructed(playerID, cityID, buildingID, plotID, bOriginalConstruction)
	if bOriginalConstruction then
		if (buildingID == iRailyard) then
			local plot = Map.GetPlotByIndex(plotID)
			local city = CityManager.GetCity(playerID, cityID)
			local cityPlot = Map.GetPlot(city:GetX(), city:GetY())
			CreateRailroadAt(plot)
			CreateRailroadFromTo(plot, cityPlot, 5)
			--local player = Players[playerID]
			-- Spawn a free railbuilder for the AI, because they probably won't build one themselves
			--if player:IsAI() then
				--player:GetUnits():Create(iRailBuilder, plot:GetX(), plot:GetY());
			--end
		elseif (buildingID == iTCStation) then
			local actPlot = Map.GetPlotByIndex(plotID)
			--local areaID = actPlot:GetArea()
			--MapUtilities.ObtainLandmassBoundaries(areaID)
			local player = Players[playerID]

			local TC_RR_Start = player:GetProperty("TCRR_START")

			if TC_RR_Start == nil then
				player:SetProperty("TCRR_START", actPlot:GetIndex())
				CreateRailroadAt(actPlot)
				--local disconnectedCities = FindDisconnectedCities(areaID, playerID)
			else
				local TC_RR_End = player:GetProperty("TCRR_END")
				if TC_RR_End == nil then
					player:SetProperty("TCRR_END", actPlot:GetIndex())
					CreateRailroadAt(actPlot)
					StartTCRR(Map.GetPlotByIndex(TC_RR_Start), actPlot, playerID)
				else
					print("Judah activated extra times...Do nothing!")
				end		
			end
		elseif (buildingID == iSubway) then
			local city = CityManager.GetCity(playerID, cityID)
			CreateSubwayNetwork(city)
		end
	end
end

function FindDisconnectedCities(areaID, playerID)
	local player = Players[playerID]
	local cities = {}
	

	return cities
end

function OnPlayerTurnStart(playerID)
	local data = Players[playerID]:GetProperty("TCRR_DATA")

	if data ~= nil then
		print("Transcontinental Railroad in progress for player "..playerID..", Turn: ".. Game.GetCurrentGameTurn())
		
		local startProgress = data.progress

		progress, building = ContinueTCRR(data, playerID)

		plot = Map.GetPlotByIndex(data.PrevPlotF)
		plotX = plot:GetX()
		plotY = plot:GetY()

		if startProgress < 50 and progress >= 50 then
			local msgString = "Halfway there!"
			local sumString = "The Transcontinental Railroad is halfway complete!"
			local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
			NotificationManager.SendNotification(playerID, type, msgString, sumString, plotX, plotY);
			--print("More than halfway there!")
		end

		if not(building) then
			TCRR_Build = nil
			local msgString = "Transcontinental Railroad complete!"
			local sumString = "Your Transcontinental Railroad is now complete, congratulations!!"
			local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
			NotificationManager.SendNotification(playerID, type, msgString, sumString, plotX, plotY);
			--print("Complete!")
		end

		DebugTCRR("TCRR Turn Complete")
	end
end

local eventsLoaded = false
function OnLoad()
	if (not(eventsLoaded)) then
		print("Registering Events")
		Events.UnitAddedToMap.Add(OnUnitAdded)
		Events.UnitMoved.Add(OnUnitMoved)
		Events.UnitTeleported.Add(OnUnitMoved)
		--Events.UnitGreatPersonActivated.Add(OnGreatPersonActivation)

		GameEvents.BuildingConstructed.Add(OnBuildingConstructed)
		GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStart)

		eventsLoaded = true
	end
end
GameEvents.LoadGameViewStateDone.Add(OnLoad)

-- #endregion

-- ===========================================================================
-- #region Railroad Management
-- ===========================================================================

function getIndustrialZoneTile(city)
	local locX = -1;
	local locY = -1;
	if city ~= nil then
		for k,index in ipairs(IZ_Types) do
			local IZ = city:GetDistricts():GetDistrictByType(index)
			if IZ ~= nil then
				locX = IZ:GetX()
				locY = IZ:GetY()
				break
			end
		end
	end

	return locX, locY;
end

function CreateRailroadAt(plot:object)
	if plot ~= nil then
		if not(plot:IsWater()) and not(plot:IsImpassable()) then
			plot:SetProperty("RouteSubType", 0)
			RouteBuilder.SetRouteType(plot, iRailroad)
		end
	end
end

function UpgradeCityToRailroads(city)
	local Plots = city:GetOwnedPlots();
	--tprint(Plots, 0);
	local plotCount = #(Plots)
	
	print("There are "..plotCount.." plots belonging to the city of "..city:GetName());

	for k,plot in ipairs(Plots) do
		local routeType = plot:GetRouteType();
		local plotX = plot:GetX();
		local plotY = plot:GetY();
		--print("Plot at "..plotX..", "..plotY.." has a route type of "..routeType);
		if plot:IsRoute() then
			local subType = plot:GetProperty("RouteSubType")
			if subType ~= nil then
				if subType <= 2 then
					print("The plot is a secondary route or better, making it a railroad");
					CreateRailroadAt(plot)
				end
			else
				print("The plot is a route, making it a railroad");
				CreateRailroadAt(plot)
			end
		end
	end
end

function CreateSubwayNetwork(city)
	local Districts = city:GetDistricts()
	print("Building Subway Network!")
	-- Find All Valid Stations
	local Stations = {};
	for k,v in ipairs(validSubwayStations) do
		print(k..","..v)
		dist = Districts:GetDistrictByType(v)
		if dist ~= nil then
			plotX = dist:GetX()
			plotY = dist:GetY()
			table.insert(Stations, Map.GetPlot(plotX, plotY))
		end
	end

	for k,plot in pairs(Stations) do
		ConnectRailroadToNearest(plot, 3)
	end
end

function HasAdjacentRailroad(plot)
	local startX = plot:GetX();
	local startY = plot:GetY();
	--print("Start = {"..startX..", "..startY.."}")
	for i = 0, 5 do
		adjPlot = Map.GetAdjacentPlot(startX, startY, i)
		--print ("Adj = {"..adjPlot:GetX()..", "..adjPlot:GetY().."}")
		local routeType = adjPlot:GetRouteType();
		if adjPlot and routeType == iRailroad then return true; end
	end
	return false;
end

function ExtendDirection(plot, prevPlot, bTunneling, playerID)
	local tunnelling = bTunneling

	DebugTCRR("Extending railroads")
	if plot:IsMountain() then
		-- Open a new tunnel if needed
		DebugTCRR("Plot is a mountain")
		if not(bTunneling) then
			DebugTCRR("Starting a tunnel")
			ImprovementBuilder.SetImprovementType(plot, iTunnel, playerID)
			tunnelling = true
		end
	else
		DebugTCRR("Plot is not a mountain")
		-- Close the tunnel on the previous plot
		if bTunneling then
			DebugTCRR("Closing a tunnel")
			ImprovementBuilder.SetImprovementType(prevPlot, iTunnel, playerID)
		end
		tunnelling = false
		CreateRailroadAt(plot)
	end

	return tunnelling
end

function FinishTCRR(playerID, data, PlotF, PlotR)
	PrevPlotF = Map.GetPlotByIndex(data.prevPlotF)
	PrevPlotR = Map.GetPlotByIndex(data.prevPlotR)
	DebugTCRR("Finishing TCRR")
	if PlotR == nil then
		if PrevPlotF == nil or PlotF == nil or PrevPlotR == nil then
			print("Cannot finish TCRR, one or more required plots are nil")
			return
		end
		-- There's only one tile in the middle
		local M1 = PrevPlotF:IsMountain()
		local M2 = PlotF:IsMountain()
		local M3 = PrevPlotR:IsMountain()

		if not(M2) then
			-- Middle tile is not a mountain, need to close any previous tunnels!
			CreateRailroadAt(PlotF)
			if M1 then ImprovementBuilder.SetImprovementType(PrevPlotF, iTunnel, playerID) end
			if M3 then ImprovementBuilder.SetImprovementType(PrevPlotR, iTunnel, playerID) end
		else
			-- Middle tile is a mountain
			if not(M1 and M3) then
				-- One of either adjacent tiles is not a mountain, meaning we can close this tunnel
				-- If both are mountains, then the route is done!
				ImprovementBuilder.SetImprovementType(PlotF, iTunnel, playerID)
			end
		end		
	else
		if PrevPlotF == nil or PlotF == nil or PlotR == nil or PrevPlotR == nil then
			print("Cannot finish TCRR, one or more required plots are nil")
			return
		end
		-- Both tiles need to be finished
		local M1 = PrevPlotF:IsMountain()
		local M2 = PlotF:IsMountain()
		local M3 = PlotR:IsMountain()
		local M4 = PrevPlotR:IsMountain()

		if not(M2) and not(M3) then
			-- Neither middle plot is a mountain, build railroads and check for tunnel exits
			CreateRailroadAt(PlotF)
			CreateRailroadAt(PlotR)
			if M1 then ImprovementBuilder.SetImprovementType(PrevPlotF, iTunnel, playerID) end
			if M4 then ImprovementBuilder.SetImprovementType(PrevPlotR, iTunnel, playerID) end
		end
		if M2 and not(M3) then
			-- One plot is a mountain, build one railroad, one tunnel exit, and check for another tunnel exit
			CreateRailroadAt(PlotR)
			ImprovementBuilder.SetImprovementType(PlotF, iTunnel, playerID)
			if M4 then ImprovementBuilder.SetImprovementType(PrevPlotR, iTunnel, playerID) end
		end
		if not(M2) and M3 then
			-- One plot is a mountain, build one railroad, one tunnel exit, and check for another tunnel exit
			CreateRailroadAt(PlotF)
			ImprovementBuilder.SetImprovementType(PlotR, iTunnel, playerID)
			if M1 then ImprovementBuilder.SetImprovementType(PrevPlotF, iTunnel, playerID) end
		end
		if M2 and M3 then
			-- Both plots are mountains, don't build railroads, only check if they're tunnel exits
			if not(M1) then ImprovementBuilder.SetImprovementType(PlotF, iTunnel, playerID) end
			if not(M4) then ImprovementBuilder.SetImprovementType(PlotR, iTunnel, playerID) end
		end
	end
end

function ContinueTCRR(data, playerID)
	local player = Players[playerID]

	local speed = math.max(1, 6-RsrcMultiplier)
	local building = true

	if data ~= nil then
		for i = 1,speed do
			local route = data.Route
			local remaining = #(route)
			DebugTCRR("Count Remaining: "..remaining)
			-- Break out if there isn't anything left to build
			if remaining <= 0 then
				-- Build complete
				building = false
				break
			end

			-- Get resource information
			local thisCost = RR_ResourceCost * 2
			if remaining == 1 then thisCost = RR_ResourceCost; end

			DebugTCRR("This cost = "..thisCost)
			local playerIron = player:GetResources():GetResourceAmount("RESOURCE_IRON")
			local playerCoal = player:GetResources():GetResourceAmount("RESOURCE_COAL")

			if playerIron >= thisCost and playerCoal >= thisCost then
				local Plot1 = Map.GetPlotByIndex(table.remove(route, 1))
				if remaining == 1 then
					-- 1 tile left
					FinishTCRR(playerID, data, Plot1)
					building = false
				elseif remaining == 2 then
					-- 2 tiles left
					local Plot2 = Map.GetPlotByIndex(table.remove(route))
					FinishTCRR(playerID, data, Plot1, Plot2)
					building = false
				else
					-- More than 2 tiles left
					local Plot2 = Map.GetPlotByIndex(table.remove(route))
					data.tunnellingF = ExtendDirection(Plot1, Map.GetPlotByIndex(data.prevPlotF), data.tunnellingF, playerID)
					data.prevPlotF = Plot1:GetIndex()

					data.tunnellingR = ExtendDirection(Plot2, Map.GetPlotByIndex(data.prevPlotR), data.tunnellingR, playerID)
					data.prevPlotR = Plot2:GetIndex()
				end

				DebugTCRR("Deducting Cost")
				-- Deduct resources
				player:GetResources():ChangeResourceAmount(iIron, -thisCost)
				player:GetResources():ChangeResourceAmount(iCoal, -thisCost)

				data.step = data.step + 1
			else
				-- Not enough resources, notify player
				local plot = Map.GetPlotByIndex(route[1])
				SendLowResourceNotification(playerID, plot:GetX(), plot:GetY())
			end

			DebugTCRR("New Progress = "..(data.step/data.TotalLength)*100)
			data.progress = (data.step/data.TotalLength)*100
			data.Route = route

			if not(building) then break; end
		end

		if not(building) then
			player:SetProperty("TCRR_DATA", nil)
		else
			player:SetProperty("TCRR_DATA", data)
		end

		DebugTCRR("TCRR Build Complete")

		return data.progress, building
	else
		print("TCRR Data was nil, how'd that happen?!")
		return 0, false
	end
end

function StartTCRR(StartPlot, EndPlot, playerID)
	local route = GetRailroadRoute(StartPlot, EndPlot, 99999)

	if #route > 0 then
		local length = #(route)

		local player = Players[playerID]
		local TCRR_Data = {
			Route = route,
			TotalLength = math.ceil(length/2),
			tunnellingF = false,
			tunnellingR = false,
			prevplotF = nil,
			prevplotR = nil,
			step = 0,
			progress = 0
		}
		player:SetProperty("TCRR_DATA", TCRR_Data)

		local msgString = "Work has begun!"
		local sumString = "Your empire has begun construction of the Transcontinental Railroad!"
		local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
		NotificationManager.SendNotification(playerID, type, msgString, sumString, StartPlot:GetX(), StartPlot:GetY());

		-- Set Owner of all tiles to the player
		for _,tile in ipairs(route) do
			Map.GetPlotByIndex(tile):SetOwner(playerID)
		end
	else
		print("No route was found for the TCRR between the two cities :(")

		local msgString = "Work could not begin!"
		local sumString = "You built your second Transcontinental Railstation, but they could not be connected!"
		local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
		NotificationManager.SendNotification(playerID, type, msgString, sumString, StartPlot:GetX(), StartPlot:GetY());
	end
end

function SendLowResourceNotification(playerID, locX, locY)
	local msgString = "Work has slowed!"
	local sumString = "Construction of the Transcontinental Railroad has slowed due to a lack of resources!"
	local type = GameInfo.Notifications["NOTIFICATION_ROADS_UPGRADED"].Index;
	NotificationManager.SendNotification(playerID, type, msgString, sumString, locX, locY);
end

-- #endregion

-- ===========================================================================
-- #region Routebuilding
-- ===========================================================================

-- ===========================================================================
-- Utitity function: A* Pathfinding Algorithm
-- Author: Nightemaire
------------------------------------------------------------------------------
-- Overview:
-- This implementation follows the basic A* algorithm. Two lists of tiles are
-- populated and a simple heuristic calculated based on the distance and
-- move cost of the tile to the destination.
--
-- GitHub Repo: https://github.com/Nightemaire/CIV6-ModUtil_Pathfinding
-- ===========================================================================
local debug_pathfinding = false
function print_if_debugging(text)
	if debug_pathfinding then
		print(text)
	end
end

------------- WEIGHT SETTINGS -------------
local Base_Cost = 1

-- Terrain
local Hills_Cost = 2
local Mountain_Cost = 3
local Snow_Cost = 2

-- Features
local Forest_Cost = 1
local Jungle_Cost = 2
local Marsh_Cost = 2
local Floodplains_Cost = 1

-- Adjacency
local River_Crossing_Cost = 2
local Direction_Change_Cost = 2
--------------------------------------------
-- Searches for the fastest route over land from start to end within a specified range
-- Returns a table of the plot indices (in reverse order) as well as the total move cost
-- Attempts to maintain a straight course by weighting changes in direction heavier
function GetRailroadRoute(startPlot : object, endPlot : object, range)
	if startPlot ~= nil and endPlot ~= nil then
		local startX = startPlot:GetX()
		local startY = startPlot:GetY()
		local endX = endPlot:GetX()
		local endY = endPlot:GetY()

		if (range == nil) then range = 999999; end

		-- Take care of a few simple cases first
		if startPlot:IsWater() or endPlot:IsWater() then
			print_if_debugging("WARNING: One of the tiles in the route is water...")
			return {}, 99999;
		end
		if startPlot:GetIndex() == endPlot:GetIndex() then
			print_if_debugging("WARNING: Start and end plots are the same...why are you trying to find a path?")
			return {startPlot}, 0
		end
		minDist = Map.GetPlotDistance(startX, startY, endX, endY)
		if minDist <= 1 then
			print_if_debugging("NO PATH: Start and end plots are adjacent...pretty simple one here...")
			return {endPlot, startPlot}, 1
		end
		if minDist > range then
			print_if_debugging("NO PATH: Plots are too far from one another (specified range: "..range..")")
			return {}, 99999;
		end

		local localPlayerVis:table = PlayersVisibility[startPlot:GetOwner()]

		-- Okay, the path isn't so simple after all	
		print_if_debugging("Routing from <"..startX..","..startY.."> to <"..endX..","..endY..">");
		local fastestPath = {}
		local totalMoveCost = 99999

		-- Local tables for storing plots
		local OpenList = {}
		local ClosedList = {}

		-- A* ALGORITHM HELPER FUNCTIONS --
		local function CalcG(plot, initialCost, adjData)
			local G = initialCost

			local ePlotFeature = plot:GetFeatureType();
            local ePlotTerrain = plot:GetTerrainType();

			if plot:IsMountain() then
				G = G + Mountain_Cost
			elseif plot:IsHills() then
				G = G + Hills_Cost
			else
				G = G + Base_Cost
			end

			local HasSnow = ePlotTerrain == iSnow or ePlotTerrain == iSnowHills or ePlotTerrain == iSnowMountain;
            if HasSnow then G = G + Snow_Cost; end

            if notNilOrNegative(ePlotFeature) then
                if ePlotFeature == iForest then
                    G = G + Forest_Cost
                elseif ePlotFeature == iJungle then
                    G = G + Jungle_Cost
                elseif ePlotFeature == iMarsh then
                    G = G + Marsh_Cost
                elseif ePlotFeature == iFloodplains then
                    G = G + Floodplains_Cost
                end
            end

            if adjData.bDirectionChange then G = G + Direction_Change_Cost; end
            if adjData.bRiverCrossing then G = G + River_Crossing_Cost; end

			return G
		end

		-- Gets a table of adjacency data that's used in the open and update plot functions
		local function GetAdjacencyInfo(i, pPlot, adjPlot, lastdir)
			local crossesRiver = pPlot:IsRiverCrossingToPlot(adjPlot)
			local dirMatches = i == lastdir

			local adjacencyTable = {
				bRiverCrossing = crossesRiver,
				iDirection = i,
				bDirectionChange = not(dirMatches)
			}

			return adjacencyTable
		end

		-- Adds a plot to the OpenList and calculates its G, H, and F values
		local function OpenPlot(currPlot : object, initialCost, bIsStart, adjData)
			if currPlot ~= nil then
				if adjData == nil then
					adjData = {}
					adjData.iDirection = 0
					adjData.bRiverCrossing = false
					adjData.bDirectionChange = false
				end
				local plotOwner = currPlot:GetOwner()
				-- For building the railroads, we care that its the correct owner or no owner
				if plotOwner == -1 or plotOwner == startPlot:GetOwner() then
					local G = 0
					local H = Map.GetPlotDistance(currPlot:GetX(), currPlot:GetY(), endX, endY)

					-- If it's not the starting plot, we care about the movement cost
					if not(bIsStart) then
						G = CalcG(currPlot, initialCost, adjData)
					end
					
					local F = G + H

					local plotID = currPlot:GetIndex()

					OpenList[plotID] = {}
					OpenList[plotID].plot = currPlot
					OpenList[plotID].dir = adjData.iDirection
					OpenList[plotID].G = G
					OpenList[plotID].H = H
					OpenList[plotID].F = F

					local printStr = "in dir: "
					--if dirMatch then printStr = "in M dir: "; end
					print_if_debugging(">> Opened plot: "..plotID.." <"..H..", "..G..", "..F.."> "..printStr..adjData.iDirection);
				end
			else
				print("ERROR: Why'd you try to add a nil plot to the open list?");
			end
		end

		-- Updates a plot in the OpenList if the newCost results in a lower F value
		local function UpdatePlot(plot : object, newCost, adjData)
			local plotIndex = plot:GetIndex()
			-- See if the plot exists in the open list, but not the closed list
			--if OpenList[plotIndex] ~= nil  and ClosedList[plotIndex] == nil then
			local entry = OpenList[plotIndex]
			local oldF = entry.F
			local newG = CalcG(plot, newCost, adjData)
			local newF = newG + entry.H

			if newF < oldF then
				OpenList[plotIndex].G = newG
				OpenList[plotIndex].F = newF
				OpenList[plotIndex].dir = adjData.iDirection
			end
			--end
		end

		-- Used in ClosePlot() to check whether an adjacent plot is a valid candidate
		local function AdjacentIsPlotValid(adjPlot)
			if adjPlot ~= nil then
				local adjIndex = adjPlot:GetIndex()
				local adjX = adjPlot:GetX()
				local adjY = adjPlot:GetY()
				
				local isVisible = localPlayerVis:IsRevealed(adjX, adjY)
				local isVolcano = adjPlot:GetFeatureType() == iVolcano

				-- Check if the plot is not water, a volcano, or a natural wonder
				local invalidPlot = adjPlot:IsWater() or (adjPlot:IsImpassable() and not(adjPlot:IsMountain()) or isVolcano or adjPlot:IsNaturalWonder())
				
				-- Check validitiy, visibility, distance, and whether this plot is already in the closed list
				local dist = Map.GetPlotDistance(startX, startY, adjX, adjY)
				local isValid = not(invalidPlot) and ClosedList[adjIndex] == nil and dist <= range and isVisible

				return isValid
			end

			return false
		end

		-- Closes out a plot and adds or updates each valid adjacent plot to the OpenList
		local function ClosePlot(plot : object)
			local thisID = plot:GetIndex()
			local thisEntry = OpenList[thisID]
			local thisCost = thisEntry.G
			local thisDir = thisEntry.dir

			-- Remove from the OpenList, and add to the ClosedList
			OpenList[thisID] = nil
			ClosedList[thisID] = thisEntry
			print_if_debugging("Closing plot: "..thisID.." with direction: "..thisDir)
			local thisX = plot:GetX()
			local thisY = plot:GetY()
			-- Iterate over all adjacent plots
			for i = 0, 5 do
				local adjPlot = Map.GetAdjacentPlot(thisX, thisY, i)
				--print_if_debugging("Checking adjacent plot "..adjPlot:GetIndex())
				if adjPlot ~= nil then
					local adjIndex = adjPlot:GetIndex()
					if AdjacentIsPlotValid(adjPlot) then
						if OpenList[adjIndex] == nil then
							-- Plot is not in the open list, add it
							OpenPlot(adjPlot, thisCost, false, GetAdjacencyInfo(i, plot, adjPlot, thisDir))
						else
							-- Plot is in the open list, update it
							UpdatePlot(adjPlot, thisCost, GetAdjacencyInfo(i, plot, adjPlot, thisDir))
						end
					else
						--print_if_debugging("Cannot open adjacent plot: "..i)
					end
				end
			end
		end

		-- Returns the plot in the OpenList with the lowest F or G value
		local function GetNextPlot()
			local Fmin = 99999
			local Gmin = 99999
			local nextEntry = nil
			for k,entry in orderedPairs(OpenList) do
				--print("Evaluating open list item "..k)
				--if entry.F < Fmin and entry.G > Gmax then
				--[[
				if entry.G < Gmin then
					Gmin = entry.G
					nextEntry = entry
				end
				--]]
				--
				if entry.F < Fmin then
					Fmin = entry.F
					nextEntry = entry
				end
				--]]
			end

			local nextPlot = nil
			if nextEntry ~= nil then
				nextPlot = nextEntry.plot
				--print("Selected plot "..nextEntry.plot:GetIndex())
			end
				
			return nextPlot
		end

		-- BEGIN A* ALGORITHM --
		-- Initialize the algorithm to our starting location
		OpenPlot(startPlot, 0, true, nil)

		local searching = true
		local routeFound = false

		-- Iterate towards the destination
		print_if_debugging("Initiating search...")
		while searching do
			local next = GetNextPlot()
			if next ~= nil then
				ClosePlot(next)
			
				if next:GetIndex() == endPlot:GetIndex() then
					print_if_debugging("Found the end...")
					routeFound = true
					searching = false
				end
			else
				-- ran out of plots to check, no route is available
				print("ERROR: Search ended without finding end")
				searching = false
				routeFound = true
			end
			last = next
		end

		local routeComplete = false
		-- Backtrack to find the route
		if routeFound then
			local backtracking = true
			local currPlot = endPlot
			local maxIterations = 1000
			local thisIteration = 0
			local lastDir = -1

			local endEntry = ClosedList[endPlot:GetIndex()]

			table.insert(fastestPath, currPlot:GetIndex())

			print_if_debugging("Initiating backtrack...")
			while backtracking do
				thisIteration = thisIteration + 1
				local costMin = 99999
				local nextPlot = nil
				local thisDur = -1
				
				-- Remove the current plot from the closed list
				ClosedList[currPlot:GetIndex()] = nil

				local currX = currPlot:GetX()
				local currY = currPlot:GetY()

				-- iterate over all adjacent plots to find the lowest F cost
				--print("Checking adjacent plots... i = "..thisIteration)
				for i = 0, 5 do
					local adjPlot = Map.GetAdjacentPlot(currX, currY, i)				
					
					if adjPlot ~= nil then
						-- Check if the plot is closed
						local adjIndex = adjPlot:GetIndex()
						local entry = ClosedList[adjIndex]
						if entry ~= nil then
							-- if it is, we see whether it's the lowest G cost
							local thisCost = entry.G
							if thisCost < costMin or (thisCost == costMin and lastDir == i) then
								-- if it is, store it
								if thisCost == costMin then
									print_if_debugging("Plot "..adjIndex.." is better.  (Straight")
								else
									print_if_debugging("Plot "..adjIndex.." is better.  (G = "..thisCost..", D = "..lastDir..","..i..")")
								end
								costMin = thisCost
								nextPlot = adjPlot
								thisDur = i
							end
						end
					end
				end

				-- if we found a plot, then add it and set it as the current plot
				if nextPlot ~= nil then
					print_if_debugging("Found a closed neighbor")
					-- add the plot to the fastest path
					table.insert(fastestPath, nextPlot:GetIndex())

					if nextPlot:GetIndex() == startPlot:GetIndex() then 
						-- if we're back at the beginning, end the loop
						backtracking = false
						routeComplete = true
					else
						-- otherwise update the current plot
						currPlot = nextPlot
						lastDir = thisDur
					end	
				else
					-- Couldn't find a tile for some reason
					backtracking = false
					print("ERROR: Failed to find an adjacent plot on the closed list... i = "..thisIteration)
				end

				if thisIteration >= maxIterations then
					backtracking = false
					print("ERROR: Failed to find a route within the max iterations allowed (1000)")
				end
			end

			if routeComplete then
				totalMoveCost = endEntry.G
				print_if_debugging("Path Complete! Cost = "..totalMoveCost)
			else
				print("ERROR: Route wasn't completed")
				fastestPath = {}
				totalMoveCost = 9999999
			end
		end

		return fastestPath, totalMoveCost
	else
		print("ERROR: One of the provided plots was nil...")
	end
end

function CreateRailroadFromTo(fromPlot : object, toPlot : object, range)
	local path, cost = GetRailroadRoute(fromPlot, toPlot, range)
	if path ~= nil then
		for k, tile in pairs(path) do
			plot = Map.GetPlotByIndex(tile)
			if plot:IsMountain() then
				ImprovementBuilder.SetImprovementType(plot, iTunnel, plot:GetOwner())
			else
				CreateRailroadAt(plot)
			end
			
		end
	end
end

function GetAllRailroadsInRange(startPlot : object, range)
	local routePlots = {}

	for pAdjacencyPlot in PlotAreaSpiralIterator(startPlot, range, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
		local routeType = pAdjacencyPlot:GetRouteType();
        if routeType == iRailroad then
			table.insert(routePlots, pAdjacencyPlot)
        end
    end
	
	return routePlots
end

function ConnectRailroadToNearest(fromPlot : object, range)
	if fromPlot ~= nil then
		local owningPlayer = fromPlot:GetOwner()

		if notNilOrNegative(owningPlayer) then
			-- The starting tile has an owner, proceed
			local routesInRange = GetAllRailroadsInRange(fromPlot, range)
			
			-- If we found some routes
			if #(routesInRange) > 0 then 
				local minCost = 99999
				local fastPath = nil

				for k,routePlot in pairs(routesInRange) do
					if routePlot:GetOwner() == owningPlayer then
						local path, cost = GetRailroadRoute(fromPlot, routePlot, range)
						if (#(path) > 0 and cost < minCost) then
							fastPath = path 
							minCost = cost
						end
					end
				end
				if fastPath ~= nil then
					CreateRailroadAt(fromPlot)
					for k, tile in pairs(fastPath) do
						CreateRailroadAt(Map.GetPlotByIndex(tile))
					end
				else
					print("No connections could be made :/")
				end
			else
				print("No nearby railroads or districts were found to connect :(")
			end
		else
			print("The plot you tried to connect to isn't owned...")
		end
	end
end

-- #endregion

-- ===========================================================================
-- #region Utitity functions: Miscellaneous
-- ===========================================================================

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

function printArgTable(argTable)
	if (argTable ~= nil) then
		for k,v in ipairs(argTable) do
			print("Arg "..k..": "..v)
		end
	end
end
-- #endregion


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

print("RAILWAYS ENGINEERED.");