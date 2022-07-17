-- Automation_Events
-- Author: Nightemaire
-- DateCreated: 7/10/2022 10:40:21
--------------------------------------------------------------
include "Automation_Utilities.lua";

function RecalcPlotUtilGrowth(iX, iY)
	local pPlot = Map.GetPlot(iX, iY)

	-- Get plot details
	local owner			= plot:GetOwner()
	local workerCount	= plot:GetWorkerCount()
	local currentUtil	= getUtilization(plot)
	local appeal		= plot:GetAppeal()
	local isFreshWater	= plot:IsFreshWater()
	local hasRoute		= plot:IsRoute()
	local yield			= plot:GetYield()	-- This sums all yields on the plot
	local distToCity	= FindClosestCity(iX, iY, 10)

	-- Set the base growth to the tile's appeal (can be negative)
	-- If negative appeal, and unworked, utilization will drop back to zero
	local growth = appeal

	-- Subtract how far the plot is from the city (if adjacent subtract nothing)
	-- << SHOULD REPLACE THIS WITH A PATH DISTANCE THAT ACCOUNTS FOR ROUTES >>
	growth = growth - (distToCity - 1)

	-- Growth from yields are fractional, but we want to take the floor anyway
	growth = growth + math.floor(yield * GROWTH_YIELD)

	-- Check for some other growths
	if isFreshWater then growth = growth + GROWTH_FRESHWATER; end
	if hasRoute then
		local subType = plot:GetProperty("RouteSubType")

		-- Subtract the route subtype, primary routes add the most benefit
		growth = growth + GROWTH_HASROUTE - subType
	end
					
	-- Add to the growth if the tile is being worked
	if workerCount > 0 then growth = growth + UtilizationWorked; end

	-- Scale the growth so it is compatible with utilization
	growth = growth * UtilizationScalar

	plot:SetProperty("PLOT_UTIL_GROWTH", growth);
end

function RecalcPlotPopGrowth(iX, iY)


end

-- ===========================================================================
-- PLOT UPDATES
-- ===========================================================================

-- Appeal changed
function OnAppealChanged(iX, iY)
	RecalcPlotUtilGrowth(iX, iY)
end
Events.PlotAppealChanged.Add(OnAppealChanged);

-- Property Changed
function OnPropertyChanged(iX, iY)
	
end
Events.PlotPropertyChanged.Add(OnPropertyChanged);

-- Yield Changed
function OnYieldChanged(iX, iY)
	RecalcPlotUtilGrowth(iX, iY)
end
Events.PlotYieldChanged.Add(OnYieldChanged);

-- Player ownership changed
function OnOwnershipChanged(iX, iY)
	
end
GameEvents.PlotOwnershipChanged.Add(OnOwnershipChanged);

-- Not sure what the marker is...
function OnMarkerChanged(iX, iY)
	print("A marker changed at <"..iX..","..iY..">")
end
Events.PlotMarkerChanged.Add(OnMarkerChanged);

-- National Park Added
function OnParkAdded()
	-- UPDATE ROUTE SUB TYPES INSIDE PARK
	RecalcPlotUtilGrowth(iX, iY)
end
Events.NationalParkAdded.Add(OnParkAdded);

-- National Park Removed
function OnParkRemoved()
	RecalcPlotUtilGrowth(iX, iY)
end
Events.NationalParkRemoved.Add(OnParkRemoved);

-- Feature Removed
function OnFeatureRemoved()
	RecalcPlotUtilGrowth(iX, iY)
end
Events.FeatureRemovedFromMap.Add(OnFeatureRemoved)


-- ===========================================================================
-- IMPROVEMENTS UPDATES
-- ===========================================================================

--Events.ImprovementChanged.Add(OnImprovementChanged);

-- Improvement Added
Events.ImprovementAddedToMap.Add(OnImprovementAdded);
function OnImprovementAdded(iX, iY, eImprovement, playerID)
	local plot = Map.GetPlot(iX, iY)
	if playerID >= 0 and playerID < 63 then
		local name = Locale.Lookup(GameInfo.Improvements[eImprovement].Name)
		print(name.." added at <"..iX..","..iY..">, giving it a road!")
		ConnectToNearestRoute(plot, 3, 3)
	end
