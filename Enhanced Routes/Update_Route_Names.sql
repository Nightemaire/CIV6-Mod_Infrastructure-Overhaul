-- Update_Route_Names
-- Author: bbarr
-- DateCreated: 8/1/2022 14:20:21
--------------------------------------------------------------

UPDATE LocalizedText	SET Text = "Trail"		WHERE Tag = "LOC_ROUTE_ANCIENT_ROAD_NAME" AND Language="en_US";
UPDATE LocalizedText	SET Text = "Road"		WHERE Tag = "LOC_ROUTE_MEDIEVAL_ROAD_NAME" AND Language="en_US";
UPDATE LocalizedText	SET Text = "Asphalt"	WHERE Tag = "LOC_ROUTE_INDUSTRIAL_ROAD_NAME" AND Language="en_US";
UPDATE LocalizedText	SET Text = "Highway"	WHERE Tag = "LOC_ROUTE_MODERN_ROAD_NAME" AND Language="en_US";