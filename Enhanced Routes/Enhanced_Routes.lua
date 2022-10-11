-- More_Infrastructure
-- Author: bbarr
-- DateCreated: 7/22/2022 19:35:45
--------------------------------------------------------------

print("ENHANCING ROUTES!! 18:36");

include "Enhanced_Routes_Config.lua";
include "SupportFunctions.lua";

-- ===========================================================================
-- #region Configuration
-- ===========================================================================

local Connect_Improvements = ER_Config.Connect_Improvements
local Improvement_Connect_Range = ER_Config.Improvement_Connect_Range

local Connect_Districts = ER_Config.Connect_Districts
local District_Connect_Range = ER_Config.District_Connect_Range

local Connect_Cities = ER_Config.Connect_Cities
local City_Connect_Range = ER_Config.City_Connect_Range

local Minimize_River_Crossings = ER_Config.Minimize_River_Crossings


-- ===========================================================================
-- Definitions
-- ===========================================================================
-- Route Types
local i_AncientRoad = GameInfo.Routes["ROUTE_ANCIENT_ROAD"].Index;
local i_MedievalRoad = GameInfo.Routes["ROUTE_MEDIEVAL_ROAD"].Index;
local i_IndustrialRoad = GameInfo.Routes["ROUTE_INDUSTRIAL_ROAD"].Index;
local i_ModernRoad = GameInfo.Routes["ROUTE_MODERN_ROAD"].Index;
local i_Railroad = GameInfo.Routes["ROUTE_RAILROAD"].Index;

-- #endregion

-- ===========================================================================
-- #region Event Handling
-- ===========================================================================

-- Makes sure that when the trader moves, the route becomes a primary route
local m_eTrader : number = GameInfo.Units["UNIT_TRADER"].Index
function OnUnitMoved(playerID:number, unitID, tileX, tileY)
	local unit = Players[playerID]:GetUnits():FindID(unitID)
	local unitType = unit:GetType()

	if (unitType == m_eTrader) then
		local plot = Map.GetPlot(tileX, tileY)
		if plot:GetProperty("RouteSubType") ~= 0 then
			plot:SetProperty("RouteSubType", 1)
		end
	end
end

-- Event handler if improvements are being connected
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	local plot = Map.GetPlot(iX, iY)
	local improvement = GameInfo.Improvements[eImprovement]
	if improvement.Buildable then
		if playerID >= 0 and playerID < 63 then
			local name = Locale.Lookup(GameInfo.Improvements[eImprovement].Name)
			print(name.." added at <"..iX..","..iY..">, giving it a road!")
			if not(plot:IsWater()) then
				ConnectToNearestRouteOfOwner(plot, Improvement_Connect_Range, 3)
			end
		end
	end
end

-- Event handler for connecting districts
function OnDistrictBuildProgressChanged(playerID:number, districtID, cityID, iX, iY, districtType, era, civilization, percentComplete, Appeal, isPillaged)
	
	if (percentComplete == 100) then
		print("District completed, creating intra-city routes...")

		local city = Players[playerID]:GetCities():FindID(cityID)
		local cityPlot = Map.GetPlot(city:GetX(), city:GetY())
		local thisPlot = Map.GetPlot(iX, iY)
		
		local startPlot = nil

		-- If it's water (harbor or water park), find an owned land tile nearest to the city to start from
		if thisPlot:IsWater() then
			-- Check all adjacent tiles for land
			local candidates = {}	
			for i = 0, 5 do
				adjPlot = Map.GetAdjacentPlot(thisPlot:GetX(), thisPlot:GetY(), i)
				if not(adjPlot:IsWater()) and adjPlot:GetOwner() == playerID then
					table.insert(candidates, adjPlot)
				end
			end

			-- Pick the one which is closest to the city
			if #(candidates) > 0 then
				if #(candidates) == 1 then
					startPlot = candidates[1]
				else
					local minDist = 9999
					local cityX = cityPlot:GetX()
					local cityY = cityPlot:GetY()
					for k,iPlot in orderedPairs(candidates) do
						local thisDist = Map.GetPlotDistance(cityX, cityY, iPlot:GetX(), iPlot:GetY())
						if thisDist < minDist then
							startPlot = iPlot
						end
					end
				end
			else
				print("Failed to find candidate land tiles to connect this water district")
			end
		else
			startPlot = thisPlot
		end

		if startPlot ~= nil then
			-- Connect to the city
			CreateRouteFromTo(startPlot, cityPlot, 2)

			-- Connect to other nearby districts
			local Plots = city:GetOwnedPlots()

			for k,plot in pairs(Plots) do
				if plot:GetIndex() ~= startPlot:GetIndex() and not(plot:IsWater()) then
					if plot:GetDistrictID() >= 0 then
						-- Quick range check
						local plotDist = Map.GetPlotDistance(plot:GetX(), plot:GetY(), startPlot:GetX(), startPlot:GetY())
						if plotDist <= District_Connect_Range then
							CreateRouteFromTo(startPlot, plot, 2)
						end
					end
				end
			end
		end
	else
		
	end
