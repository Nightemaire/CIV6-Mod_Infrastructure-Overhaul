include("LensSupport")

local PANEL_OFFSET_Y:number = 32
local PANEL_OFFSET_X:number = -5

local LENS_NAME = "ML_GROWTH_PROPERTY"
local ML_LENS_LAYER = UILens.CreateLensLayerHash("Hex_Coloring_Appeal_Level")

local ColorGradient = {}
ColorGradient[1]			= UI.GetColorValue("COLOR_PROPERTY_GRADIENT_1")
ColorGradient[2]			= UI.GetColorValue("COLOR_PROPERTY_GRADIENT_2")
ColorGradient[3]			= UI.GetColorValue("COLOR_PROPERTY_GRADIENT_3")
ColorGradient[4]			= UI.GetColorValue("COLOR_PROPERTY_GRADIENT_4")
ColorGradient[5]			= UI.GetColorValue("COLOR_PROPERTY_GRADIENT_5")

-- ===========================================================================
--  Member Variables
-- ===========================================================================

local m_isOpen:boolean = false
local m_bonusResourcesToShow:table = {}

ParameterToShow = "Value"
CurrentPropertyID = ""

-- ===========================================================================
--  Exported functions
-- ===========================================================================
local function GetValuePlotTable(PropertyID)
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[ColorGradient[1]] = {}
	colorPlot[ColorGradient[2]] = {}
	colorPlot[ColorGradient[3]] = {}
	colorPlot[ColorGradient[4]] = {}
	colorPlot[ColorGradient[5]] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local pPlot = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
			local UI_Data = ExposedMembers.TileGrowth.UI_GetData(PropertyID, pPlot);

			local percentUtil = math.floor((UI_Data[1]*100)/UI_Data[3])

			local index = math.floor(percentUtil/20) + 1
			if index < 1 then index = 1; end
			if index > 5 then index = 5; end
			
			table.insert(colorPlot[ColorGradient[index]], pPlot:GetIndex())
        end
    end

    return colorPlot
end

local function GetGrowthPlotTable(PropertyID)
	local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]

    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local colorPlot:table = {}
	colorPlot[ColorGradient[1]] = {}
	colorPlot[ColorGradient[2]] = {}
	colorPlot[ColorGradient[3]] = {}
	colorPlot[ColorGradient[4]] = {}
	colorPlot[ColorGradient[5]] = {}

	local mapWidth, mapHeight = Map.GetGridSize()
	for i = 0, (mapWidth * mapHeight) - 1, 1 do
        local pPlot = Map.GetPlotByIndex(i)

        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
			
			local index = 1
			
			local UI_Data = ExposedMembers.TileGrowth.UI_GetData(PropertyID, pPlot);
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

    return colorPlot
end

function RefreshPropertyLens()
    -- Assuming city overlap lens is already applied
    UILens.ClearLayerHexes(ML_LENS_LAYER)
    SetGrowthPropertyLens()
end

function SetGrowthPropertyLens()
    -- print("Show Resource lens")
    local localPlayer:number = Game.GetLocalPlayer()

	local colorTable = {}
	if ParameterToShow == "Value" then
		colorTable = GetValuePlotTable(CurrentPropertyID)
	elseif ParameterToShow == "Growth" then
		colorTable = GetGrowthPlotTable(CurrentPropertyID)
	else
		print("Show what now? "..ParameterToShow)
	end

	for k,v in pairs(colorTable) do
		UILens.SetLayerHexesColoredArea( ML_LENS_LAYER, localPlayer, v, k )
	end
end

function RefreshPropertyPicker()
	print("Show Resource Picker")
    local mapWidth, mapHeight = Map.GetGridSize()
    local localPlayer:number = Game.GetLocalPlayer()
    local pPlayer:table = Players[localPlayer]
    local localPlayerVis:table = PlayersVisibility[localPlayer]

	local GrowthProperties = ExposedMembers.TileGrowth.GetAllPropertyIDs(true)

    Controls.GrowthPropertyStack:DestroyAllChildren()

    if table.count(GrowthProperties) > 0 then
        for i, property in ipairs(GrowthProperties) do
            -- print(Locale.Lookup(resourceInfo.Name))
            local propertyPickInstance:table = {}
            ContextPtr:BuildInstanceForControl( "GrowthPropertyPickEntry", propertyPickInstance, Controls.GrowthPropertyStack )

            propertyPickInstance.PropertyLabel:SetText(property)

            propertyPickInstance.ShowGrowthProperty:RegisterCallback(
                Mouse.eLClick,
                function()
                    HandlePropertyRadioBox(propertyPickInstance, property)
                end)
        end
    end

    -- Cleanup
    Controls.GrowthPropertyStack:CalculateSize()
end

function ToggleValueToShow()
    if Controls.ShowGrowthPropertyValue:IsChecked() then
		ParameterToShow = "Value";
	elseif Controls.ShowGrowthPropertyGrowth:IsChecked() then
		ParametToShow = "Growth"
	else
		ParameterToShow = "Value"
	end
    m_resetBonusResourceList = true
    m_bonusResourcesToShow = {}

    -- Assuming resource lens is already applied
    --RefreshPropertyPicker()
    RefreshPropertyLens()
