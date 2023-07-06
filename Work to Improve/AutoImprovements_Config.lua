-- AutoImprovements_Config
-- Author: bbarr
-- DateCreated: 6/22/2022 23:46:51
--------------------------------------------------------------

local speed_setting = Game:GetProperty("Improvement_Speed")

if speed_setting == nil then speed_setting = 3; end

--------------------------------------------------------------
-- CONFIGURATION PARAMETERS
--------------------------------------------------------------
WTI_Config = {}

local ExpandThreshold = 1
local ImprovementThreshold = 2
local CityThreshold = 4

-- THRESHOLD SCALAR --
-- Lower values will result in tiles automatically improving faster
-- This value gets multiplied by the game speed multiplier to arrive at a
-- threshold before an improvement will be added
if speed_setting == 1 then
	print("Improvement Speed = VERY SLOW (50)")
	Threshold_Scalar = 22
elseif speed_setting == 2 then
	print("Improvement Speed = SLOW (35)")
	Threshold_Scalar = 14
elseif speed_setting == 3 then
	print("Improvement Speed = AVERAGE (25)")
	Threshold_Scalar = 8
elseif speed_setting == 4 then
	print("Improvement Speed = FAST (15)")
	Threshold_Scalar = 4
else
	print("Improvement Speed = VERY FAST (5)")
	Threshold_Scalar = 2
end

-- ALLOW APPEAL REDUCTION --
-- If set false, then improvements which reduce appeal (mines, quarries, etc) will not be automatically constructed
WTI_Config.Allow_Appeal_Reduction = true

-- FEATURE REMOVAL SETTINGS --
-- Global toggle parameter
WTI_Config.Allow_Feature_Removal = false
-- Only applicable if Allow_Feature_Removal is set to true
WTI_Config.Allow_Marsh_Removal = false
WTI_Config.Allow_Forest_Removal = false
WTI_Config.Allow_Jungle_Removal = false

-- BONUS WHEN WORKED --
-- This is the bonus applied to the gain when a tile is worked. A value of 5 will exactly cancel out a tile with
-- disgusting appeal, and the tile will not gain any utilization.
WTI_Config.GROWTH_WORKED = 5

-- ADDITIONAL BONUSES --
WTI_Config.GROWTH_APPEAL = 0.5
WTI_Config.GROWTH_FRESHWATER = 4
WTI_Config.GROWTH_HASROUTE = 4		-- The route sub type is subtracted from this value, so a tertiary route is 3 less than this value, while a railroad gets the full value
WTI_Config.GROWTH_YIELD = 1			-- The gain here is calculated as floor[(food+production)*GROWTH_YIELD]. Fractional values are permitted.
WTI_Config.BLEED_BONUS = 1/5

local GameSpeedType = GameConfiguration.GetGameSpeedType()
local SpeedMultiplier = GameInfo.GameSpeeds[GameSpeedType].CostMultiplier

-- Required utilization before the tile automatically improves
WTI_Config.ExpansionThreshold = ExpandThreshold * Threshold_Scalar * SpeedMultiplier
WTI_Config.AutoImproveThreshold = ImprovementThreshold * Threshold_Scalar * SpeedMultiplier
WTI_Config.BuildCityThreshold = CityThreshold * Threshold_Scalar * SpeedMultiplier

-- Development works with appeal, which is low order of magnitude, so we scale that to work with the threshold
WTI_Config.DevelopmentScalar = 10

--print("Auto-Improvements config loaded")