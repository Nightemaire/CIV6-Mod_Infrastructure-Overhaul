-- Automation Utilities
-- Author: Multiple
-- DateCreated: 7/11/2022 09:27:34
--------------------------------------------------------------

-- ===========================================================================
-- Utitity functions: Routebuilding
-- ===========================================================================
-- Route Types
local i_AncientRoad = GameInfo.Routes["ROUTE_ANCIENT_ROAD"].Index;
local i_MedievalRoad = GameInfo.Routes["ROUTE_MEDIEVAL_ROAD"].Index;
local i_IndustrialRoad = GameInfo.Routes["ROUTE_INDUSTRIAL_ROAD"].Index;
local i_ModernRoad = GameInfo.Routes["ROUTE_MODERN_ROAD"].Index;
local i_Railroad = GameInfo.Routes["ROUTE_RAILROAD"].Index;

function FindFastestLandRoute(startPlot : object, endPlot : object, range)
	local fastestPath = {}
	local totalMoveCost = -1

	local searching = true
	local OpenList = {}
	local ClosedList = {}

	-- A* Pathfinding Functions
	function OpenPlot(plot : object, initialCost)
		local G = 0
		local H = Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), endPlot:GetX(), endPlot:GetY())
		local F = G + H

		if plot:GetID() ~= startPlot:GetID() then
			G = initialCost + plot:GetMovementCost()
		end

		OpenList[plot:GetID()] = {
			"plot"	= plot,
			"G"		= G,
			"H"		= H,
			"F"		= F
		}
	end
	function UpdatePlot(plot : object, newCost)
		-- See if the plot exists in the open list, but not the closed list
		if OpenList[plot:GetID()] ~= nil  and ClosedList[plot:GetID()] == nil then
			local oldF = OpenList[plot:GetID()].F
			local newCost = newCost + plot:GetMovementCost()
			local newF = newCost + OpenList[plot:GetID()].H

			if newF < oldF then
				OpenList[plot:GetID()].G = newCost
				OpenList[plot:GetID()].F = newF
			end
		end
	end
	function ClosePlot(plot : object)
		local thisID = plot:GetID()
		local thisEntry = OpenList[thisID]
		local thisCost = thisEntry.G

		OpenList[thisID] = nil
		ClosedList[thisID] = thisEntry

		for i = 0, 5 do
			adjPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i)
			-- Check if the plot is not water, impassable, or already closed
			local dist = Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), endPlot:GetX(), endPlot:GetY())
			local validPlot = not(adjPlot:IsImpassable()) and not(adjPlot:IsWater())

			if validPlot and ClosedList[adjPlot:GetID()] == nil and dist <= range then
				if OpenList[adjPlot:GetID()] == nil then
					-- Plot is not in the open list, add it
					OpenPlot(adjPlot, thisCost)
				else
					-- Plot is in the open list, update it
					UpdatePlot(adjPlot, thisCost)
				end
			end
		end
	end
	function GetNextPlot()
		local Fmin = 99999
		local Gmax = 0
		local nextEntry = nil
		for entry in OpenList do
			if entry.F < Fmin and entry.G > Gmax then
				nextEntry = entry
			end
		end

		local nextPlot = nil
		if nextEntry ~= nil then
			nextPlot = nextEntry.plot
		end
			
		return nextPlot
	end

	-- Initialize the algorithm to our starting location
	OpenPlot(startPlot, 0)

	local routeFound = false
	-- Iterate towards the destination
	while searching do
		local next = GetNextPlot()
		if next ~= nil then
			ClosePlot(next)
		
			if next:GetID() == endPlot:GetID() then
				routeFound = true
				searching = false
			end
		else
			-- ran out of plots to check, no route is available
			searching = false
		end
	end

	if routeFound then
		-- Backtrack to find the route
		local backtracking = true
		local pathPlot = endPlot
		while backtracking do
			for i = 0, 5 do
				adjPlot = Map.GetAdjacentPlot(pathPlot:GetX(), pathPlot:GetY(), i)
				local costMin = 99999
				-- Check if the plot is closed
				if ClosedList[adjPlot:GetID()] ~= nil then
					-- if it is, we see whether it's the lowest movement cost
					if ClosedList[adjPlot:GetID()].G < costMin then
						-- if it is, add it to the path
						table.insert(fastestPath, adjPlot)
						-- update the next plot to check
						pathPlot = adjPlot
					end
				end
			end
			-- if we're back at the beginning, end the loop
			if pathPlot:GetID() == startPlot:GetID() then backtracking = false; end	
		end

		totalMoveCost = ClosedList[endPlot:GetID()].G
	end

	return fastestPath, totalMoveCost