end

-- Improvement Removed
function OnImprovementRemoved(iX, iY, eImprovement, playerID)
	

end
Events.ImprovementRemovedFromMap.Add(OnImprovementRemoved);

-- Route Added
function OnRouteAdded(iX, iY)
	print("A route was added at <"..iX..","..iY..">")
	local plot = Map.GetPlot(iX, iY)

	-- if there's no sub type, then we need to set one
	if plot:GetProperty("RouteSubType") == nil then
		local isCity		= plot:IsCity()
		local isDistrict	= plot:GetDistrictType() >= 0
		local isWonder		= plot:GetWonderType() >= 0
		local isPark		= plot:IsNationalPark()

		-- Check if it's a district or wonder, and set the type to 2 if so, otherwise it's a 1
		if isCity then
			plot:SetProperty("RouteSubType", 1)
		elseif isDistrict or isWonder then
			print("  - Route has district or wonder, subtype => 2")
			plot:SetProperty("RouteSubType", 2)
		elseif isPark then
			print("  - Route has park, subtype => 3")
			plot:SetProperty("RouteSubType", 3)
		else
			-- Assume it's added by a trader, so is a primary route
			print("  - Defaulting to primary route")
			plot:SetProperty("RouteSubType", 1)
		end
	end
end
Events.RouteAddedToMap.Add(OnRouteAdded);

-- Unit Moved
function OnUnitMoved(playerID:number, unitID, tileX, tileY)
	local unit = UnitManager.GetUnit(playerID, unitID)
	local unitType = GameInfo.Units[unit:GetType()].Index

	if (unitType == m_eTrader) then
		local plot = Map.GetPlot(tileX, tileY)
		plot:SetProperty("RouteSubType", 1)
	end
end
Events.UnitMoved.Add(OnUnitMoved);

-- ===========================================================================
-- DISTRICT UPDATES
-- ===========================================================================

-- District Constructed
function OnDistrictConstructed(playerID, districtID, iX, iY)

end
GameEvents.OnDistrictConstructed.Add(OnDistrictConstructed);	-- (playerID, districtID, iX, iY)

-- District Removed
function OnDistrictRemoved(playerID, districtID)

end
Events.DistrictRemovedFromMap.Add(OnDistrictRemoved)			-- (playerID, districtID)

-- District Pillaged
function OnDistrictPillaged(playerID, districtID, cityID, iX, iY, districtType, percentComplete, isPillaged)

end
Events.DistrictPillaged.Add(OnDistrictPillaged)					-- (owner, districtID, cityID, iX, iY, districtType, percentComplete, isPillaged)

-- ===========================================================================
-- CITY UPDATES
-- ===========================================================================

-- City Initialized
function OnCityInitialized(cityOwner, cityID, iX, iY)

end
Events.CityInitialized.Add(OnCityInitialized);					-- (playerID, cityID, iX, iY)

-- City Focus Changed
function OnCityFocusChanged(cityOwner, cityID)
	local pPlayer = PlayerManager.GetPlayer(cityOwner)
	local city = pPlayer:GetCities():FindID(cityID)

	local favoredYields = {}
	local disfavoredYields = {}

	for yield in GameInfo.YieldTypes do
		local isFavored = city:GetCitizens():IsFavoredYield(yield)
		local isDisfavored = city:GetCitizens():IsDisfavoredYield(yield)

		if isFavored then
			table.insert(favoredYields, yield)
		end

		if isDisfavored then
			table.insert(disfavoredYields, yield)
		end
	end
end
Events.CityFocusChanged.Add(OnCityFocusChanged);				-- (playerID, cityID)

-- Population Changed
function OnCityPopChanged(cityOwner, cityID, ChangeAmount)

end
GameEvents.OnCityPopulationChanged.Add(OnCityPopChanged);		-- (cityOwner, cityID, ChangeAmount)

-- Worker Changed
function OnWorkerChanged(cityOwner, cityID, iX, iY)
	--local pPlayer = PlayerManager.GetPlayer(cityOwner)
	--local city = pPlayer:GetCities():FindID(cityID)

	--for k,plot in pairs(city:GetOwnedPlots()) do
		RecalcPlotUtilGrowth(plot:GetX(), plot:GetY())
		--UpdatePlotUtilization(plot, CityData)
	--end
