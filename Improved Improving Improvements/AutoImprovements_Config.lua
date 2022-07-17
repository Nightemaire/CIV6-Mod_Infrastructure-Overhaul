-- AutoImprovements_Config
-- Author: bbarr
-- DateCreated: 6/22/2022 23:46:51
--------------------------------------------------------------

--------------------------------------------------------------
-- CONFIGURATION PARAMETERS
--------------------------------------------------------------
-- THRESHOLD SCALAR --
-- Lower values will result in tiles automatically improving faster
-- This value gets multiplied by the game speed multiplier to arrive at a
-- threshold before an improvement will be added
Threshold_Scalar = 25

-- ALLOW APPEAL REDUCTION --
-- If set false, then improvements which reduce appeal (mines, quarries, etc) will not be automatically constructed
Allow_Appeal_Reduction = true

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

AutoImproveThreshold = Threshold_Scalar * SpeedMultiplier -- Required utilization before the tile automatically improves
UtilizationScalar = 10	-- Utilization works with appeal, which is low order of magnitude, so we scale that to work with the threshold