end

-- Event handler for connecting cities
function OnCityAdded(playerID, cityID, iX, iY)
	print("City added at <"..iX..","..iY..">, connecting to nearby cities with roads")
	local cities = AllCitiesWithinXTiles(City_Connect_Range, iX, iY)
	local thisPlot = Map.GetPlot(iX, iY)
	if #(cities) > 0 then
		for k,city in pairs(cities) do
			local cityX = city:GetX()
			local cityY = city:GetY()
			if city:GetID() ~= cityID and city:GetOwner() == playerID and Map.GetPlotDistance(iX, iY, cityX, cityY) <= City_Connect_Range then
				CreateRouteFromTo(Map.GetPlot(iX, iY), Map.GetPlot(cityX, cityY), 1)
			end
		end
	end
end

-- Sets the sub type on any route that gets created
-- This also fires for each route in an empire when an era change occurs (since i think it just replaces all routes)
function OnRouteAdded(iX, iY)
	--print("A route was added at <"..iX..","..iY..">")
	local plot = Map.GetPlot(iX, iY)	
	local routeType = plot:GetRouteType()
	
	if routeType ~= i_Railroad then
		-- if there's no sub type, then we need to set one
		if plot:GetProperty("RouteSubType") == nil then
			local isCity		= plot:IsCity()
			local isDistrict	= plot:GetDistrictType() >= 0
			local isWonder		= plot:GetWonderType() >= 0
			local isPark		= plot:IsNationalPark()

			-- Check if it's a district or wonder, and set the type to 2 if so, otherwise it's a 1
			if isCity then
				plot:SetProperty("RouteSubType", 1)
			elseif isDistrict or isWonder then
				--print("  - Route has district or wonder, subtype => 2")
				plot:SetProperty("RouteSubType", 2)
			elseif isPark then
				--print("  - Route has park, subtype => 3")
				plot:SetProperty("RouteSubType", 3)
			else
				-- Assume it's added by a trader, so is a primary route
				--print("  - Defaulting to primary route")
				plot:SetProperty("RouteSubType", 1)
			end
		end

		local subType = plot:GetProperty("RouteSubType")

		-- Don't need to modify railroads
		if subType >= 1 then
			local owner = plot:GetOwner()
			if owner >= 0 then
				local newType = GetRouteTypeFromSubtype(Players[owner], subType)
				if newType ~= routeType then
					RouteBuilder.SetRouteType(plot, newType)
				end
			end
		end
	end
end

Events.LoadComplete.Add(
	function()
		Events.UnitMoved.Add(OnUnitMoved);
		Events.RouteAddedToMap.Add(OnRouteAdded);

		if Connect_Improvements then
			print("Connect Improvements ENABLED")
			Events.ImprovementAddedToMap.Add(OnImprovementAdded);
		end

		if Connect_Districts then
			print("Connect Districts ENABLED")
			Events.DistrictBuildProgressChanged.Add(OnDistrictBuildProgressChanged)
		end

		if Connect_Cities then
			print("Connect Cities ENABLED")
			Events.CityAddedToMap.Add(OnCityAdded)
		end
	end
)

-- #endregion

-- ===========================================================================
-- #region Utitity functions: Routebuilding
-- ===========================================================================

-- ===========================================================================
-- Utitity function: A* Pathfinding Algorithm
-- Author: Nightemaire
------------------------------------------------------------------------------
-- Overview:
-- This implementation follows the basic A* algorithm. Two lists of tiles are
-- populated and a simple heuristic calculated based on the distance and
-- move cost of the tile to the destination.
-- ===========================================================================
local debug_pathfinding = false
function print_if_debugging(text)
	if debug_pathfinding then
		print(text)
	end
