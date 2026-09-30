-- Shared state and helpers for the kuhy_selftest phases (see init.lua).

local S = { phase = "boot", t = 0, fails = 0, data = {} }

local function write(file, mode, text)
    local f = io.open(file, mode)
    if f then f:write(text) f:close() end
end

local function out(line) write("results.txt", "a", line .. "\n") print("[kuhy_selftest] " .. line) end
local function check(name, ok, detail)
    if not ok then S.fails = S.fails + 1 end
    out((ok and "PASS " or "FAIL ") .. name .. (detail and (" -- " .. detail) or ""))
end
local function go(phase) S.phase = phase S.t = 0 write("state.txt", "w", phase) end

local function tdb(id) return TweakDBID.new(id) end
local function idstr(itemID) return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID)) end

local function countItem(id)
    local ok, items = Game.GetTransactionSystem():GetItemList(Game.GetPlayer())
    local n = 0
    for _, data in ipairs(items or {}) do
        if idstr(data:GetID()) == id then n = n + data:GetQuantity() end
    end
    return n
end

local function sys(name) return Game.GetScriptableSystemsContainer():Get(name) end
local function inMenu()
    local defs = Game.GetAllBlackboardDefs()
    return Game.GetBlackboardSystem():Get(defs.UI_System):GetBool(defs.UI_System.IsInMenu)
end

-- Items for the disassembly test: id -> expected to survive a pickup.
local ITEMS = {
    { "Items.Preset_Lexington_Default", false },
    { "Items.AnimalsJunkItem1", false },
    { "Items.Jacket_01_basic_01", false },
    { "Items.w_att_scope_short_01", false },
    { "Items.Preset_Overture_Kerry", true },
    { "Items.GrenadeFragRegular", true },
    { "Items.FirstAidWhiffV0", true },
}

local function questHash(journal, entry)
    if not entry then return 0 end
    local q = questLogGameController.GetTopQuestEntry(journal, entry)
    return q and journal:GetEntryHash(q) or 0
end

local function findOtherObjective(journal, excludeHash)
    local ctx = JournalRequestContext.new()
    local filter = JournalRequestStateFilter.new()
    filter.active = true
    ctx.stateFilter = filter
    local quests = journal:GetQuests(ctx)
    for _, q in ipairs(quests or {}) do
        if journal:GetEntryHash(q) ~= excludeHash then
            for _, phase in ipairs(journal:GetChildren(q, filter) or {}) do
                local objs = journal:GetChildren(phase, filter)
                if objs and #objs > 0 then return objs[1] end
            end
        end
    end
    return nil
end

local function gameTime() return Game.GetTimeSystem():GetGameTimeStamp() end

-- The driver writes rmb_done / esc_done after injecting input; screenshots of
-- a large desktop take seconds, so a fixed wait raced the driver.
local function acked(name)
    local f = io.open(name, "r")
    if f then f:close() os.remove(name) return true end
    return false
end

return {
    S = S, write = write, out = out, check = check, go = go, tdb = tdb, idstr = idstr,
    countItem = countItem, sys = sys, inMenu = inMenu, ITEMS = ITEMS, questHash = questHash,
    findOtherObjective = findOtherObjective, gameTime = gameTime, acked = acked,
}
