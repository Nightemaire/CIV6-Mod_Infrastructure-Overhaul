-- Railway Buildings
-- Author: Nightemaire
-- DateCreated: 10/2/2022

INSERT INTO Types   (   Type,                       Kind            ) 
VALUES              (   'BUILDING_RAILYARD',        'KIND_BUILDING' ),
                    (   'BUILDING_TCRR_STATION',    'KIND_BUILDING' ),
                    (   'BUILDING_SUBWAY_NETWORK',  'KIND_BUILDING' );

-- RAILYARD
INSERT INTO Buildings   
                (   BuildingType,              Name,                            Description,                            PrereqDistrict,
                    Cost,       CitizenSlots,  PurchaseYield,                   AdvisorType,        Maintenance,        PrereqTech
                )
VALUES
                (   'BUILDING_RAILYARD',       'LOC_BUILDING_RAILYARD_NAME',    'LOC_BUILDING_RAILYARD_DESCRIPTION',    'DISTRICT_INDUSTRIAL_ZONE',
                    '250',      '1',           'YIELD_PRODUCTION',              'ADVISOR_GENERIC',  '1',                'TECH_STEAM_POWER'
                );

-- TRANSCONTINENTAL RAILSTATION
INSERT INTO Buildings
                (   BuildingType,              Name,                            Description,                            PrereqDistrict,
                    Cost,            PurchaseYield,              Maintenance,   PrereqTech,                 MaxPlayerInstances   )
VALUES          (   'BUILDING_TCRR_STATION',   'LOC_BUILDING_TCRR_STATION_NAME','LOC_BUILDING_TCRR_STATION_DESCRIPTION','DISTRICT_CITY_CENTER',
                    '500',           'YIELD_PRODUCTION',         '2',           'TECH_ECONOMICS',           '2'                  );

-- SUBWAY NETWORK
INSERT INTO Buildings   
                (   BuildingType,              Name,                            Description,                            PrereqDistrict,
                    Cost,       CitizenSlots,  PurchaseYield,                   AdvisorType,        Maintenance,        PrereqTech
                )
VALUES
                (   'BUILDING_SUBWAY_NETWORK', 'LOC_BUILDING_SUBWAY_NAME',      'LOC_BUILDING_SUBWAY_DESCRIPTION',      'DISTRICT_CITY_CENTER',
                    '450',      '1',           'YIELD_PRODUCTION',              'ADVISOR_GENERIC',  '5',                'TECH_ELECTRICITY'
                );

INSERT INTO BuildingPrereqs ( Building, PrereqBuilding ) VALUES ( 'BUILDING_TCRR_STATION', 'BUILDING_RAILYARD' );
INSERT INTO BuildingPrereqs ( Building, PrereqBuilding ) VALUES ( 'BUILDING_SUBWAY_NETWORK', 'BUILDING_RAILYARD' );

-- YIELDS
INSERT INTO Building_YieldChanges           ( BuildingType,             YieldType,          YieldChange ) 
VALUES                                      ( 'BUILDING_RAILYARD',      'YIELD_PRODUCTION', '2'         ),
                                            ( 'BUILDING_TCRR_STATION',  'YIELD_GOLD',       '5'         );

INSERT INTO Building_GreatPersonPoints      ( BuildingType,               GreatPersonClassType,           PointsPerTurn   )
VALUES                                      ( 'BUILDING_RAILYARD',        'GREAT_PERSON_CLASS_ENGINEER',  '1'             ),
                                            ( 'BUILDING_TCRR_STATION',    'GREAT_PERSON_CLASS_MERCHANT',  '2'             );

-- MODIFIERS
INSERT INTO BuildingModifiers               ( BuildingType,                 ModifierId                  )
VALUES                                      ( 'BUILDING_RAILYARD',          'RAILYARD_ADDTRADEROUTE'    ),
                                            ( 'BUILDING_RAILYARD',          'RAILYARD_ADJUST_STOCKPILE' ),
                                            ( 'BUILDING_TCRR_STATION',      'TCSTATION_ADJUST_TOURISM'  ),
                                            ( 'BUILDING_SUBWAY_NETWORK',    'SUBWAY_ADJUST_CULTURE'     ),
                                            ( 'BUILDING_SUBWAY_NETWORK',    'SUBWAY_ADJUST_SCIENCE'     ),
                                            ( 'BUILDING_SUBWAY_NETWORK',    'SUBWAY_ADJUST_PRODUCTION'  ),
                                            ( 'BUILDING_SUBWAY_NETWORK',    'SUBWAY_ADJUST_FAITH'       ),
                                            ( 'BUILDING_SUBWAY_NETWORK',    'SUBWAY_ADJUST_GOLD'        );

INSERT INTO Modifiers                       ( ModifierId,                   ModifierType,                                       SubjectRequirementSetId                         )
VALUES                                      ( 'RAILYARD_ADDTRADEROUTE',     'MODIFIER_PLAYER_ADJUST_TRADE_ROUTE_CAPACITY',      'RAILYARD_TRADE_ROUTE_CAPACITY_REQUIREMENTS'    ),
                                            ( 'RAILYARD_ADJUST_STOCKPILE',  'MODIFIER_PLAYER_ADJUST_RESOURCE_STOCKPILE_CAP',    null                                            ),
                                            ( 'TCSTATION_ADJUST_TOURISM',   'MODIFIER_SINGLE_CITY_ADJUST_TOURISM',              null                                            ),
                                            ( 'SUBWAY_ADJUST_CULTURE',      'MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER',  'SUBWAY_ADJUST_CULTURE_REQUIREMENTS'            ),
                                            ( 'SUBWAY_ADJUST_SCIENCE',      'MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER',  'SUBWAY_ADJUST_SCIENCE_REQUIREMENTS'            ),
                                            ( 'SUBWAY_ADJUST_PRODUCTION',   'MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER',  'SUBWAY_ADJUST_PRODUCTION_REQUIREMENTS'         ),
                                            ( 'SUBWAY_ADJUST_FAITH',        'MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER',  'SUBWAY_ADJUST_FAITH_REQUIREMENTS'              ),
                                            ( 'SUBWAY_ADJUST_GOLD',         'MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER',  'SUBWAY_ADJUST_GOLD_REQUIREMENTS'               );