end
-- Searches for the fastest route over land from start to end within a specified range
-- Returns a table of the plots (in reverse order) as well as the total move cost
function GetLandRoute(startPlot : object, endPlot : object, range)
	-- Take care of a few simple cases first
	if startPlot:IsWater() or endPlot:IsWater() then
		print_if_debugging("One of the tiles in the route is water...")
		return {}, 99999;
	end
	if startPlot:GetIndex() == endPlot:GetIndex() then
		print_if_debugging("Start and end plots are the same...why are you trying to find a path?")
		return {startPlot}, 0
	end
	minDist = Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), endPlot:GetX(), endPlot:GetY())
	if minDist <= 1 then
		print_if_debugging("Start and end plots are adjacent...pretty simple one here...")
		return {endPlot, startPlot}, 1
	end
	if minDist > range then
		print_if_debugging("Plots are too far from one another (specified range: "..range..")")
		return {}, 99999;
	end

	-- Okay, the path isn't so simple after all	
	print_if_debugging("Routing from <"..startPlot:GetX()..","..startPlot:GetY().."> to <"..endPlot:GetX()..","..endPlot:GetY()..">");
	local fastestPath = {}
	local totalMoveCost = 99999
	
	-- Local tables for storing plots
	local OpenList = {}
	local ClosedList = {}

	-- A* ALGORITHM HELPER FUNCTIONS --
	-- Adds a plot to the OpenList and calculates its G, H, and F values
	local function OpenPlot(currPlot : object, initialCost, bIsStart, bIsAcrossRiver)
		local G = 0
		local H = Map.GetPlotDistance(currPlot:GetX(), currPlot:GetY(), endPlot:GetX(), endPlot:GetY())

		-- If it's not the starting plot, we care about the movement cost
		if not(bIsStart) then
			G = initialCost + currPlot:GetMovementCost()
			if bIsAcrossRiver then
				G = G + 1
			end
		end
		
		local F = G + H

		if currPlot ~= nil then
			plotID = currPlot:GetIndex()

			OpenList[plotID] = {}
			OpenList[plotID].plot = currPlot
			OpenList[plotID].G = G
			OpenList[plotID].H = H
			OpenList[plotID].F = F

			--print("Opened plot "..plotID.."// G: "..G.."// H: "..H.."// F: "..F);
		else
			print("Why'd you try to add a nil plot to the open list?");
		end
	end

	-- Updates a plot in the OpenList if the newCost results in a lower F value
	local function UpdatePlot(plot : object, newCost, bIsAcrossRiver)
		-- See if the plot exists in the open list, but not the closed list
		if OpenList[plot:GetIndex()] ~= nil  and ClosedList[plot:GetIndex()] == nil then
			local oldF = OpenList[plot:GetIndex()].F
			local newCost = newCost + plot:GetMovementCost()
			if bIsAcrossRiver then
				newCost = newCost + 1
			end
			local newF = newCost + OpenList[plot:GetIndex()].H

			if newF < oldF then
				OpenList[plot:GetIndex()].G = newCost
				OpenList[plot:GetIndex()].F = newF
			end
		end
	end

	-- Closes out a plot and adds or updates each valid adjacent plot to the OpenList
	local function ClosePlot(plot : object)
		local thisID = plot:GetIndex()
		local thisEntry = OpenList[thisID]
		local thisCost = thisEntry.G

		-- Remove from the OpenList, and add to the ClosedList
		OpenList[thisID] = nil
		ClosedList[thisID] = thisEntry
		--print("Closed plot "..thisID)

		-- Iterate over all adjacent plots
		for i = 0, 5 do
			local adjPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i)
			--print("Checking adjacent plot "..adjPlot:GetIndex())

			-- Check to see if we cross a river, and if we even care
			local crossesRiver = plot:IsRiverCrossingToPlot(adjPlot) and Minimize_River_Crossings

			if adjPlot ~= nil then
				-- Check if the plot is not water, impassable, or already closed
				local dist = Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), adjPlot:GetX(), adjPlot:GetY())
				local validPlot = not(adjPlot:IsImpassable()) and not(adjPlot:IsWater())
				local canOpen = validPlot and ClosedList[adjPlot:GetIndex()] == nil and dist <= range

				if canOpen then
					if OpenList[adjPlot:GetIndex()] == nil then
						-- Plot is not in the open list, add it
						OpenPlot(adjPlot, thisCost, false, crossesRiver)
					else
						-- Plot is in the open list, update it
						UpdatePlot(adjPlot, thisCost, crossesRiver)
					end
				end
			end
		end
	end

	-- Returns the plot in the OpenList with the lowest F value
	local function GetNextPlot()
		local Fmin = 99999
		local Gmin = -1
		local nextEntry = nil
		for k,entry in orderedPairs(OpenList) do
			--print("Evaluating open list item "..k)
			--if entry.F < Fmin and entry.G > Gmax then
			if entry.F < Fmin then
				Fmin = entry.F
				nextEntry = entry
			end
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
	OpenPlot(startPlot, 0, true)
		
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
		end
	end

	local routeComplete = false
	-- Backtrack to find the route
	if routeFound then
		local backtracking = true
		local currPlot = endPlot
		local maxIterations = 1000
		local thisIteration = 0

		print_if_debugging("Initiating backtrack...")
		while backtracking do
			thisIteration = thisIteration + 1
			local costMin = 99999
			local nextPlot = nil

			-- iterate over all adjacent plots to find the lowest F cost
			--print("Checking adjacent plots... i = "..thisIteration)
			for i = 0, 5 do
				local adjPlot = Map.GetAdjacentPlot(currPlot:GetX(), currPlot:GetY(), i)				
				
				if adjPlot ~= nil then
					-- Check if the plot is closed
					local entry = ClosedList[adjPlot:GetIndex()]
					if entry ~= nil then
						--print ("Found a closed neighbor")
						-- if it is, we see whether it's the lowest G cost
						local thisCost = entry.G
						if thisCost < costMin then
							-- if it is, store it
							costMin = thisCost
							nextPlot = adjPlot
						end
					end
				end
			end

			-- if we found a plot, then add it and set it as the 
			if nextPlot ~= nil then
				-- add the plot to the fastest path
				table.insert(fastestPath, nextPlot)

				if nextPlot:GetIndex() == startPlot:GetIndex() then 
					-- if we're back at the beginning, end the loop
					backtracking = false
					routeComplete = true
				else
					-- otherwise update the current plot
					currPlot = nextPlot
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
			totalMoveCost = ClosedList[endPlot:GetIndex()].G
			print_if_debugging("Path Complete! Cost = "..totalMoveCost)
		else
			print("ERROR: Route wasn't completed")
			fastestPath = {}
			totalMoveCost = 9999999
		end
	end

	return fastestPath, totalMoveCost
