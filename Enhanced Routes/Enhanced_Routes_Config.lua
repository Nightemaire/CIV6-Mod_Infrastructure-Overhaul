-- Enhanced_Routes_Config
-- Author: Nightemaire
-- DateCreated: 7/31/2022 17:32:18
--------------------------------------------------------------

local CI = Game.GetProperty("Connect_Improvements")
local CD = Game.GetProperty("Connect_Districts")
local CC = Game.GetProperty("Connect_Cities")

if CI == nil then CI = false; end
if CD == nil then CD = false; end
if CC == nil then CC = false; end

ER_Config = {}

ER_Config.Connect_Improvements = CI
ER_Config.Improvement_Connect_Range = 3

ER_Config.Connect_Districts = CD
ER_Config.District_Connect_Range = 4

ER_Config.Connect_Cities = CC
ER_Config.City_Connect_Range = 6

ER_Config.Minimize_River_Crossings = true