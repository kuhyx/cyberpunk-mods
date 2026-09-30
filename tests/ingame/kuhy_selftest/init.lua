-- In-game self-test for the Kuhy mods. Installed only by
-- scripts/ingame_selftest.sh, never by install.sh.
--
-- Runs a phased state machine once the auto-continued save is live, writes
-- PASS/FAIL lines to results.txt and its current phase to state.txt (the
-- driver script watches state.txt to inject real mouse/keyboard input for the
-- fast-travel map test), then exits the game.

local H = require("helpers")
local S, write, out, check, go, tdb, idstr, countItem, sys, inMenu, ITEMS, questHash, findOtherObjective, gameTime, acked =
    H.S, H.write, H.out, H.check, H.go, H.tdb, H.idstr, H.countItem, H.sys, H.inMenu, H.ITEMS, H.questHash, H.findOtherObjective, H.gameTime, H.acked

local PHASES = {}

PHASES.boot = function()
    if Game.GetPlayer() and not Game.GetSystemRequestsHandler():IsPreGame() then
        check("auto_continue: save loaded with no input", true)
        go("settle")
    elseif S.t > 240 then
        check("auto_continue: save loaded with no input", false, "no player after 240 s")
        go("quit")
    end
end


-- The world must start running on its own: a "press to continue" stall
-- leaves game time frozen. Wait up to 90 s for it to advance; the driver
-- presses Space on need_continue so the remaining tests can still run.
PHASES.settle = function()
    if not S.data.gt0 then S.data.gt0 = gameTime() end
    local advanced = gameTime() - S.data.gt0
    if advanced > 30 then
        check("auto_continue: world running without input (no press-to-continue)", true,
            string.format("game time advanced %.0f s after %.0f s", advanced, S.t))
        go("wait_sweep")
    elseif S.t > 90 then
        check("auto_continue: world running without input (no press-to-continue)", false,
            string.format("game time advanced %.0f s in 90 s", advanced))
        S.data.gt0 = gameTime()
        go("need_continue")
    end
end

PHASES.need_continue = function()
    if gameTime() - S.data.gt0 > 30 then go("wait_sweep") end
    if S.t > 60 then check("world never started", false) go("quit") end
end

PHASES.wait_sweep = function() if S.t > 15 then go("disassemble_sweep") end end

PHASES.disassemble_sweep = function()
    local ad = sys("Kuhy.AutoDisassemble.AutoDisassembleSystem")
    local left = ad and #ad:Eligible(Game.GetPlayer()) or -1
    check("auto_disassemble: ready after load sweep", ad and ad:IsReady(), tostring(ad and ad:IsReady()))
    check("auto_disassemble: load sweep left nothing eligible", left == 0, "eligible=" .. left)
    for _, it in ipairs(ITEMS) do S.data[it[1]] = countItem(it[1]) end
    for _, it in ipairs(ITEMS) do
        S.data["given_" .. it[1]] = Game.GetTransactionSystem():GiveItemByTDBID(Game.GetPlayer(), tdb(it[1]), 1)
    end
    go("disassemble_pickup")
end

PHASES.disassemble_pickup = function()
    if S.t < 3 then return end
    local ad = sys("Kuhy.AutoDisassemble.AutoDisassembleSystem")
    local ok, items = Game.GetTransactionSystem():GetItemList(Game.GetPlayer())
    for _, data in ipairs(items or {}) do
        if idstr(data:GetID()) == "Items.w_att_scope_short_01" then
            local id = data:GetID()
            out(string.format("INFO scope: category=%s type=%s canDisassemble=%s eligible=%s",
                tostring(RPGManager.GetItemCategory(id)), tostring(RPGManager.GetItemType(id)),
                tostring(sys("CraftingSystem"):CanItemBeDisassembled(Game.GetPlayer(), id)),
                tostring(ad:IsEligible(Game.GetPlayer(), data))))
        end
    end
    for _, it in ipairs(ITEMS) do
        local before, now = S.data[it[1]], countItem(it[1])
        local given = S.data["given_" .. it[1]]
        local survived = now > before
        if it[2] and not survived then
            out("INFO " .. it[1] .. " not in inventory after give (given=" .. tostring(given) .. ") -- not a mod decision")
        else
            check("auto_disassemble: pickup " .. it[1] .. (it[2] and " kept" or " disassembled"),
                survived == it[2], "before=" .. before .. " after=" .. now)
        end
        if survived then Game.GetTransactionSystem():RemoveItemByTDBID(Game.GetPlayer(), tdb(it[1]), now - before) end
    end
    go("track_setup")
end

