-- Great Engineer: Theodore Judah
-- Author: Nightemaire
-- DateCreated: 10/2/2022

INSERT INTO Types (Type, Kind) VALUES ('GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH', 'KIND_GREAT_PERSON_INDIVIDUAL');

INSERT INTO GreatPersonIndividuals
        (   GreatPersonIndividualType,
            Name,                                       
            GreatPersonClassType,                               
            EraType,                            
            Gender, 
            ActionCharges,                              
            ActionRequiresCompletedDistrictType,                
            ActionRequiresMissingBuildingType,  
            ActionEffectTextOverride
        )
VALUES  (   'GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH',   
            'LOC_GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH_NAME',
            'GREAT_PERSON_CLASS_ENGINEER',
            'ERA_INDUSTRIAL',                   
            'M',
            '2',                                        
            'DISTRICT_INDUSTRIAL_ZONE',                         
            'BUILDING_TCRR_STATION',            
            'LOC_GREATPERSON_THEODORE_JUDAH_ACTIVE'
        );

INSERT INTO GreatPersonIndividualActionModifiers ( 
            GreatPersonIndividualType,                  ModifierId,                                 AttachmentTargetType                                    )
VALUES  (   'GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH',   'GREATPERSON_RAILYARD',                     'GREAT_PERSON_ACTION_ATTACHMENT_TARGET_DISTRICT_IN_TILE'),
        (   'GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH',   'GREATPERSON_TCRR_STATION',                 'GREAT_PERSON_ACTION_ATTACHMENT_TARGET_DISTRICT_IN_TILE'),
        (   'GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH',   'GREATPERSON_RAILYARD_PRODUCTION',          'GREAT_PERSON_ACTION_ATTACHMENT_TARGET_DISTRICT_IN_TILE'),
        (   'GREAT_PERSON_INDIVIDUAL_THEODORE_JUDAH',   'GREATPERSON_THEODORE_JUDAH_EXTRA_RANGE',   'GREAT_PERSON_ACTION_ATTACHMENT_TARGET_DISTRICT_IN_TILE');

INSERT INTO Modifiers   ( ModifierId,                                 ModifierType,                                           RunOnce,  Permanent   )
VALUES                  ( 'GREATPERSON_RAILYARD',                     'MODIFIER_SINGLE_CITY_GRANT_BUILDING_IN_CITY_IGNORE',   '1',      '1'         ),
                        ( 'GREATPERSON_TCRR_STATION',                 'MODIFIER_SINGLE_CITY_GRANT_BUILDING_IN_CITY_IGNORE',   '1',      '1'         ),
                        ( 'GREATPERSON_RAILYARD_PRODUCTION',          'MODIFIER_PLAYER_CITIES_ADJUST_BUILDING_YIELD_CHANGE',  '0',      '1'         ),
                        ( 'GREATPERSON_THEODORE_JUDAH_EXTRA_RANGE',   'MODIFIER_PLAYER_DISTRICT_ADJUST_EXTRA_REGIONAL_RANGE', '0',      '1'         );

INSERT INTO ModifierArguments(  ModifierId,                                 Name,               Value                       )
VALUES                       (  'GREATPERSON_RAILYARD',                     'BuildingType',     'BUILDING_RAILYARD'         ),
                             (  'GREATPERSON_TCRR_STATION',                 'BuildingType',     'BUILDING_TCRR_STATION'     ),
                             (  'GREATPERSON_RAILYARD_PRODUCTION',          'YieldType',        'YIELD_PRODUCTION'          ),
                             (  'GREATPERSON_RAILYARD_PRODUCTION',          'Amount',           '1'                         ),
                             (  'GREATPERSON_RAILYARD_PRODUCTION',          'BuildingType',     'BUILDING_RAILYARD'         ),
                             (  'GREATPERSON_THEODORE_JUDAH_EXTRA_RANGE',   'Amount',           '2'                         );