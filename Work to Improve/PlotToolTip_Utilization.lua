-- PlotToolTip_Utilization
-- Author: Nightemaire
-- DateCreated: 6/22/2022 22:13:13
--------------------------------------------------------------
-- ===========================================================================
-- INCLUDES
-- ===========================================================================
include "PlotTooltip_Expansion2";
include "AutoImprovements_Config";

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
XP2_FetchData = FetchData;
XP2_GetDetails = GetDetails;

print("Initializing Development Tooltip UI Script");

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function FetchData(pPlot)
	--print("Calling overridden data fetch");
	local data = XP2_FetchData(pPlot);

	local UI_Data = ExposedMembers.TileGrowth.UI_GetData("Development", pPlot);
	
	data.PlotIndex = pPlot:GetIndex();
	data.Development = UI_Data[1];
	data.Growth = UI_Data[2];
	data.DevThreshold = UI_Data[3];
	data.TriggerTurn = UI_Data[4];

	return data;
end

function GetDetails(data)
	--print("Calling overridden GetDetails()");
	local details : table = XP2_GetDetails(data);

	if data.Development ~= nil then
		-- Turn the utilization into a percent of the threshold
		local percentUtil = math.floor((data.Development*100)/data.DevThreshold)
		local percentGrowth = math.floor((data.Growth*100)/data.DevThreshold)
		table.insert(details, "Plot ID: "..data.PlotIndex)
		table.insert(details, Locale.Lookup("LOC_PLOT_DEVELOPMENT_TOOLTIP_TEXT", data.Development, data.DevThreshold, percentUtil));
		table.insert(details, Locale.Lookup("LOC_PLOT_UTIL_GROWTH_TOOLTIP_TEXT", data.Growth, percentGrowth));
		table.insert(details, Locale.Lookup("LOC_PLOT_UTIL_TRIGGER_TOOLTIP_TEXT", data.TriggerTurn));
	end
	
	return details;
end