PHASES.track_setup = function()
    local journal = Game.GetJournalManager()
    S.data.orig = journal:GetTrackedEntry()
    S.data.origQuest = questHash(journal, S.data.orig)
    S.data.other = findOtherObjective(journal, S.data.origQuest)
    if not S.data.other then
        check("no_auto_track: needs a second active quest", false, "none found")
        go("radio") return
    end
    journal:TrackEntry(S.data.other) -- no player intent: must be reverted
    go("track_auto")
end

PHASES.track_auto = function()
    if S.t < 2 then return end
    local journal = Game.GetJournalManager()
    local now = questHash(journal, journal:GetTrackedEntry())
    check("no_auto_track: automatic switch reverted", now == S.data.origQuest,
        "orig=" .. S.data.origQuest .. " now=" .. now)
    sys("Kuhy.NoAutoTrack.NoAutoTrackSystem"):MarkPlayerIntent()
    journal:TrackEntry(S.data.other)
    go("track_user")
end

PHASES.track_user = function()
    if S.t < 2 then return end
    local journal = Game.GetJournalManager()
    local now = questHash(journal, journal:GetTrackedEntry())
    local want = questHash(journal, S.data.other)
    check("no_auto_track: player's own switch kept", now == want, "want=" .. want .. " now=" .. now)
    sys("Kuhy.NoAutoTrack.NoAutoTrackSystem"):MarkPlayerIntent()
    if S.data.orig then journal:TrackEntry(S.data.orig) else journal:UntrackEntry() end
    go("radio")
end

PHASES.radio = function()
    local player = Game.GetPlayer()
    local radio = sys("Kuhy.RadioInCombat.RadioInCombatSystem")
    local pocket = player:GetPocketRadio()
    if pocket:IsActive() then pocket:HandleRadioToggleEvent(RadioToggleEvent.new()) end
    radio:OnCombatChanged(player, true)
    S.data.toneNoRadio = radio:IsCombatToneSent()
    pocket:HandleRadioToggleEvent(RadioToggleEvent.new())
    go("radio_on")
end

PHASES.radio_on = function()
    if S.t < 4 then return end
    local player = Game.GetPlayer()
    local radio = sys("Kuhy.RadioInCombat.RadioInCombatSystem")
    local pocket = player:GetPocketRadio()
    check("radio_in_combat: combat music when no radio", S.data.toneNoRadio == true, tostring(S.data.toneNoRadio))
    check("radio_in_combat: pocket radio turned on", pocket:IsActive(), tostring(pocket:IsActive()))
    check("radio_in_combat: combat music withheld while radio plays", radio:IsCombatToneSent() == false, tostring(radio:IsCombatToneSent()))
    pocket:HandleRadioToggleEvent(RadioToggleEvent.new())
    radio:OnCombatChanged(player, false)
    go("ft_open")
end

PHASES.ft_open = function()
    if S.t < 1 then return end
    Game.GetUISystem():RequestFastTravelMenu()
    go("ft_wait_open")
end

PHASES.ft_wait_open = function()
    if inMenu() and S.t > 6 then go("ft_ready_for_rmb") -- driver right-clicks now
    elseif S.t > 20 then check("fast_travel_map: menu opened", false) go("quit") end
end

PHASES.ft_ready_for_rmb = function()
    if acked("rmb_done") then S.data.ackAt = S.t end
    if S.data.ackAt and S.t - S.data.ackAt > 2 then S.data.ackAt = nil go("ft_after_rmb") end
    if S.t > 60 then check("fast_travel_map: driver never right-clicked", false) go("quit") end
end

PHASES.ft_after_rmb = function()
    check("fast_travel_map: right-click did not close the menu", inMenu())
    go("ft_ready_for_esc") -- driver presses Esc now
end

PHASES.ft_ready_for_esc = function()
    if acked("esc_done") then S.data.ackAt = S.t end
    if S.data.ackAt and S.t - S.data.ackAt > 3 then
        check("fast_travel_map: Esc closed the menu", not inMenu())
        go("quit")
    elseif S.t > 60 then
        check("fast_travel_map: driver never pressed Esc", false) go("quit")
    end
end

PHASES.quit = function()
    if S.t < 1 then return end
    out("DONE fails=" .. S.fails)
    go("done")
    Game.GetSystemRequestsHandler():ExitGame()
end

PHASES.done = function() end

registerForEvent("onInit", function()
    write("results.txt", "w", "")
    go("boot")
end)

registerForEvent("onUpdate", function(dt)
    S.t = S.t + dt
    local ok, err = pcall(PHASES[S.phase])
    if not ok then
        check("phase " .. S.phase .. " raised", false, tostring(err))
        go("quit")
    end
end)
