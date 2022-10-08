-- Routes_GameSetup
-- Author: Nightemaire
-- DateCreated: 9/25/2022 10:13:57
--------------------------------------------------------------

INSERT INTO Parameters (ParameterId, Name, Description,
Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, Visible, ReadOnly,
SupportsSinglePlayer, SupportsLANMultiplayer, SupportsInternetMultiplayer, SupportsHotSeat, SupportsPlayByCloud,
ChangeableAfterGameStart, ChangeableAfterPlayByCloudMatchCreate, SortIndex) VALUES

('ER_CONNECT_IMPROVEMENTS', 'LOC_NAME_ER_CONNECT_IMPROVEMENTS', 'LOC_DESC_ER_CONNECT_IMPROVEMENTS',
'bool', 1, 'Game', 'ER_CONNECT_IMPROVEMENTS', 'AdvancedOptions', 1, 0,
1, 1, 1, 1, 1,
0, 0, 400),

('ER_CONNECT_DISTRICTS', 'LOC_NAME_ER_CONNECT_DISTRICTS', 'LOC_DESC_ER_CONNECT_DISTRICTS',
'bool', 1, 'Game', 'ER_CONNECT_DISTRICTS', 'AdvancedOptions', 1, 0,
1, 1, 1, 1, 1,
0, 0, 401),

('ER_CONNECT_CITIES', 'LOC_NAME_ER_CONNECT_CITIES', 'LOC_DESC_ER_CONNECT_CITIES',
'bool', 0, 'Game', 'ER_CONNECT_CITIES', 'AdvancedOptions', 1, 0,
1, 1, 1, 1, 1,
0, 0, 402);