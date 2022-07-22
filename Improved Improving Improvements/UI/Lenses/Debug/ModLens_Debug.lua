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
print("Initializing Debug Lens UI Script");
-- ===========================================================================
-- Constants
-- ===========================================================================
print("Initializing Terrain Area Lens UI Script");

local ColorGradient = {}
ColorGradient[1]			= UI.GetColorValue("DEFAULT_COLOR_GRADIENT_1")
ColorGradient[2]			= UI.GetColorValue("DEFAULT_COLOR_GRADIENT_2")
ColorGradient[3]			= UI.GetColorValue("DEFAULT_COLOR_GRADIENT_3")
ColorGradient[4]			= UI.GetColorValue("DEFAULT_COLOR_GRADIENT_4")
ColorGradient[5]			= UI.GetColorValue("DEFAULT_COLOR_GRADIENT_5")

local AREA_LENS_NAME = "AREA_LENS"

local AREA_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

local areaColorTable = {}

-- ===========================================================================
-- Exported functions
-- ===========================================================================

local function OnGetAreaPlotTable()
	local colorPlot:table = {}

	local mapWidth, mapHeight = Map.GetGridSize()

	-- iterate over all hexes
	for i = 0, (mapWidth * mapHeight) - 1, 1 do

        local plot:table = Map.GetPlotByIndex(i)

		-- get the area and check if there's an entry in the color table for it
        local area = plot:GetAreaID()
		local thisColor = areaColorTable[area]

		-- if not, make one
		if thisColor == nil then
			local R = math.random(50,100)/100
			local G = math.random(50,100)/100
			local B = math.random(50,100)/100
			thisColor = UI.GetColorValue(R, G, B,0.5)
			print("New area is: "..area.."   applying color <"..R..","..G..","..B..">")
			areaColorTable[area] = thisColor
			colorPlot[thisColor] = {}
		end

		table.insert(colorPlot[thisColor], plot:GetIndex())
    end

	--print("There are "..#areaColorTable.." areas on the map")
	for k,v in ipairs(areaColorTable) do
		print("Area "..k.." has "..#v.." tiles in it")
	end

    return colorPlot
end

-- ===========================================================================
--  Init
-- ===========================================================================

local AreaLensEntry = {
	LensButtonText = "LOC_HUD_AREA_LENS",
	LensButtonTooltip = "LOC_HUD_AREA_LENS_TOOLTIP",
	Initialize = nil,
	GetColorPlotTable = OnGetAreaPlotTable
};

AreaLensLegend = {
	{"Nothing",		AncientRoadColor}
}

-- minimappanel.lua
if g_ModLenses ~= nil then
	g_ModLenses[AREA_LENS_NAME] = AreaLensEntry
end

-- modallenspanel.lua
if g_ModLensModalPanel ~= nil then
	g_ModLensModalPanel[AREA_LENS_NAME] = {}
    g_ModLensModalPanel[AREA_LENS_NAME].LensTextKey = "LOC_HUD_AREA_LENS"
    g_ModLensModalPanel[AREA_LENS_NAME].Legend = AreaLensLegend
end