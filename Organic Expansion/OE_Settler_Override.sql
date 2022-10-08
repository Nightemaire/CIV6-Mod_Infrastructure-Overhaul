-- OE_Settler_Override
-- Author: Nightemaire
-- DateCreated: 8/1/2022 14:58:52
--------------------------------------------------------------

UPDATE Units	

SET 
Cost = 140,
PopulationCost = 2,
PrereqPopulation = 4

WHERE UnitType = "UNIT_SETTLER";