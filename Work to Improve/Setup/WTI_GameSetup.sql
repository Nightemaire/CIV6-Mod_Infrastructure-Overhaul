-- WTI_GameSetup
-- Author: Nightemaire
-- DateCreated: 9/25/2022 10:13:57
--------------------------------------------------------------


INSERT OR REPLACE INTO DomainValues (Domain, Name, Description, SortIndex, Value) VALUES
('ImprovementSpeed', 'LOC_ImprovementSpeed_veryslow_NAME', 'LOC_ImprovementSpeed_veryslow_DESC', 1, 1),
('ImprovementSpeed', 'LOC_ImprovementSpeed_slow_NAME', 'LOC_ImprovementSpeed_slow_DESC', 2, 2),
('ImprovementSpeed', 'LOC_ImprovementSpeed_average_NAME', 'LOC_ImprovementSpeed_average_DESC', 3, 3),
('ImprovementSpeed', 'LOC_ImprovementSpeed_fast_NAME', 'LOC_ImprovementSpeed_fast_DESC', 4, 4),
('ImprovementSpeed', 'LOC_ImprovementSpeed_veryfast_NAME', 'LOC_ImprovementSpeed_veryfast_DESC', 5, 5) ;


INSERT INTO Parameters 
(ParameterId, Name, Description,
Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, Visible, ReadOnly,
SupportsSinglePlayer, SupportsLANMultiplayer, SupportsInternetMultiplayer, SupportsHotSeat, SupportsPlayByCloud,
ChangeableAfterGameStart, ChangeableAfterPlayByCloudMatchCreate, SortIndex)
VALUES
('WTI_IMPROVEMENT_THRESHOLD', 'LOC_NAME_WTI_IMPROVEMENT_THRESHOLD', 'LOC_DESC_WTI_IMPROVEMENT_THRESHOLD',
'ImprovementSpeed', 3, 'Game', 'WTI_IMPROVEMENT_THRESHOLD', 'AdvancedOptions', 1, 0,
1, 1, 1, 1, 1,
0, 0, 420);
