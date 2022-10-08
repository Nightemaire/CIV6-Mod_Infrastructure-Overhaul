-- UnitFlagManager_RailbuilderCharges.lua
-- Author: Nightemaire
--
-- Acknowledgements:
-- Extends the implementation of the mod "Better Build Charges Tracking by wltk
--
-- DateCreated: 9/25/2022 18:37:58
--------------------------------------------------------------
-- =================================================================================
-- Import base file
-- =================================================================================

-- Check to see if they're using the original mod or not
-- Original mod ID = "c6477d9f-6bad-4d24-9e76-49cda4f0a966"
local OriginalIsEnabled = Modding.IsModEnabled("c6477d9f-6bad-4d24-9e76-49cda4f0a966")

local files = {}
if OriginalIsEnabled then
    files = {
        "UnitFlagManager_BuilderCharges.lua",
        "UnitFlagManager_BarbarianClansMode.lua",
        "UnitFlagManager.lua"
    }
else
    files = {
        "UnitFlagManager_BarbarianClansMode.lua",
        "UnitFlagManager.lua"
    }
end

for _, file in ipairs(files) do
    include(file)
    if Initialize then
        print("Loading " .. file .. " as base file");
        break
    end
end

print("Initializing Railway Engineer Flag Manager")

-- =================================================================================
-- Cache base functions
-- =================================================================================
local BASE_Subscribe        = Subscribe;
local BASE_Unsubscribe      = Unsubscribe;
local BASE_UpdatePromotions	= UnitFlag.UpdatePromotions;

-- =================================================================================
-- Overrides
-- =================================================================================
function OnUnitChargesChanged(playerID, unitID)
    local flagInstance = GetUnitFlag(playerID, unitID);
    if flagInstance ~= nil then 
        flagInstance:UpdatePromotions();
    end                            
end

function UnitFlag.UpdatePromotions(self)
    local unit = self:GetUnit();
    if unit ~= nil and unit:GetUnitType() ~= -1 then
        local unitType = GameInfo.Units[unit:GetUnitType()].UnitType;
        if unitType == "UNIT_RAILWAY_ENGINEER" then
            -- The unit is a railroad builder, try updating it's builder charges.
			buildCharges = unit:GetActionCharges();

            if buildCharges > 0 then
                -- Only need to update if has charges.
                self.m_Instance.UnitNumPromotions:SetText(buildCharges);
                self.m_Instance.Promotion_Flag:SetHide(false);
            end
            return;
        end
    end
    BASE_UpdatePromotions(self);
end

function Subscribe()
    BASE_Subscribe();
    if not(OriginalIsEnabled) then
        Events.UnitChargesChanged.Add(OnUnitChargesChanged);
    end
end

function Unsubscribe()
    BASE_Unsubscribe();
    if not(OriginalIsEnabled) then
        Events.UnitChargesChanged.Remove(OnUnitChargesChanged);
    end
end
