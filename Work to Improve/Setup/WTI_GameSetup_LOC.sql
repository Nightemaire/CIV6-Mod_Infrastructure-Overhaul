-- WTI_GameSetup_LOC
-- Author: Nightemaire
-- DateCreated: 9/25/2022 10:14:16
--------------------------------------------------------------

INSERT OR REPLACE INTO LocalizedText
(Tag, Text, Language) VALUES

('LOC_NAME_WTI_IMPROVEMENT_THRESHOLD', 'Auto-Improve Speed', 'en_US'),
('LOC_DESC_WTI_IMPROVEMENT_THRESHOLD', 'Adjust how quickly tiles will automatically improve.', 'en_US'),

('LOC_ImprovementSpeed_veryslow_NAME', 'Very Slow', 'en_US'),
('LOC_ImprovementSpeed_veryslow_DESC', 'Dont expect to see many automatic improvements unless your empires appeal is through the roof.', 'en_US'),

('LOC_ImprovementSpeed_slow_NAME', 'Slow', 'en_US'),
('LOC_ImprovementSpeed_slow_DESC', 'You should notice a few improvements after a bit, but dont count on them.', 'en_US'),

('LOC_ImprovementSpeed_average_NAME', 'Average', 'en_US'),
('LOC_ImprovementSpeed_average_DESC', 'Your worked tiles should automatically improve if you neglect them, but you will still probably want builders for strategics.', 'en_US'),

('LOC_ImprovementSpeed_fast_NAME', 'Fast', 'en_US'),
('LOC_ImprovementSpeed_fast_DESC', 'You wont need many builders if you choose this option.', 'en_US'),

('LOC_ImprovementSpeed_veryfast_NAME', 'Very Fast', 'en_US'),
('LOC_ImprovementSpeed_veryfast_DESC', 'Builders = Choppers', 'en_US');
