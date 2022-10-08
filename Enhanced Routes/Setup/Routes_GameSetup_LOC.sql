-- Routes_GameSetup_LOC
-- Author: Nightemaire
-- DateCreated: 9/25/2022 10:14:16
--------------------------------------------------------------

INSERT OR REPLACE INTO LocalizedText
(Tag, Text, Language) VALUES

('LOC_NAME_ER_CONNECT_IMPROVEMENTS', 'ROUTES: Connect Improvements', 'en_US'),
('LOC_DESC_ER_CONNECT_IMPROVEMENTS', 'Enabling this will cause construction of improvements to automatically build tertiary roads to the nearest route within the city boundaries.', 'en_US'),

('LOC_NAME_ER_CONNECT_DISTRICTS', 'ROUTES: Connect Districts', 'en_US'),
('LOC_DESC_ER_CONNECT_DISTRICTS', 'Enabling this will cause construction of a district to automatically connect it to the city and other nearby districts with secondary roads.', 'en_US'),

('LOC_NAME_ER_CONNECT_CITIES', 'ROUTES: Connect Cities', 'en_US'),
('LOC_DESC_ER_CONNECT_CITIES', 'Enabling this will cause construction of new cities to automatically build primary roads to other cities within 6 tiles.', 'en_US');