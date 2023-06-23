-- Railway Engineering_GameSetup
-- Author: Nightemaire
-- DateCreated: 9/25/2022 10:13:57
--------------------------------------------------------------

INSERT INTO Parameters (ParameterId, Name, Description,
Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, Visible, ReadOnly,
SupportsSinglePlayer, SupportsLANMultiplayer, SupportsInternetMultiplayer, SupportsHotSeat, SupportsPlayByCloud,
ChangeableAfterGameStart, ChangeableAfterPlayByCloudMatchCreate, SortIndex) VALUES

('RE_AI_HELPER', 'LOC_NAME_RE_AI_HELPER', 'LOC_DESC_RE_AI_HELPER',
'bool', 1, 'Game', 'RE_GAME_SETUP', 'AdvancedOptions', 1, 0,
1, 1, 1, 1, 1,
0, 0, 400);