INSERT INTO ModifierArguments               (  ModifierId,                                 Name,                Value                   )
VALUES                                      (  'RAILYARD_ADDTRADEROUTE',                   'Amount',            '1'                     ),
                                            (  'RAILYARD_ADJUST_STOCKPILE',                'Amount',            '10'                    ),
                                            (  'TCSTATION_ADJUST_TOURISM',                 'Religious',         '0'                     ),
                                            (  'TCSTATION_ADJUST_TOURISM',                 'ScalingFactor',     '150'                   ),
                                            (  'SUBWAY_ADJUST_CULTURE',                    'Amount',            '5'                     ),
                                            (  'SUBWAY_ADJUST_CULTURE',                    'YieldType',         'YIELD_CULTURE'         ),
                                            (  'SUBWAY_ADJUST_SCIENCE',                    'Amount',            '5'                     ),
                                            (  'SUBWAY_ADJUST_SCIENCE',                    'YieldType',         'YIELD_SCIENCE'         ),
                                            (  'SUBWAY_ADJUST_PRODUCTION',                 'Amount',            '5'                     ),
                                            (  'SUBWAY_ADJUST_PRODUCTION',                 'YieldType',         'YIELD_PRODUCTION'      ),
                                            (  'SUBWAY_ADJUST_FAITH',                      'Amount',            '5'                     ),
                                            (  'SUBWAY_ADJUST_FAITH',                      'YieldType',         'YIELD_FAITH'           ),
                                            (  'SUBWAY_ADJUST_GOLD',                       'Amount',            '5'                     ),
                                            (  'SUBWAY_ADJUST_GOLD',                       'YieldType',         'YIELD_GOLD'            );

-- REQUIREMENTS
INSERT INTO RequirementSets                 (   RequirementSetId,                               RequirementSetType                      )
VALUES                                      (   'RAILYARD_TRADE_ROUTE_CAPACITY_REQUIREMENTS',   'REQUIREMENTSET_TEST_ALL'               ),
                                            (   'SUBWAY_ADJUST_CULTURE_REQUIREMENTS',           'REQUIREMENTSET_TEST_ALL'               ),
                                            (   'SUBWAY_ADJUST_SCIENCE_REQUIREMENTS',           'REQUIREMENTSET_TEST_ALL'               ),
                                            (   'SUBWAY_ADJUST_PRODUCTION_REQUIREMENTS',        'REQUIREMENTSET_TEST_ALL'               ),
                                            (   'SUBWAY_ADJUST_FAITH_REQUIREMENTS',             'REQUIREMENTSET_TEST_ALL'               ),
                                            (   'SUBWAY_ADJUST_GOLD_REQUIREMENTS',              'REQUIREMENTSET_TEST_ALL'               );

INSERT INTO RequirementSetRequirements      (   RequirementSetId,                               RequirementId                           )
VALUES                                      (   'RAILYARD_TRADE_ROUTE_CAPACITY_REQUIREMENTS',   'REQUIRES_NO_MARKET'                    ),
                                            (   'RAILYARD_TRADE_ROUTE_CAPACITY_REQUIREMENTS',   'REQUIRES_NO_LIGHTHOUSE_IN_CITY'        ),
                                            (   'SUBWAY_ADJUST_CULTURE_REQUIREMENTS',           'REQUIRES_CITY_HAS_THEATER_DISTRICT'    ),
                                            (   'SUBWAY_ADJUST_SCIENCE_REQUIREMENTS',           'REQUIRES_CITY_HAS_CAMPUS'              ),
                                            (   'SUBWAY_ADJUST_PRODUCTION_REQUIREMENTS',        'REQUIRES_CITY_HAS_INDUSTRIAL_ZONE'     ),
                                            (   'SUBWAY_ADJUST_FAITH_REQUIREMENTS',             'REQUIRES_CITY_HAS_HOLY_SITE'           ),
                                            (   'SUBWAY_ADJUST_GOLD_REQUIREMENTS',              'REQUIRES_CITY_HAS_COMMERCIAL_HUB'      );

INSERT INTO Requirements                    (   RequirementId,                          RequirementType,                    Inverse     )
VALUES                                      (   'REQUIRES_NO_LIGHTHOUSE_IN_CITY',       'REQUIREMENT_CITY_HAS_BUILDING',    '1'         );

INSERT INTO RequirementArguments            (   RequirementId,                          Name,                   Value                   )
VALUES                                      (   'REQUIRES_NO_LIGHTHOUSE_IN_CITY',       'BuildingType',         'BUILDING_LIGHTHOUSE'   ),
                                            (   'REQUIRES_NO_LIGHTHOUSE_IN_CITY',       'MustBeFunctioning',    '0'                     );