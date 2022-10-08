-- ===========================================================================
-- UtilizationLensManager
-- Author: Nightemaire
-- DateCreated: 6/26/2022 11:36:00
--------------------------------------------------------------
-- Implementation of this lens adapted directly from the "More Lenses" mod
-- https://steamcommunity.com/sharedfiles/filedetails/?id=871712879
-- by Astog
--
-- ===========================================================================
include "OE_Main.lua";

print("Initializing Development Lens UI Script");
-- ===========================================================================
-- Constants
-- ===========================================================================
local ColorGradient = {}
ColorGradient[1]			= UI.GetColorValue("COLOR_POP_GRADIENT_1")
ColorGradient[2]			= UI.GetColorValue("COLOR_POP_GRADIENT_2")
ColorGradient[3]			= UI.GetColorValue("COLOR_POP_GRADIENT_3")
ColorGradient[4]			= UI.GetColorValue("COLOR_POP_GRADIENT_4")
ColorGradient[5]			= UI.GetColorValue("COLOR_POP_GRADIENT_5")

local ImprovementColor		= UI.GetColorValue("COLOR_POP_IMPROVEMENT")
local VillageColor			= UI.GetColorValue("COLOR_POP_VILLAGE")
local TownshipColor			= UI.GetColorValue("COLOR_POP_TOWNSHIP")
local CityColor				= UI.GetColorValue("COLOR_POP_CITY")
local MetroColor			= UI.GetColorValue("COLOR_POP_METROPOLIS")

local POP_LENS_NAME = "POPULATION_LENS"
local DEV_LENS_NAME = "DEVELOPMENT_LENS"

local POP_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")
local DEV_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetPopPlotTable()
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]
	local cities = pPlayer:GetCities();

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[ColorGradient[1]] = {}
	colorPlot[ColorGradient[2]] = {}
	colorPlot[ColorGradient[3]] = {}
	colorPlot[ColorGradient[4]] = {}
	colorPlot[ColorGradient[5]] = {}
	colorPlot[CityColor] = {}
	colorPlot[MetroColor] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) then
			if plot:GetProperty("CanHaveCity") ~= false then
				score = CalculateExpansionScore(plot, localPlayer)
				local tableIndex = ColorGradient[1]

				if score <= 4 then tableIndex = ColorGradient[1];
				elseif score <= 8 then tableIndex = ColorGradient[2];
				elseif score <= 12 then tableIndex = ColorGradient[3];
				elseif score <= 16 then tableIndex = ColorGradient[4];
				else tableIndex = ColorGradient[4]; end

				table.insert(colorPlot[tableIndex], plot:GetIndex())
			end
        end
    end

    return colorPlot
end

local function OnGetDevPlotTable()
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]
	local cities = pPlayer:GetCities();

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[ImprovementColor] = {}
	colorPlot[VillageColor] = {}
	colorPlot[TownshipColor] = {}
	colorPlot[CityColor] = {}
	colorPlot[MetroColor] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) then
            if plot:GetOwner() == localPlayer then
                if plot:IsCity() then
					table.insert(colorPlot[CityColor], plot:GetIndex())
				elseif plot:GetImprovementType() >= 0 then
					table.insert(colorPlot[ImprovementColor], plot:GetIndex())
				else
					
				end
            end
        end
    end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================

local PopLensEntry = {
	LensButtonText = "LOC_HUD_POPULATION_LENS",
	LensButtonTooltip = "LOC_HUD_POPULATION_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetPopPlotTable
};

local DevLensEntry = {
	LensButtonText = "LOC_HUD_DEVELOPMENT_LENS",
	LensButtonTooltip = "LOC_HUD_DEVELOPMENT_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetDevPlotTable
};

PopLensLegend = {
    {"LOC_TOOLTIP_POPULATION_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_POPULATION_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_POPULATION_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_POPULATION_HIGH",				ColorGradient[4]},
    {"LOC_TOOLTIP_POPULATION_HIGHEST",			ColorGradient[5]}
}

DevLensLegend = {
	{"LOC_TOOLTIP_DEVELOPMENT_IMPROVEMENT",		ImprovementColor},
    {"LOC_TOOLTIP_DEVELOPMENT_VILLAGE",			VillageColor},
	{"LOC_TOOLTIP_DEVELOPMENT_TOWNSHIP",		TownshipColor},
	{"LOC_TOOLTIP_DEVELOPMENT_CITY",			CityColor},
	{"LOC_TOOLTIP_DEVELOPMENT_METRO",			MetroColor}
}

-- minimappanel.lua
if g_ModLenses ~= nil then
    g_ModLenses[POP_LENS_NAME] = PopLensEntry
	--g_ModLenses[DEV_LENS_NAME] = DevLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
    g_ModLensModalPanel[POP_LENS_NAME] = {}
    g_ModLensModalPanel[POP_LENS_NAME].LensTextKey = "LOC_HUD_POPULATION_LENS"
    g_ModLensModalPanel[POP_LENS_NAME].Legend = PopLensLegend

	g_ModLensModalPanel[DEV_LENS_NAME] = {}
    g_ModLensModalPanel[DEV_LENS_NAME].LensTextKey = "LOC_HUD_DEVELOPMENT_LENS"
    g_ModLensModalPanel[DEV_LENS_NAME].Legend = DevLensLegend
end


function CalculateExpansionScore(plot : object, playerID : number)
	local player = Players[playerID]

	local plotX = plot:GetX()
	local plotY = plot:GetY()
	
	local score = plot:GetAppeal() + 3

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


