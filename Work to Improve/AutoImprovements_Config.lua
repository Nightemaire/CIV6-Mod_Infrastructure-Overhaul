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

-- THRESHOLD SCALAR --
-- Lower values will result in tiles automatically improving faster
-- This value gets multiplied by the game speed multiplier to arrive at a
-- threshold before an improvement will be added
if speed_setting == 1 then
	print("Improvement Speed = VERY SLOW (50)")
	Threshold_Scalar = 50
elseif speed_setting == 2 then
	print("Improvement Speed = SLOW (35)")
	Threshold_Scalar = 35
elseif speed_setting == 3 then
	print("Improvement Speed = AVERAGE (25)")
	Threshold_Scalar = 25
elseif speed_setting == 4 then
	print("Improvement Speed = FAST (15)")
	Threshold_Scalar = 15
else
	print("Improvement Speed = VERY FAST (5)")
	Threshold_Scalar = 5
end

-- ALLOW APPEAL REDUCTION --
-- If set false, then improvements which reduce appeal (mines, quarries, etc) will not be automatically constructed
Allow_Appeal_Reduction = true

-- FEATURE REMOVAL SETTINGS --
-- Global toggle parameter
Allow_Feature_Removal = false
-- Only applicable if Allow_Feature_Removal is set to true
Allow_Marsh_Removal = false
Allow_Forest_Removal = false
Allow_Jungle_Removal = false

-- BONUS WHEN WORKED --
-- This is the bonus applied to the gain when a tile is worked. A value of 5 will exactly cancel out a tile with
-- disgusting appeal, and the tile will not gain any utilization.
Utilization_Bonus_If_Worked = 5

-- ADDITIONAL BONUSES --
GROWTH_FRESHWATER = 2
GROWTH_HASROUTE = 4
GROWTH_YIELD = 1/3	-- The gain here is calculated as floor(yield*Gain_Yield), i.e. yield of 3 is gain of 1, yield of 2 is gain of 0, yield of 4 is gain of 1, yield of 6 is gain of 2.

local GameSpeedType = GameConfiguration.GetGameSpeedType()
local SpeedMultiplier = GameInfo.GameSpeeds[GameSpeedType].CostMultiplier

-- Required utilization before the tile automatically improves
AutoImproveThreshold = Threshold_Scalar * SpeedMultiplier

-- Utilization works with appeal, which is low order of magnitude, so we scale that to work with the threshold
UtilizationScalar = 10

--print("Auto-Improvements config loaded")