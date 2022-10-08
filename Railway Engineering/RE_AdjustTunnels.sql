-- RE_Tunnel_Override
-- Author: Nightemaire
-- DateCreated: 8/1/2022 14:58:52
--------------------------------------------------------------

UPDATE Improvements	    SET PrereqTech = 'TECH_METAL_CASTING'  WHERE ImprovementType = 'IMPROVEMENT_MOUNTAIN_TUNNEL';

INSERT INTO Improvement_ValidBuildUnits(ImprovementType, UnitType, ConsumesCharge, ValidRepairOnly)
VALUES ('IMPROVEMENT_MOUNTAIN_TUNNEL', 'UNIT_RAILWAY_ENGINEER', '0', '0');