end

function HandlePropertyRadioBox(pControl, propertyID)
    if pControl.ShowGrowthProperty:IsChecked() then
		CurrentPropertyID = propertyID
    end

    -- Assuming resource lens is already applied
    RefreshPropertyLens()
end

-- ===========================================================================
--  UI Controls
-- ===========================================================================

local function Open()
    Controls.ResourceLensOptionsPanel:SetHide(false)
    m_isOpen = true

    -- Load our saved settings, but if no settings exits, ensure a reset
    if not LoadBonusResourcesToShow() then
        m_resetBonusResourceList = true
    end
    if not LoadLuxuryResourcesToShow() then
        m_resetLuxuryResourceList = true
    end
    if not LoadStrategicResourcesToShow() then
        m_resetStrategicResourceList = true
    end

    RefreshPropertyPicker()  -- Recall this to apply options properly
end

local function Close()
    Controls.ResourceLensOptionsPanel:SetHide(true)
    m_isOpen = false
end

local function TogglePanel()
    if m_isOpen then
        Close()
    else
        Open()
    end
end

local function OnReoffsetPanel()
    -- Get size and offsets for minimap panel
    local offsets = {}
    LuaEvents.MinimapPanel_GetLensPanelOffsets(offsets)
    Controls.ResourceLensOptionsPanel:SetOffsetY(offsets.Y + PANEL_OFFSET_Y)
    Controls.ResourceLensOptionsPanel:SetOffsetX(offsets.X + PANEL_OFFSET_X)
end

-- ===========================================================================
--  Game Engine Events
-- ===========================================================================

local function OnLensLayerOn(layerNum:number)
    if layerNum == ML_LENS_LAYER then
        local lens = {}
        LuaEvents.MinimapPanel_GetActiveModLens(lens)
        if lens[1] == LENS_NAME then
            SetGrowthPropertyLens()
        end
    end
end

local function ChangeContainer()
    -- Change the parent to /InGame/HUD container so that it hides correcty during diplomacy, etc
    local hudContainer = ContextPtr:LookUpControl("/InGame/HUD")
    Controls.ResourceLensOptionsPanel:ChangeParent(hudContainer)
end

local function OnInit(isReload:boolean)
    if isReload then
        ChangeContainer()
    end
end

local function OnShutdown()
    -- Destroy the container manually
    local hudContainer = ContextPtr:LookUpControl("/InGame/HUD")
    if hudContainer ~= nil then
        hudContainer:DestroyChild(Controls.ResourceLensOptionsPanel)
    end
end

-- ===========================================================================
--  Init
-- ===========================================================================

-- minimappanel.lua
local GrowthPropertyLensEntry = {
    LensButtonText = "LOC_HUD_GROWTH_PROPERTY_LENS",
    LensButtonTooltip = "LOC_HUD_GROWTH_PROPERTY_LENS_TOOLTIP",
    Initialize = nil,
    OnToggle = TogglePanel,
    GetColorPlotTable = nil  -- Don't pass a function here since we will have our own trigger
}

-- modallenspanel.lua
local PropertyLensModalPanelEntry = {}
PropertyLensModalPanelEntry.LensTextKey = "LOC_HUD_GROWTH_PROPERTY_LENS"
PropertyLensModalPanelEntry.Legend = {
    {"LOC_TOOLTIP_PROPERTY_LOWEST",				ColorGradient[1]},
    {"LOC_TOOLTIP_PROPERTY_LOW",				ColorGradient[2]},
    {"LOC_TOOLTIP_PROPERTY_MEDIUM",				ColorGradient[3]},
    {"LOC_TOOLTIP_PROPERTY_HIGH",				ColorGradient[4]},
    {"LOC_TOOLTIP_PROPERTY_HIGHEST",			ColorGradient[5]}
}

-- Don't import this into g_ModLenses, since this for the UI (ie not lens)
local function Initialize()
    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    print("         Plot Property Panel")
    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    Close()
    OnReoffsetPanel()

    ContextPtr:SetInitHandler( OnInit )
    ContextPtr:SetShutdown( OnShutdown )
    ContextPtr:SetInputHandler( OnInputHandler, true )

    Events.LoadScreenClose.Add(
        function()
            ChangeContainer()
            LuaEvents.MinimapPanel_AddLensEntry(LENS_NAME, GrowthPropertyLensEntry)
            LuaEvents.ModalLensPanel_AddLensEntry(LENS_NAME, PropertyLensModalPanelEntry)
        end
    )
    Events.LensLayerOn.Add( OnLensLayerOn )

    -- Resource Lens Setting
    Controls.ShowGrowthPropertyValue:RegisterCallback( Mouse.eLClick, ToggleValueToShow )
    Controls.ShowGrowthPropertyGrowth:RegisterCallback( Mouse.eLClick, ToggleValueToShow )

    LuaEvents.ML_ReoffsetPanels.Add( OnReoffsetPanel )
    LuaEvents.ML_CloseLensPanels.Add( Close )
end

Initialize()
