-- UNIT: Railway Engineer
-- Author: Nightemaire
-- DateCreated: 10/2/2022

INSERT INTO Types (Type, Kind) 
VALUES ('UNIT_RAILWAY_ENGINEER', 'KIND_UNIT');

INSERT INTO UnitAiInfos (UnitType, AiType)
VALUES ('UNIT_RAILWAY_ENGINEER', 'UNITTYPE_CIVILIAN');

INSERT INTO TypeTags (Type, Tag)
VALUES ('UNIT_RAILWAY_ENGINEER', 'CLASS_BUILDER'), ('UNIT_RAILWAY_ENGINEER','CLASS_SUPPORT');

INSERT INTO Unit_BuildingPrereqs (Unit, PrereqBuilding)
VALUES ('UNIT_RAILWAY_ENGINEER', 'BUILDING_RAILYARD');

INSERT INTO Units   (   UnitType, BaseMoves, BuildCharges, BaseSightRange,
                        PrereqTech, StrategicResource, Domain, PurchaseYield, AdvisorType, FormationClass,
                        Cost, CostProgressionModel, CostProgressionParam1,
                        Name, Description
                    )
VALUES              (   'UNIT_RAILWAY_ENGINEER', '1', '2', '2',
                        'TECH_STEAM_POWER', 'RESOURCE_IRON', 'DOMAIN_LAND','YIELD_GOLD', 'ADVISOR_GENERIC','FORMATION_CLASS_CIVILIAN', 
                        '90', 'COST_PROGRESSION_GAME_PROGRESS', '400',
                        'LOC_UNIT_RAILWAY_ENGINEER_NAME', 'LOC_UNIT_RAILWAY_ENGINEER_DESCRIPTION'
                    );

INSERT INTO Units_XP2   (UnitType,                  CanEarnExperience,  ResourceCost,   ResourceMaintenanceAmount,  ResourceMaintenanceType,    CanFormMilitaryFormation)
VALUES                  ('UNIT_RAILWAY_ENGINEER',   '0',                '10',           '1',                        'RESOURCE_COAL',            '0'                 );

INSERT INTO UnitCaptures (CapturedUnitType, BecomesUnitType) VALUES ('UNIT_RAILWAY_ENGINEER', 'UNIT_RAILWAY_ENGINEER')