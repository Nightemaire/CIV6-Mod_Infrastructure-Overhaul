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
include "AutoImprovements_Config.lua";

--print("Initializing Utilization Lens UI Script");
-- ===========================================================================
-- Constants
-- ===========================================================================
local ColorGradient = {}
ColorGradient[1]			= UI.GetColorValue("COLOR_UTIL_GRADIENT_1")
ColorGradient[2]			= UI.GetColorValue("COLOR_UTIL_GRADIENT_2")
ColorGradient[3]			= UI.GetColorValue("COLOR_UTIL_GRADIENT_3")
ColorGradient[4]			= UI.GetColorValue("COLOR_UTIL_GRADIENT_4")
ColorGradient[5]			= UI.GetColorValue("COLOR_UTIL_GRADIENT_5")

local ImprovementColor		= UI.GetColorValue("COLOR_UTIL_IMPROVEMENT")
local CityColor				= UI.GetColorValue("COLOR_UTIL_CITY")

local UTIL_LENS_NAME = "UTIL_LENS"
local GROWTH_LENS_NAME = "GROWTH_LENS"

local UTILIZATION_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")
local GROWTH_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetUtilPlotTable()
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
	colorPlot[ImprovementColor] = {}
	colorPlot[CityColor] = {}

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
					local util = plot:GetProperty("PLOT_UTILIZATION")
					if util == nil then util = 0; end
					
					thold = 100;
					if AutoImproveThreshold ~= nil then thold = AutoImproveThreshold; end

					local percentUtil = math.floor((util*100)/thold)

					local index = math.floor(percentUtil/20) + 1
					if index < 1 then index = 1; end
					if index > 5 then index = 5; end
					
					table.insert(colorPlot[ColorGradient[index]], plot:GetIndex())
				end
            end
        end
    end

    return colorPlot
end

local function OnGetGrowthPlotTable()
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

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) then
            if plot:GetOwner() == localPlayer then
                if plot:IsCity() then
					table.insert(colorPlot[CityColor], plot:GetIndex())
				else
					local index = 1
					
					local growth = plot:GetProperty("PLOT_UTIL_GROWTH")
					if growth == nil then 
						growth = 0
					else
						growth = growth / UtilizationScalar;
					end

					if growth < 0 then
						index = 1
					elseif growth == 0 then
						index = 2
					elseif growth < 4 then
						index = 3
					elseif growth < 8 then
						index = 4
					else
						index = 5
					end

					table.insert(colorPlot[ColorGradient[index]], plot:GetIndex())
				end
            end
        end
    end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================

local UtilizationLensEntry = {
	LensButtonText = "LOC_HUD_UTILIZATION_LENS",
	LensButtonTooltip = "LOC_HUD_UTILIZATION_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetUtilPlotTable
};

local GrowthLensEntry = {
	LensButtonText = "LOC_HUD_GROWTH_LENS",
	LensButtonTooltip = "LOC_HUD_GROWTH_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetGrowthPlotTable
};

UtilizationLensLegend = {
    {"LOC_TOOLTIP_UTILIZATION_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_UTILIZATION_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_UTILIZATION_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_UTILIZATION_HIGH",			ColorGradient[4]},
    {"LOC_TOOLTIP_UTILIZATION_HIGHEST",			ColorGradient[5]},
	{"LOC_TOOLTIP_UTILIZATION_IMPROVEMENT",		ImprovementColor},
	{"LOC_TOOLTIP_UTILIZATION_CITY",			CityColor},
}

GrowthLensLegend = {
    {"LOC_TOOLTIP_GROWTH_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_GROWTH_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_GROWTH_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_GROWTH_HIGH",				ColorGradient[4]},
    {"LOC_TOOLTIP_GROWTH_HIGHEST",			ColorGradient[5]},
	{"LOC_TOOLTIP_UTILIZATION_IMPROVEMENT",		ImprovementColor},
	{"LOC_TOOLTIP_UTILIZATION_CITY",			CityColor},
}

-- minimappanel.lua
if g_ModLenses ~= nil then
    g_ModLenses[UTIL_LENS_NAME] = UtilizationLensEntry
	g_ModLenses[GROWTH_LENS_NAME] = GrowthLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
    g_ModLensModalPanel[UTIL_LENS_NAME] = {}
    g_ModLensModalPanel[UTIL_LENS_NAME].LensTextKey = "LOC_HUD_UTILIZATION_LENS"
    g_ModLensModalPanel[UTIL_LENS_NAME].Legend = UtilizationLensLegend

	g_ModLensModalPanel[GROWTH_LENS_NAME] = {}
    g_ModLensModalPanel[GROWTH_LENS_NAME].LensTextKey = "LOC_HUD_GROWTH_LENS"
    g_ModLensModalPanel[GROWTH_LENS_NAME].Legend = GrowthLensLegend
end