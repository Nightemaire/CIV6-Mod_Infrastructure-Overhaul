-- OE_Main
-- Author: Nightemaire
-- DateCreated: 7/31/2022 12:18:23
--------------------------------------------------------------
print("ORGANICALLY EXPANDING!!! 16:16");


local Unowned_routes = {}
local city_threshold = 20

local debug_city = false

-- ===========================================================================
-- Event Handling
-- ===========================================================================

function OnCityExpanded(owner, cityID)
	local player = Players[owner]
	local city = player:GetCities():FindID(cityID)
	print("Ownership changed for Player "..owner.." in "..Locale.Lookup(city:GetName()))

	local cityX = city:GetX()
	local cityY = city:GetY()
	local cityPlot = Map.GetPlot(cityX, cityY)

	local expandablePlots = {}

	print("Looking for expansion spots")
	for pAdjacencyPlot in PlotAreaSpiralIterator(cityPlot, 5, SECTOR_NONE, DIRECTION_CW, DIRECTION_IN, CENTRE_EXCLUDE) do
        local dist = Map.GetPlotDistance(cityX, cityY, pAdjacencyPlot:GetX(), pAdjacencyPlot:GetY())
		if dist <= 3 then
			break;
		end

		if not(pAdjacencyPlot:IsWater()) and not(pAdjacencyPlot:IsImpassable()) then
			local bCanHaveCity = pAdjacencyPlot:GetProperty("CanHaveCity")

			if bCanHaveCity == nil or bCanHaveCity == true then
				table.insert(expandablePlots, pAdjacencyPlot)
			end
		end
    end

	local maxScore = 0
	local bestPlot = nil
	if #(expandablePlots) > 0 then
	print("Picking the best spot!")
		for k,plot in pairs(expandablePlots) do
			local score = CalculateExpansionScore(plot, owner)
			if score > maxScore then
				bestPlot = plot
				maxScore = score
				--print("Score = "..score.."*")
			else
				--print("Score = "..score)
			end			
		end
	else
		print("No expandable plots found :(")
	end
	print("Max Score is: "..maxScore)
	if maxScore > city_threshold then
		print("Making a new city!")
		player:GetCities():Create(bestPlot:GetX(), bestPlot:GetY())
	end
end
Events.CityTileOwnershipChanged.Add(OnCityExpanded)

function OnCityAdded(playerID, cityID, iX, iY)
	--print("City Added")
	local city = Players[playerID]:GetCities():FindID(cityID)
	local cityPlot = Map.GetPlot(city:GetX(), city:GetY())
	for pAdjacencyPlot in PlotAreaSpiralIterator(cityPlot, 3, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_INCLUDE) do
		--print("Plot : "..pAdjacencyPlot:GetIndex())
        pAdjacencyPlot:SetProperty("CanHaveCity", false)
		if playerID == 0 and debug_city then
			WorldBuilder.CityManager():SetPlotOwner(pAdjacencyPlot, city);
		end
    end
end
Events.CityAddedToMap.Add(OnCityAdded)

function OnCityRemoved(playerID, cityID, iX, iY)
	print("City removed")
	if iX ~= nil then print("iX Not Nil!") end
	if iY ~= nil then print("iY Not Nil!") end
end
Events.CityRemovedFromMap.Add(OnCityRemoved)


-- ===========================================================================
-- Expansion Calculations
-- ===========================================================================
function CalculateExpansionScore(plot : object, playerID : number)
	local player = Players[playerID]

	local plotX = plot:GetX()
	local plotY = plot:GetY()
	
	local score = plot:GetAppeal()

	if plot:IsRoute() then
		score = score + 3
	end

	local nearby_pop_bonus = 0
	local nearbyCities = AllCitiesWithinXTiles(6, plotX, plotY)
	for k, city in pairs(nearbyCities) do
		if city:GetOwner() == playerID then
			local cityPop = city:GetPopulation()
			local borderDist = Map.GetPlotDistance(city:GetX(), city:GetY(), plotX, plotY) - 3
			local thisbonus = cityPop * (4-borderDist)
			nearby_pop_bonus = nearby_pop_bonus + thisbonus
		end
	end

	score = score + nearby_pop_bonus

	if plot:IsFreshWater() then
		score = score * 2
	else
		if plot:IsCoastalLand() or PlotCanHaveAqueduct(plot) then
			score = score * 1.5
		end
	end

	return score
end

function PlotCanHaveAqueduct(plot : object)

	if plot ~= nil then
		-- Check for adjacent freshwater plots
		for i = 0, 5 do
			local adjPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i)
			--print("Checking adjacent plot "..adjPlot:GetIndex())

			if adjPlot ~= nil then
				if adjPlot:IsFreshWater() then return true; end
			end
		end

		-- Check for mountains within 2 tiles
		for pAdjacencyPlot in PlotAreaSpiralIterator(plot, 2, SECTOR_NONE, DIRECTION_CW, DIRECTION_OUT, CENTRE_EXCLUDE) do
			if pAdjacencyPlot:IsMountain() then return true; end
		end
	end

	return false
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

-- Utitity function: find all cities in a range
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



print("Expansion complete!")