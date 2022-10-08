-- PlotToolTip_Utilization
-- Author: bbarr
-- DateCreated: 6/22/2022 22:13:13
--------------------------------------------------------------
-- ===========================================================================
-- INCLUDES
-- ===========================================================================
include "PlotTooltip_Expansion2";
include "AutoImprovements_Config.lua";

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================
XP2_FetchData = FetchData;
XP2_GetDetails = GetDetails;

print("Initializing Utilization Tooltip UI Script");

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function FetchData(pPlot)
	--print("Calling overridden data fetch");
	local data = XP2_FetchData(pPlot);

	local util = pPlot:GetProperty("PLOT_UTILIZATION");
	local growth = pPlot:GetProperty("PLOT_UTIL_GROWTH");
	if util == nil then util = 0; end
	if growth == nil then growth = 0; end
	
	data.Utilization = util;
	data.Growth = growth;

	return data;
end

function GetDetails(data)
	--print("Calling overridden GetDetails()");
	local details : table = XP2_GetDetails(data);

	if (data.Owner == Game.GetLocalPlayer()) then
		if data.Utilization == nil then
			table.insert(details, "Utilization: 0% (0)");
			table.insert(details, "Growth: 0% (0)");
		else
			-- Turn the utilization into a percent of the threshold
			thold = 100;
			if AutoImproveThreshold ~= nil then thold = AutoImproveThreshold; end
			local percentUtil = math.floor((data.Utilization*100)/thold)
			local percentGrowth = math.floor((data.Growth*100)/thold)
			table.insert(details, Locale.Lookup("LOC_PLOT_UTILIZATION_TOOLTIP_TEXT", percentUtil, data.Utilization));
			table.insert(details, Locale.Lookup("LOC_PLOT_UTIL_GROWTH_TOOLTIP_TEXT", percentGrowth, data.Growth));
		end
		--print("Tried to print something..."..data.Utilization);
	end	
	
	return details;
end