end
Events.CityWorkerChanged.Add(OnWorkerChanged);					-- (owner, cityID, iX, iY)

-- Tile Ownership Changed
function OnTileOwnershipChanged(cityOwner, cityID)
	RecalcPlotUtilGrowth(plot:GetX(), plot:GetY())
end
Events.CityTileOwnershipChanged.Add(OnTileOwnershipChanged);	-- (owner, cityID)

-- City Removed
function OnCityRemoved(cityOwner, cityID)
	
end
Events.CityRemovedFromMap.Add(OnCityRemoved);					-- (playerID, cityID)

-- City Conquered
function OnCityConquered(newOwner, oldOwner, newCityID, iX, iY)
	local pPlayer = PlayerManager.GetPlayer(newOwner)
	local city = pPlayer:GetCities():FindID(newCityID)

	for k,plot in pairs(city:GetOwnedPlots()) do
		RecalcPlotUtilGrowth(plot:GetX(), plot:GetY())
		--UpdatePlotUtilization(plot, CityData)
	end
end
Events.CityConquered.Add(OnCityConquered);						--(newPlayerID,oldPlayerID,newCityID,x,y)

-- ===========================================================================
-- GOVERNOR UPDATES
-- ===========================================================================

-- Appointed
Events.GovernorAppointed.Add(OnGovernorAppointed);
function OnGovernorAppointed(playerID:number, governorID:number)
	--print("Player "..playerID.." appointed "..GameInfo.Governors[governorID].Name);
	if (governorID == m_eGovernorLiang) then
		print("Player "..playerID.." appointed Liang");
		getPlayer(playerID):SetProperty("HAS_LIANG", true);
	end
end

-- Promoted
Events.GovernorPromoted.Add(OnGovernorPromoted);
function OnGovernorPromoted(playerID:number, governorID:number, promotionID:number)
	if (governorID == m_eGovernorLiang and promotionID == m_eAquaculturePromotion) then
		getPlayer(playerID):SetProperty("HAS_AQUACULTURE", true);
		print("Player "..playerID.." promoted Liang for Aquaculture");
	end

end

-- Assigned
Events.GovernorAssigned.Add(OnGovernorAssigned);
function OnGovernorAssigned(cityOwner:number, cityID:number, governorOwner:number, governorID:number)
	if (governorID == m_eGovernorLiang) then
		local pPlayer = PlayerManager.GetPlayer(cityOwner)
		local priorCityID = pPlayer:GetProperty("AQUACULTURE_CITY")
		if priorCityID ~= nil then
			local priorCity = pPlayer:GetCities():FindID(priorCityID)
		end
		print("Player "..governorOwner.." reassigned Liang to "..cityID);
		getPlayer(governorOwner):SetProperty("AQUACULTURE_CITY", nil);
	end
end

-- Established
Events.GovernorEstablished.Add(OnGovernorEstablished);
function OnGovernorEstablished(cityOwner:number, cityID:number, governorOwner:number, governorID:number)
	if (governorID == m_eGovernorLiang) then
		print("Player "..governorOwner.." established Liang in "..cityID);
		getPlayer(governorOwner):SetProperty("AQUACULTURE_CITY", cityID);
	end
end

-- ===========================================================================
-- OTHER UPDATES
-- ===========================================================================

-- Need to readjust route types to account for sub-type when a player era changes
function OnPlayerEraChange(playerID:number, eraID)
	local player = getPlayer(playerID)
	if eraID == i_MedievalEra or eraID == i_IndustrialEra or eraID == i_ModernEra then
		local currentRouteType = GetRouteTypeForPlayer(player)
		local cities = getAllCities(playerID)
		if cities ~= nil then
			for iCityIndex : number, city : object in cities:Members() do
				AdjustRoadsBySubType(city, currentRouteType)
			end
		end
	end
end
Events.PlayerEraChanged.Add(OnPlayerEraChange);

--Events.Combat.Add(OnCombat);						--(combatResult)
--
--Events.WonderCompleted.Add(OnWonderComplete)	--(x,y,buildingID,playerID,cityID,%complete,unknown)