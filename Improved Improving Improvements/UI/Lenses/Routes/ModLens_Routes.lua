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
print("Initializing Route Lens UI Script");
-- ===========================================================================
-- Constants
-- ===========================================================================

local PillagedRoadColor		= UI.GetColorValue("COLOR_ROUTE_PILLAGED")
local AncientRoadColor		= UI.GetColorValue("COLOR_ROUTE_ANCIENT")
local MedievalRoadColor		= UI.GetColorValue("COLOR_ROUTE_MEDIEVAL")
local IndustrialRoadColor	= UI.GetColorValue("COLOR_ROUTE_INDUSTRIAL")
local ModernRoadColor		= UI.GetColorValue("COLOR_ROUTE_MODERN")
local RailroadColor			= UI.GetColorValue("COLOR_ROUTE_RAILROAD")

local ROUTES_LENS_NAME = "ROUTES_LENS"
local SUBTYPE_LENS_NAME = "SUBTYPE_LENS"

local ROUTES_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")
local SUBTYPE_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

local i_AncientRoad = GameInfo.Routes["ROUTE_ANCIENT_ROAD"].Index;
local i_MedievalRoad = GameInfo.Routes["ROUTE_MEDIEVAL_ROAD"].Index;
local i_IndustrialRoad = GameInfo.Routes["ROUTE_INDUSTRIAL_ROAD"].Index;
local i_ModernRoad = GameInfo.Routes["ROUTE_MODERN_ROAD"].Index;
local i_Railroad = GameInfo.Routes["ROUTE_RAILROAD"].Index;

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetRoutesPlotTable()
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]
	local cities = pPlayer:GetCities();

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[PillagedRoadColor] = {}
	colorPlot[AncientRoadColor] = {}
	colorPlot[MedievalRoadColor] = {}
	colorPlot[IndustrialRoadColor] = {}
	colorPlot[ModernRoadColor] = {}
	colorPlot[RailroadColor] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) and plot:IsRoute() then
            if plot:IsRoutePillaged() then
				table.insert(colorPlot[PillagedRoadColor], plot:GetIndex())
			else
				local type = plot:GetRouteType()

				if type == i_AncientRoad then
					table.insert(colorPlot[AncientRoadColor], plot:GetIndex())
				elseif type == i_MedievalRoad then
					table.insert(colorPlot[MedievalRoadColor], plot:GetIndex())
				elseif type == i_IndustrialRoad then
					table.insert(colorPlot[IndustrialRoadColor], plot:GetIndex())
				elseif type == i_ModernRoad then
					table.insert(colorPlot[ModernRoadColor], plot:GetIndex())
				elseif type == i_Railroad then
					table.insert(colorPlot[RailroadColor], plot:GetIndex())
				else
					print("Road type unknown")
				end
			end
        end
    end

    return colorPlot
end

local function OnGetSubtypePlotTable()
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]
	local cities = pPlayer:GetCities();

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[PillagedRoadColor] = {}
	colorPlot[AncientRoadColor] = {}
	colorPlot[MedievalRoadColor] = {}
	colorPlot[IndustrialRoadColor] = {}
	colorPlot[ModernRoadColor] = {}
	colorPlot[RailroadColor] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) and plot:IsRoute() then
			type = plot:GetProperty("RouteSubType")
			if type == nil then type = 1; end
			if type == 1 then
				table.insert(colorPlot[AncientRoadColor], plot:GetIndex())
			elseif type == 2 then
				table.insert(colorPlot[MedievalRoadColor], plot:GetIndex())
			elseif type == 3 then
				table.insert(colorPlot[IndustrialRoadColor], plot:GetIndex())
			elseif type == 4 then
				table.insert(colorPlot[ModernRoadColor], plot:GetIndex())
			elseif type == 5 then
				table.insert(colorPlot[RailroadColor], plot:GetIndex())
			else
				print("Road type unknown")
			end
        end
    end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================

local RoutesLensEntry = {
	LensButtonText = "LOC_HUD_ROUTES_LENS",
	LensButtonTooltip = "LOC_HUD_ROUTES_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetRoutesPlotTable
};

local SubtypeLensEntry = {
	LensButtonText = "LOC_HUD_SUBTYPE_LENS",
	LensButtonTooltip = "LOC_HUD_SUBTYPE_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetSubtypePlotTable
};

RoutesLensLegend = {
	{"LOC_TOOLTIP_LENS_ROUTE_ANCIENT",			AncientRoadColor},
    {"LOC_TOOLTIP_LENS_ROUTE_MEDIEVAL",			MedievalRoadColor},
	{"LOC_TOOLTIP_LENS_ROUTE_INDUSTRIAL",		IndustrialRoadColor},
	{"LOC_TOOLTIP_LENS_ROUTE_MODERN",			ModernRoadColor},
	{"LOC_TOOLTIP_LENS_ROUTE_RAILROAD",			RailroadColor},
	{"LOC_TOOLTIP_LENS_ROUTE_PILLAGED",			PillagedRoadColor}
}

SubtypeLensLegend = {
	{"LOC_TOOLTIP_LENS_SUBTYPE_PRIMARY",		AncientRoadColor},
    {"LOC_TOOLTIP_LENS_SUBTYPE_SECONDARY",		MedievalRoadColor},
	{"LOC_TOOLTIP_LENS_SUBTYPE_TERTIARY",		IndustrialRoadColor},
	{"LOC_TOOLTIP_LENS_SUBTYPE_OTHER",			ModernRoadColor}
}

-- minimappanel.lua
if g_ModLenses ~= nil then
	g_ModLenses[ROUTES_LENS_NAME] = RoutesLensEntry
	g_ModLenses[SUBTYPE_LENS_NAME] = SubtypeLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
	g_ModLensModalPanel[ROUTES_LENS_NAME] = {}
    g_ModLensModalPanel[ROUTES_LENS_NAME].LensTextKey = "LOC_HUD_ROUTES_LENS"
    g_ModLensModalPanel[ROUTES_LENS_NAME].Legend = RoutesLensLegend

	g_ModLensModalPanel[SUBTYPE_LENS_NAME] = {}
    g_ModLensModalPanel[SUBTYPE_LENS_NAME].LensTextKey = "LOC_HUD_SUBTYPE_LENS"
    g_ModLensModalPanel[SUBTYPE_LENS_NAME].Legend = SubtypeLensLegend
end