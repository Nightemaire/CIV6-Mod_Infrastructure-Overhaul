-- ===========================================================================
-- Lens Template
-- Author: Nightemaire
-- DateCreated: 6/26/2022 11:36:00
--------------------------------------------------------------
-- Implementation of this lens adapted directly from the "More Lenses" mod
-- https://steamcommunity.com/sharedfiles/filedetails/?id=871712879
-- by Astog
--
-- ===========================================================================
--print("Initializing Movecost Lens UI Script");
-- ===========================================================================
-- Constants
-- ===========================================================================
local ColorGradient = {}
ColorGradient[1]			= UI.GetColorValue("COLOR_MOVEMENT_GRADIENT_1")
ColorGradient[2]			= UI.GetColorValue("COLOR_MOVEMENT_GRADIENT_2")
ColorGradient[3]			= UI.GetColorValue("COLOR_MOVEMENT_GRADIENT_3")
ColorGradient[4]			= UI.GetColorValue("COLOR_MOVEMENT_GRADIENT_4")
ColorGradient[5]			= UI.GetColorValue("COLOR_MOVEMENT_GRADIENT_5")


-- ===========================================================================
-- Exported function
-- ===========================================================================
local function ExportPlotColorTable()
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

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local plot:table = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(plot:GetX(), plot:GetY()) then
		
            local cost = plot:GetMovementCost()
			if plot:IsImpassable() then
				table.insert(colorPlot[ColorGradient[1]], plot:GetIndex())
			elseif cost >= 3 then 
				table.insert(colorPlot[ColorGradient[2]], plot:GetIndex())
			elseif cost >= 2 then
				table.insert(colorPlot[ColorGradient[3]], plot:GetIndex())
			elseif cost >= 1 then
				table.insert(colorPlot[ColorGradient[4]], plot:GetIndex())
			else
				table.insert(colorPlot[ColorGradient[5]], plot:GetIndex())
			end
        end
    end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================
local THIS_LENS_NAME = "MOVECOST_LENS_NAME"

local LensEntry = {
	LensButtonText = "LOC_HUD_MOVECOST_LENS",
	LensButtonTooltip = "LOC_HUD_MOVECOST_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = ExportPlotColorTable
};

local LensLegend = {
    {"LOC_TOOLTIP_MOVECOST_LOWEST",			ColorGradient[1]},
    {"LOC_TOOLTIP_MOVECOST_LOW",			ColorGradient[2]},
    {"LOC_TOOLTIP_MOVECOST_MEDIUM",			ColorGradient[3]},
    {"LOC_TOOLTIP_MOVECOST_HIGH",			ColorGradient[4]},
    {"LOC_TOOLTIP_MOVECOST_HIGHEST",		ColorGradient[5]},
}

-- minimappanel.lua
if g_ModLenses ~= nil then
    g_ModLenses[THIS_LENS_NAME] = LensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
    g_ModLensModalPanel[THIS_LENS_NAME] = {}
    g_ModLensModalPanel[THIS_LENS_NAME].LensTextKey = LensEntry.LensButtonText
    g_ModLensModalPanel[THIS_LENS_NAME].Legend = LensLegend
end

print("Initialized "..THIS_LENS_NAME.." UI Script");