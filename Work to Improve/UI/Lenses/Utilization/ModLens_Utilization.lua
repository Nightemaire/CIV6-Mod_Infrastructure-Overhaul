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

local DEVELOPMENT_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")
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
        local pPlot = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
			if pPlot:IsCity() then
				table.insert(colorPlot[CityColor], pPlot:GetIndex())
			elseif pPlot:GetImprovementType() >= 0 then
				table.insert(colorPlot[ImprovementColor], pPlot:GetIndex())
			else
				local UI_Data = ExposedMembers.TileGrowth.UI_GetData("Development", pPlot);

				local percentUtil = math.floor((UI_Data[1]*100)/UI_Data[3])

				local index = math.floor(percentUtil/20) + 1
				if index < 1 then index = 1; end
				if index > 5 then index = 5; end
				
				table.insert(colorPlot[ColorGradient[index]], pPlot:GetIndex())
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
        local pPlot = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
			if pPlot:IsCity() then
				table.insert(colorPlot[CityColor], pPlot:GetIndex())
			else
				local index = 1
				
				local UI_Data = ExposedMembers.TileGrowth.UI_GetData("Development", pPlot);
				if growth == nil then growth = 0; end

				local dev_scalar = 100
				if WTI_Config.DevelopmentScalar ~= nil then dev_scalar = WTI_Config.DevelopmentScalar; end

				growth = UI_Data[2] / dev_scalar;

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

				table.insert(colorPlot[ColorGradient[index]], pPlot:GetIndex())
			end
        end
    end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================

local UtilizationLensEntry = {
	LensButtonText = "LOC_HUD_DEVELOPMENT_LENS",
	LensButtonTooltip = "LOC_HUD_DEVELOPMENT_LENS_TOOLTIP",
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
    {"LOC_TOOLTIP_DEVELOPMENT_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_DEVELOPMENT_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_DEVELOPMENT_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_DEVELOPMENT_HIGH",			ColorGradient[4]},
    {"LOC_TOOLTIP_DEVELOPMENT_HIGHEST",			ColorGradient[5]},
	{"LOC_TOOLTIP_DEVELOPMENT_IMPROVEMENT",		ImprovementColor},
	{"LOC_TOOLTIP_DEVELOPMENT_CITY",			CityColor},
}

GrowthLensLegend = {
    {"LOC_TOOLTIP_GROWTH_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_GROWTH_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_GROWTH_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_GROWTH_HIGH",				ColorGradient[4]},
    {"LOC_TOOLTIP_GROWTH_HIGHEST",			ColorGradient[5]},
	{"LOC_TOOLTIP_DEVELOPMENT_IMPROVEMENT",		ImprovementColor},
	{"LOC_TOOLTIP_DEVELOPMENT_CITY",			CityColor},
}

-- minimappanel.lua
if g_ModLenses ~= nil then
    g_ModLenses[UTIL_LENS_NAME] = UtilizationLensEntry
	g_ModLenses[GROWTH_LENS_NAME] = GrowthLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
    g_ModLensModalPanel[UTIL_LENS_NAME] = {}
    g_ModLensModalPanel[UTIL_LENS_NAME].LensTextKey = "LOC_HUD_DEVELOPMENT_LENS"
    g_ModLensModalPanel[UTIL_LENS_NAME].Legend = UtilizationLensLegend

	g_ModLensModalPanel[GROWTH_LENS_NAME] = {}
    g_ModLensModalPanel[GROWTH_LENS_NAME].LensTextKey = "LOC_HUD_GROWTH_LENS"
    g_ModLensModalPanel[GROWTH_LENS_NAME].Legend = GrowthLensLegend
end