end

function GetAllRoutesInRange(startPlot : object, range)
	local routePlots = {}

	for pAdjacencyPlot in PlotAreaSpiralIterator(startPlot, range, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
        if pPlot:IsRoute() then
			table.insert(routePlots, pAdjacencyPlot)
        end
    end

	return routePlots
end

function ConnectToNearestRoute(startPlot : object, range, routeSubType)
	local routesInRange = GetAllRoutesInRange(startPlot, range)

	local minCost = 99999
	local fastPath = nil
	for routePlot in routesInRange do
		local path, cost = FindFastestLandRoute(startPlot, routePlot, range)
		if cost < minCost then
			fastPath = path 
		end
	end
	for tile in fastPath do
		CreateRoadAt(tile, 3)
	end
end

function CreateRoadAt(plot : object, routeType, subType)
	if plot ~= nil then
		if not(plot:IsWater()) and not(plot:IsImpassable()) then
			local owner = plot:GetOwner()
		
			-- If no route type is given we need to pick one
			if routeType == nil or routeType < 0 then
				-- Default to Ancient Roads
				routeType = i_AncientRoad

				-- If owned by a player, then use their current level
				if owner >= 0 then
					local player = Players[owner];
					routeType = GetRouteTypeForPlayer(player)
				end
			end

			if subType == nil or subType < 0 then subType = 1; end
			printIfPlayer(1, "Adding a route at <"..plot:GetX()..","..plot:GetY()..">, subType: "..subType)
			plot:SetProperty("RouteSubType", subType)
			RouteBuilder.SetRouteType(plot, routeType)
		else
			print("Road was water or impassable at <"..plot:GetX()..","..plot:GetY()..">")
		end
	else
		print("Tried to make a road, but the plot was nil, water, or impassable.")
	end
end

-- This function adapted from the "City Roads" mod by AOM
function GetRouteTypeFromSubtype(player, subtype)
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

-- This function adapted from the "City Roads" mod by AOM
function GetRouteTypeForPlayer(player)
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

function GetRouteForSubtype(PrimaryRouteLevel, subType)
	if subType == nil or subType == 1 then return PrimaryRouteLevel; end

	local newType = -1

	if PrimaryRouteLevel == i_ModernRoad then
		if subType == 2 then
			newType = i_IndustrialRoad
		else
			newType = i_MedievalRoad
		end
	elseif PrimaryRouteLevel == i_IndustrialRoad then
		if subType == 2 then
			newType = i_MedievalRoad
		else
			newType = i_AncientRoad
		end
	elseif PrimaryRouteLevel == i_MedievalRoad then
		-- Only one other route type it could be...
		newType = i_AncientRoad
	else
		-- do nothing because we have ancient roads...how did we get here then?
		print("Not sure how you're seeing this, but good job!")
	end

	return newType
end

function AdjustRoadsBySubType(city, PrimaryRouteLevel)
	for k,plot in pairs(city:GetOwnedPlots()) do

		local PlotRoute = plot:GetRouteType()

		if notNilOrNegative(PlotRoute) then

			local subType = plot:GetProperty("RouteSubType")
			if subType == nil then subType = 1; end

			-- Don't need to modify railroads or routes with subType 1 (primary)
			if subType > 1 and PlotRoute ~= i_Railroad then
				newType = GetRouteForSubtype(PrimaryRouteLevel, subType)
				
				if newType > 0 then
					RouteBuilder.SetRouteType(plot, newType)
				end
			end
		end
	end
end

-- ===========================================================================
-- Utitity functions: City Management
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

-- ===========================================================================
-- Utitity functions: Player Management
-- ===========================================================================

function getPlayer(playerID)
	return PlayerManager.GetPlayer(playerID)
end


-- ===========================================================================
-- Utitity functions: Miscellaneous
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