end

-- ===========================================================================

function GetAllRoutesInRange(startPlot : object, range)
	local routePlots = {}

	for pAdjacencyPlot in PlotAreaSpiralIterator(startPlot, range, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
        if pAdjacencyPlot:IsRoute() then
			table.insert(routePlots, pAdjacencyPlot)
        end
    end
	
	return routePlots
end

function ConnectToNearestRouteOfOwner(startPlot : object, range, routeSubType)
	
	local owningPlayer = startPlot:GetOwner()

	if notNilOrNegative(owningPlayer) then
		-- The starting tile has an owner, proceed
		local routesInRange = GetAllRoutesInRange(startPlot, range)
		
		-- If we found some routes
		if #(routesInRange) > 0 then 
			local minCost = 99999
			local fastPath = nil

			for k,routePlot in pairs(routesInRange) do
				if routePlot:GetOwner() == owningPlayer then
					local path, cost = GetLandRoute(startPlot, routePlot, range)
					if (#(path) > 0 and cost < minCost) then
						fastPath = path 
						minCost = cost
					end
				end
			end
			if fastPath ~= nil then
				for k, tile in pairs(fastPath) do
					CreateRoadAt(tile, nil, routeSubType)
				end
			else
				print("No connections could be made :/")
			end
		else
			print("No nearby routes were found to connect :(")
		end
	else
		print("The plot you tried to connect to isn't owned...")
	end
end

function ConnectToNearestRoute(startPlot : object, range, routeSubType)
	local routesInRange = GetAllRoutesInRange(startPlot, range)

	local minCost = 99999
	local fastPath = nil
	if #routesInRange > 0 then 
		for k,routePlot in pairs(routesInRange) do
			local path, cost = GetLandRoute(startPlot, routePlot, range)
			if (#(path) > 0 and cost < minCost) then
				fastPath = path 
				minCost = cost
			end
		end
		if fastPath ~= nil then
			for k, tile in pairs(fastPath) do
				CreateRoadAt(tile, nil, routeSubType)
			end
		else
			print("No connections could be made :/")
		end
	else
		print("No nearby routes were found to connect :(")
	end
end

function CreateRouteFromTo(fromPlot : object, toPlot : object, subType)
	local path, cost = GetLandRoute(fromPlot, toPlot, 99)
	if path ~= nil then
		for k, tile in pairs(path) do
			CreateRoadAt(tile, nil, subType)
		end
	else
		print("No connections could be made :/")
	end
end

function CreateRailroadAt(plot:object)
	if plot ~= nil then
		if not(plot:IsWater()) and not(plot:IsImpassable()) then
			plot:SetProperty("RouteSubType", 0)
			RouteBuilder.SetRouteType(plot, i_Railroad)
		end
	end
end

function CreateRoadAt(plot : object, routeType, subType)
	if plot ~= nil then
		if not(plot:IsWater()) and not(plot:IsImpassable()) then
			if routeType ~= i_Railroad then
				if subType == nil or subType < 0 then subType = 1; end
				local bMakeRoute = true

				-- check to see if there's already a sub type
				local currSubType = plot:GetProperty("RouteSubType")
				if currSubType ~= nil then
					if currSubType == 0 then
						-- this is a railroad, do nothing
						bMakeRoute = false
					elseif subType < currSubType then
						-- Update the sub type if the new value is lower than current
						plot:SetProperty("RouteSubType", subType)
					end
				else
					-- else it has no sub type, so set it
					plot:SetProperty("RouteSubType", subType)
				end

				local owner = plot:GetOwner()
		
				-- If no route type is given we need to pick one
				if routeType == nil or routeType < 0 then
					-- Default to Ancient Roads
					routeType = i_AncientRoad

					-- If owned by a player, then use their current level
					if owner >= 0 then
						local player = Players[owner];
						routeType = GetRouteTypeFromSubtype(player, subType)
					end
				end
				if bMakeRoute then
					RouteBuilder.SetRouteType(plot, routeType)
				end
			else
				-- Always make a railroad if requested
				CreateRailroadAt(plot)
			end
		else
			print("Road was water or impassable at <"..plot:GetX()..","..plot:GetY()..">")
		end
	else
		print("Tried to make a road, but the plot was nil at <"..plot:GetX()..","..plot:GetY()..">")
	end
end

function GetRouteTypeFromSubtype(player : object, subtype)
	-- Always return a railroad if subtype is 0
	if subtype == 0 then return i_Railroad; end

	local playerEra = player:GetEra()
	if playerEra == nil or playerEra < 0 then playerEra = Game.GetEras().GetCurrentEra(); end
	local era = GameInfo.Eras[playerEra].Index;

	local route = GetRouteForEraAndSubtype(era, subtype)

	return route;
end

-- This function adapted from the "City Roads" mod by AOM
function GetRouteTypeForPlayer(player : object)
	local route = nil;
	local playerEra = player:GetEra()
	if playerEra == nil or playerEra < 0 then playerEra = Game.GetEras().GetCurrentEra(); end
	local era = GameInfo.Eras[playerEra];
	for routeType in GameInfo.Routes() do 
		if route == nil then
			route = routeType;
		else
			local prereq_era = GameInfo.Eras[routeType.PrereqEra];
			if prereq_era and era.ChronologyIndex >= prereq_era.ChronologyIndex  then
				route = routeType;
			end
		end
	end
	return route.Index;
end

function GetRouteForEraAndSubtype(era, subtype)
	if subtype == nil then subtype = 1; end

	local route = -1

	if era == 0 then
		route = i_AncientRoad
	elseif era == 1 then
		if subtype <= 1 then
			route = i_MedievalRoad
		else
			route = i_AncientRoad
		end
	elseif era == 2 then
		if subtype <= 2 then
			route = i_MedievalRoad
		else
			route = i_AncientRoad
		end
	elseif era == 3 then
		if subtype <= 3 then
			route = i_MedievalRoad
		else
			route = i_AncientRoad
		end
	elseif era == 4 then
		if subtype <= 1 then
			route = i_IndustrialRoad
		elseif subtype <= 2 then
			route = i_MedievalRoad
		else
			route = i_AncientRoad
		end
	elseif era == 5 then
		if subtype <= 2 then
			route = i_IndustrialRoad
		elseif subtype <= 3 then
			route = i_MedievalRoad
		else
			route = i_AncientRoad
		end
	elseif era == 6 then
		if subtype <= 1 then
			route = i_ModernRoad
		elseif subtype <= 2 then
			route = i_IndustrialRoad
		else
			route = i_MedievalRoad
		end
	elseif era == 7 then
		if subtype <= 2 then
			route = i_ModernRoad
		elseif subtype <= 3 then
			route = i_IndustrialRoad
		else
			route = i_MedievalRoad
		end
	elseif era >= 8 then
		if subtype <= 1 then
			route = i_Railroad
		elseif subtype <= 3 then
			route = i_ModernRoad
		else
			route = i_IndustrialRoad
		end
	else
		route = i_ModernRoad
	end

	return route
end

function AdjustRoadsBySubType(city)
	local owner = city:GetOwner()
	for k,plot in pairs(city:GetOwnedPlots()) do

		local PlotRoute = plot:GetRouteType()

		if notNilOrNegative(PlotRoute) then

			local subType = plot:GetProperty("RouteSubType")
			if subType == nil then subType = 1; end

			-- Don't need to modify railroads
			if subType > 0 and PlotRoute ~= i_Railroad then
				newType = GetRouteTypeFromSubtype(owner, subType)
				
				if newType > 0 then
					RouteBuilder.SetRouteType(plot, newType)
				end
			end
		end
	end
end

-- #endregion

-- ===========================================================================
-- #region Utitity functions: City Management
-- ===========================================================================

-- Utitity function: find any city in a range
function AnyCityWithinXTiles(iTargetDist, iX, iY)

	local aPlayers = PlayerManager.GetAliveMajors();
	for loop, pPlayer in ipairs(aPlayers) do
		local pPlayerCities:table = pPlayer:GetCities();
		for i, pLoopCity in pPlayerCities:Members() do
			local iDistance = Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY());
			if (iDistance <= iTargetDist) then
				return true;
			end
		end
	end
	return false;
end

-- Utitity function: find any city in a range
function AllCitiesWithinXTiles(iTargetDist, iX, iY)
	local allCities = {}
	local aPlayers = PlayerManager.GetAliveMajors();
	for loop, pPlayer in ipairs(aPlayers) do
		local pPlayerCities:table = pPlayer:GetCities();
		for i, pLoopCity in pPlayerCities:Members() do
			local iDistance = Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY());
			if (iDistance <= iTargetDist) then
				table.insert(allCities, pLoopCity)
			end
		end
	end
	return allCities;
end

-- Utitity function: find any city in a range
function AllOwnedDistrictsWithinXTiles(range, iX, iY)
	local pPlot = Map.GetPlot(iX, iY)
	local pOwner = pPlot:GetOwner()
	local allDistrictPlots = {}

	if pOwner >= 0 then
		for pAdjacencyPlot in PlotAreaSpiralIterator(pPlot, range, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
			if pAdjacencyPlot:GetDistrictID() >= 0 and pAdjacencyPlot:GetOwner() == pOwner then
				table.insert(allDistrictPlots, pAdjacencyPlot)
			end
		end
	end
	return allDistrictPlots;
end

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
	local cities = Players[playerID]:GetCities();
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
	return Players[playerID]:GetCities():FindID(cityID);
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

function tprint(tbl, indent)
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

function getPlayer(playerID)
	return PlayerManager.GetPlayer(playerID)
end

--
-- Plot Iterator, Author: whoward69; URL: https://forums.civfanatics.com/threads/border-and-area-plot-iterators.474634/
    -- convert funcs odd-r offset to axial. URL: http://www.redblobgames.com/grids/hexagons/
    -- here grid == offset, hex == axial
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
-- #endregion --------------------


--print("Config dump:")
--tprint(ER_Config)

print("ROUTES ENHANCED");