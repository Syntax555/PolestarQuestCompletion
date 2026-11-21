-- Independent Polestar Hub section for WoW: Forever.
-- Reads Polestar's existing data and the current character's quest state.

local PS = _G.Polestar
local UI, Q, C = PS and PS.UI, PS and PS.QuestDB, PS and PS.Compat
local Picker = UI and UI.Picker
local Codex = PS and PS.Codex
local SECTION = "QuestCompletion"

SLASH_POLESTARQUESTCOMPLETION1 = "/pqc"
SLASH_POLESTARQUESTCOMPLETION2 = "/polestarquests"
SlashCmdList.POLESTARQUESTCOMPLETION = function()
    print("Polestar Quest Completion: Installiere eine kompatible Polestar-Version (getestet mit 0.4.1.1).")
end

-- The hub and the QuestDB record interface are internal to Polestar.
local F = Q and Q.F
if not (UI and UI.RegisterSection and UI.ShowPicker and Picker and Picker.ShowSection and Picker.Render
    and Q and Q.IsLoaded and Q.Load and Q.QuestIds and Q.QuestRecord and Q.GetQuestTitle
    and Q.PlayerContext and Q.IsEligible and Q.CheckAvailable and Q.Each
    and F and F.ZONE and F.LEVEL and F.MIN and F.PRE and F.PRE_ALL and F.EXCL and F.SKILL
    and C and C.IsQuestCompleted and C.IsOnQuest) then
    return
end

local S = PolestarQuestCompletionDB
if type(S) ~= "table" then
    S = {}
    PolestarQuestCompletionDB = S
end

local STATUS = {
    available = { "Vermutlich verfügbar", 1.00, 0.82, 0.26, 1 },
    active    = { "Im Questlog",          0.40, 0.72, 1.00, 2 },
    blocked   = { "Gesperrt",             0.70, 0.72, 0.76, 3 },
    unknown   = { "Unklar",               0.86, 0.74, 0.52, 4 },
    done      = { "Abgeschlossen",       0.37, 0.87, 0.51, 5 },
}
if S.filter ~= "all" and not STATUS[S.filter] then S.filter = "all" end

local WHY = {
    unknown = "Keine Daten zu dieser Quest.",
    level = "Das Mindestlevel ist noch nicht erreicht.",
    prerequisite = "Eine Voraussetzung aus der Questkette fehlt.",
    exclusive = "Eine ausschließende Quest ist im Log oder abgeschlossen.",
    skill = "Die bekannte Berufsanforderung ist nicht erfüllt.",
    skill_unknown = "Fertigkeitsrang konnte nicht geprüft werden.",
    parent = "Die zugehörige Quest muss im Questlog stehen.",
    reputation = "Der laut Codex für Quest oder Belohnung nötige Rufrang fehlt.",
    reputation_unknown = "Der Charakterruf konnte nicht geprüft werden.",
}

local LOAD_ERROR = {
    off = "Aktiviere die Quest-Datenbank in Polestar unter Optionen → Questen → Quests.",
    missing = "Installiere den Ordner Polestar_QuestDB aus dem vollständigen Polestar-Release.",
    disabled = "Aktiviere Polestar_QuestDB im Add-on-Menü der Charakterauswahl.",
    combat = "Die Questdatenbank wird nach dem Kampf geladen.",
    empty = "Installiere Polestar und Polestar_QuestDB aus demselben Release.",
}

local ROW_HEIGHT = 29
local index, zones, cachedIDs, indexedFor
local root, scroll, child, heading, subtitle, counts, message, details, detailsHint
local buttons, pool = {}, {}
local snapshot, pending, rerenderHub, waitForCombat, waitForCodex, codexError
local dirty = true
local needle, previousZone = "", nil
local drawing = false
local codexSupported = Codex and Codex.Load and Codex.IsLoaded and Codex.Quest
local readable = C.Readable or function(value) return value end

local function hasCodex()
    return codexSupported and Codex.IsLoaded()
end

local function currentZone()
    if not (C_Map and C_Map.GetBestMapForUnit and index) then return nil end
    local id = C_Map.GetBestMapForUnit("player")
    for _ = 1, 8 do
        if not id then break end
        if index[id] then return id end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        id = info and info.parentMapID
    end
end

local function mapName(id)
    local name = C.MapName and C.MapName(id)
    return name or ("Zone #" .. id)
end

local function renderHub()
    if not drawing and root and root:IsVisible() then Picker.Render() end
end

local function loadQuestDB()
    if PS.Get and PS.Get("qol.questDB") == false then return false, "off" end
    if Q.IsLoaded() then return true end
    local ok, reason = Q.Load()
    if ok or reason ~= "off" or not (PS.Data and PS.Data.Pack) then return ok, reason end

    -- The DB remains useful when Polestar's other quest features are off.
    local loaded, failure = PS.Data.Pack(Q.ADDON or "Polestar_QuestDB")
    if Q.IsLoaded() then
        if PS.Fire then PS.Fire("QUESTDB_LOADED") end
        return true
    end
    return false, failure or (loaded and "empty" or "missing")
end

local function ensureIndex()
    local ok, reason = loadQuestDB()
    if not ok then return false, reason end

    local ids, ctx = Q.QuestIds(), Q.PlayerContext()
    local key = table.concat({ tostring(ctx.faction), tostring(ctx.raceBit),
        tostring(ctx.raceHigh), tostring(ctx.classBit) }, ":")
    if ids == cachedIDs and key == indexedFor then return true end

    index, zones = {}, {}
    for _, id in ipairs(ids) do
        local record = Q.QuestRecord(id)
        local zone = record and record[F.ZONE]
        if type(zone) == "number" and zone > 0 and Q.IsEligible(record, ctx) then
            local entry = index[zone]
            if not entry then
                entry = { id = zone, name = mapName(zone), ids = {} }
                index[zone] = entry
                zones[#zones + 1] = entry
            end
            entry.ids[#entry.ids + 1] = id
        end
    end
    table.sort(zones, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    cachedIDs, indexedFor = ids, key
    dirty = true
    return true
end

local function chosenZone()
    if S.zone and index[S.zone] then return S.zone end
    S.zone = currentZone() or (zones[1] and zones[1].id)
    return S.zone
end

local function completionAccessor()
    local done = {}
    if Q._client and Q._client.CompletedSet and Q._client.CompletedSet(done) then
        return function(id) return done[id] == true end
    end
    return function(id)
        if done[id] == nil then done[id] = C.IsQuestCompleted(id) end
        return done[id]
    end
end

local function fold(text)
    if PS.Search and PS.Search.Fold then return (PS.Search.Fold(text):gsub("^ ", "")) end
    return text:lower()
end

local function questTitle(id)
    return Q.GetQuestTitle(id) or ("Quest #" .. id)
end

local function missing(field, isDone, any)
    local missingIDs
    for _, id in Q.Each(field) do
        if isDone(id) then
            if any then return end
        else
            missingIDs = missingIDs or {}
            missingIDs[#missingIDs + 1] = id
        end
    end
    return missingIDs
end

local function exclusions(field, isDone, isOn, found)
    for _, id in Q.Each(field) do
        if isDone(id) or isOn(id) then
            found = found or {}
            found[id] = true
        end
    end
    return found
end

local function standingName(rank)
    return (PS.StandingName and PS.StandingName(rank)) or ("Rang " .. rank)
end

local function zoneSnapshot(zone, useCodex)
    local rows = {}
    local totals = { available = 0, active = 0, blocked = 0, unknown = 0, done = 0 }
    if not zone then return { rows = rows, totals = totals, useCodex = useCodex } end

    local ctx = Q.PlayerContext()
    local isDone = completionAccessor()
    local active, skills, factions = {}, {}, {}
    local canReadSkill = C.GetSkillRank and C.Supports and C.Supports("skill")
    local function isOn(id)
        if active[id] == nil then active[id] = C.IsOnQuest(id) end
        return active[id]
    end
    local function skillRank(line)
        if not canReadSkill then return nil end
        if skills[line] == nil then skills[line] = C.GetSkillRank(line) or 0 end
        return skills[line]
    end
    local function faction(id)
        if not factions[id] then
            local rank, name
            if C.GetFactionStanding then
                local ok, standing, _, _, _, factionName = pcall(C.GetFactionStanding, id)
                if ok then
                    rank, name = readable(standing), readable(factionName)
                end
            end
            local data = not name and Codex.Faction and Codex.Faction(id)
            factions[id] = { rank = rank, name = name or (data and data.name) or ("Fraktion #" .. id) }
        end
        return factions[id]
    end
    local opts = { lowLevel = true, skillRank = skillRank }
    for _, id in ipairs(index[zone].ids) do
        local r = Q.QuestRecord(id)
        local extra = useCodex and Codex.Quest(id)
        local title = questTitle(id)
        local row = { id = id, title = title, searchTitle = fold(title), level = r[F.LEVEL], minLevel = r[F.MIN] }
        local line = (extra and extra.skill) or r[F.SKILL]
        if line then
            row.skill = line
            row.rankNeeded = extra and extra.skillRank or nil
            row.rank = skillRank(line)
        end
        if extra and extra.repFaction and extra.repStanding then
            row.rep, row.repNeeded = faction(extra.repFaction), extra.repStanding
        end

        local state, why = "available", nil
        if isDone(id) then
            state = "done"
        elseif isOn(id) then
            state = "active"
        else
            local available
            available, why = Q.CheckAvailable(id, ctx, isDone, isOn, opts)
            if not available then state = "blocked" end
            row.missingAll = missing(r[F.PRE_ALL] or (extra and extra.pre) or nil, isDone)
            row.missingAny = missing(r[F.PRE] or (extra and extra.preAny) or nil, isDone, true)
            row.conflicts = exclusions(r[F.EXCL], isDone, isOn)
            if extra and extra.closedBy then
                row.conflicts = exclusions(extra.closedBy, isDone, isOn, row.conflicts)
            end
            if extra and extra.parent and not isOn(extra.parent) then row.parent = extra.parent end

            if state == "available" then
                if row.missingAll or row.missingAny then
                    state, why = "blocked", "prerequisite"
                elseif row.conflicts then
                    state, why = "blocked", "exclusive"
                elseif row.parent then
                    state, why = "blocked", "parent"
                elseif row.skill and row.rank == nil then
                    state, why = "unknown", "skill_unknown"
                elseif row.skill and row.rank < math.max(1, row.rankNeeded or 0) then
                    state, why = "blocked", "skill"
                elseif row.rep and row.rep.rank == nil then
                    state, why = "unknown", "reputation_unknown"
                elseif row.rep and row.rep.rank < row.repNeeded then
                    state, why = "blocked", "reputation"
                end
            end
        end
        row.state, row.reason = state, why
        totals[state] = totals[state] + 1
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b)
        if a.state ~= b.state then return STATUS[a.state][5] < STATUS[b.state][5] end
        local aLevel, bLevel = a.level or 0, b.level or 0
        if aLevel ~= bLevel then return aLevel < bLevel end
        if a.title ~= b.title then return a.title < b.title end
        return a.id < b.id
    end)
    return { zone = zone, rows = rows, totals = totals, useCodex = useCodex }
end

local function addPrereqs(tooltip, ids, label)
    if not ids then return end
    tooltip:AddLine(label, 1, 0.76, 0.3)
    for _, id in ipairs(ids) do
        tooltip:AddLine("• " .. questTitle(id), 0.85, 0.85, 0.85, true)
    end
end

local function statusText(row)
    return row.reason == "reputation" and "Ruf fehlt" or STATUS[row.state][1]
end

local function makeRow(i)
    local b = CreateFrame("Button", nil, child)
    b:SetHeight(ROW_HEIGHT - 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.12, 0.18, i % 2 == 0 and 0.39 or 0.18)
    b.levelText = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.levelText:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.levelText:SetWidth(42)
    b.levelText:SetJustifyH("LEFT")
    b.questText = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    b.questText:SetPoint("LEFT", b, "LEFT", 53, 0)
    b.questText:SetPoint("RIGHT", b, "RIGHT", -174, 0)
    b.questText:SetJustifyH("LEFT")
    b.questText:SetWordWrap(false)
    b.statusText = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.statusText:SetPoint("RIGHT", b, "RIGHT", -9, 0)
    b.statusText:SetWidth(161)
    b.statusText:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self)
        local r = self.data
        if not r then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(r.title, 1, 0.86, 0.37)
        GameTooltip:AddLine("Quest-ID: " .. r.id .. "  |  Level: " .. tostring(r.level or "?"), 1, 1, 1)
        local s = STATUS[r.state]
        GameTooltip:AddLine(statusText(r), s[2], s[3], s[4])
        if r.minLevel then GameTooltip:AddLine("Mindestlevel: " .. r.minLevel, 0.83, 0.83, 0.83) end
        if r.reason and WHY[r.reason] then GameTooltip:AddLine(WHY[r.reason], 1, 0.63, 0.3, true) end
        addPrereqs(GameTooltip, r.missingAll, "Alle diese Vorquests fehlen:")
        addPrereqs(GameTooltip, r.missingAny, "Eine dieser Vorquests wird benötigt:")
        if r.parent then GameTooltip:AddLine("Benötigt im Questlog: " .. questTitle(r.parent), 1, 0.76, 0.3, true) end
        if r.conflicts then
            GameTooltip:AddLine("Ausschließende Quests im Log oder abgeschlossen:", 1, 0.76, 0.3, true)
            for id in pairs(r.conflicts) do
                GameTooltip:AddLine("• " .. questTitle(id), 0.85, 0.85, 0.85, true)
            end
        end
        if r.skill then
            local name = (C.GetSkillLineName and C.GetSkillLineName(r.skill)) or ("Fertigkeit #" .. r.skill)
            local need = r.rankNeeded and (" " .. r.rankNeeded) or ""
            local have = r.rank ~= nil and tostring(r.rank) or "unbekannt"
            GameTooltip:AddLine(("Beruf: %s%s (aktuell: %s)"):format(name, need, have), 0.83, 0.83, 0.83, true)
        end
        if r.rep then
            local have = r.rep.rank and standingName(r.rep.rank) or "unbekannt"
            GameTooltip:AddLine(("Ruf: %s – %s (aktuell: %s)"):format(r.rep.name, standingName(r.repNeeded), have),
                0.83, 0.83, 0.83, true)
        end
        GameTooltip:AddLine("Klicken: Quest in Polestar öffnen", 0.5, 0.83, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if not self.data then return end
        if UI.ShowLookup then
            UI.ShowLookup({ query = self.data.title, kind = "quest", id = self.data.id })
        elseif Picker.ShowQuest then
            Picker.ShowQuest(self.data.id)
        end
    end)
    pool[i] = b
    return b
end

local function refresh(repaintOnly)
    if drawing or not root then return end
    drawing = true

    local ok, reason = true, nil
    if not repaintOnly or not snapshot then ok, reason = ensureIndex() end
    waitForCombat = reason == "combat"
    if not ok then
        snapshot = nil
        heading:SetText("Quest Completion")
        subtitle:SetText("Questdatenbank nicht verfügbar")
        counts:SetText("")
        details:Hide()
        detailsHint:SetText("")
        message:SetText(LOAD_ERROR[reason] or ("QuestDB konnte nicht geladen werden (" .. tostring(reason) .. ")."))
        message:Show()
        for _, row in ipairs(pool) do row:Hide() end
        child:SetHeight(1)
        drawing = false
        return
    end

    local zone = chosenZone()
    local useCodex = hasCodex() and true or false
    if dirty or not snapshot or snapshot.zone ~= zone or snapshot.useCodex ~= useCodex then
        snapshot = zoneSnapshot(zone, useCodex)
        dirty = false
    end
    local available, active, blocked, unknown, done = snapshot.totals.available, snapshot.totals.active,
        snapshot.totals.blocked, snapshot.totals.unknown, snapshot.totals.done
    local total = available + active + blocked + unknown + done
    local newNeedle = fold((Picker.Query and Picker.Query()) or needle)
    local resetScroll = zone ~= previousZone or newNeedle ~= needle
    previousZone, needle = zone, newNeedle

    heading:SetText(zone and index[zone].name or "Keine Zone gefunden")
    if total > 0 then
        local pct = math.floor(done * 100 / total + 0.5)
        if done < total then pct = math.min(pct, 99) end
        subtitle:SetText(("%d / %d abgeschlossen (%d %%)"):format(done, total, pct))
    else
        subtitle:SetText("– / – abgeschlossen")
    end
    counts:SetText(("%d verfügbar  ·  %d im Log  ·  %d gesperrt  ·  %d unklar"):format(available, active, blocked, unknown))
    details:SetShown(codexSupported and not useCodex or false)
    if useCodex then
        detailsHint:SetText("Ruf und Voraussetzungen laut Polestar. Details beim Überfahren einer Quest.")
    elseif not codexSupported then
        detailsHint:SetText("Verfügbarkeit geschätzt. Rufdetails benötigen eine kompatible Polestar-Codex-Version.")
    elseif waitForCodex then
        detailsHint:SetText("Der Codex wird nach dem Kampf geladen.")
    elseif codexError then
        detailsHint:SetText("Codex nicht verfügbar. Prüfe Polestar_Codex in deiner Polestar-Installation.")
    else
        detailsHint:SetText("Verfügbarkeit geschätzt. Für bekannte Rufanforderungen den Codex laden.")
    end
    for key, button in pairs(buttons) do
        if key == S.filter then button:LockHighlight() else button:UnlockHighlight() end
    end

    local width = math.max(1, child:GetWidth() - 8)
    local visible = 0
    for _, data in ipairs(snapshot.rows) do
        if (S.filter == "all" or S.filter == data.state)
            and (needle == "" or data.searchTitle:find(needle, 1, true) or tostring(data.id):find(needle, 1, true)) then
            visible = visible + 1
            local row = pool[visible] or makeRow(visible)
            local status = STATUS[data.state]
            row.data = data
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -((visible - 1) * ROW_HEIGHT + 3))
            row:SetWidth(width)
            row.questText:SetText(data.title)
            row.questText:SetTextColor(status[2], status[3], status[4])
            row.levelText:SetText(data.level and ("[" .. data.level .. "]") or "[?]")
            row.statusText:SetText(statusText(data))
            row.statusText:SetTextColor(status[2], status[3], status[4])
            row:Show()
        end
    end
    for i = visible + 1, #pool do pool[i]:Hide() end
    child:SetHeight(math.max(1, visible * ROW_HEIGHT + 8))
    message:SetText(total == 0 and "Keine Quests mit Zonenkennung für diesen Charakter gefunden."
        or "Keine Quests zu diesem Filter gefunden.")
    message:SetShown(visible == 0)
    if resetScroll then scroll:SetVerticalScroll(0) end
    drawing = false
end

local function loadDetails()
    local ok, reason = Codex.Load()
    waitForCodex = reason == "combat"
    codexError = not (ok or waitForCodex)
    refresh()
end

local function filterButton(key, label, x, width)
    local button = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", root, "TOPLEFT", x, -72)
    button:SetText(label)
    button:SetScript("OnClick", function()
        S.filter = key
        scroll:SetVerticalScroll(0)
        refresh(true)
    end)
    buttons[key] = button
end

local function build(parent)
    root = parent
    root:HookScript("OnShow", function() dirty = true end)
    heading = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -12)
    heading:SetJustifyH("LEFT")

    subtitle = root:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    subtitle:SetJustifyH("LEFT")
    counts = root:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    counts:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -5)
    counts:SetJustifyH("LEFT")

    local now = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    now:SetSize(120, 23)
    now:SetPoint("TOPRIGHT", root, "TOPRIGHT", -18, -10)
    now:SetText("Aktuelle Zone")
    now:SetScript("OnClick", function()
        local zone = currentZone()
        if zone and zone ~= S.zone then
            S.zone = zone
            renderHub()
        end
    end)

    details = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    details:SetSize(112, 23)
    details:SetPoint("TOPRIGHT", now, "BOTTOMRIGHT", 0, -5)
    details:SetText("Ruf & Details")
    details:SetScript("OnClick", loadDetails)

    filterButton("all", "Alle", 14, 58)
    filterButton("available", "Verfügbar", 76, 92)
    filterButton("active", "Im Log", 172, 68)
    filterButton("blocked", "Gesperrt", 244, 84)
    filterButton("unknown", "Unklar", 332, 72)
    filterButton("done", "Fertig", 408, 64)
    detailsHint = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detailsHint:SetPoint("TOPLEFT", root, "TOPLEFT", 18, -104)
    detailsHint:SetPoint("RIGHT", root, "RIGHT", -18, 0)
    detailsHint:SetJustifyH("LEFT")

    scroll = CreateFrame("ScrollFrame", "PolestarQuestCompletionScroll", root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 13, -134)
    scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -33, 14)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(480, 1)
    scroll:SetScrollChild(child)
    -- The hub anchors the section after its first render.
    scroll:SetScript("OnSizeChanged", function(_, width)
        if width <= 0 then return end
        child:SetWidth(width)
        for _, row in ipairs(pool) do row:SetWidth(math.max(1, width - 8)) end
    end)
    message = root:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("LEFT", scroll, "LEFT", 12, 0)
    message:SetPoint("RIGHT", scroll, "RIGHT", -12, 0)
    message:SetJustifyH("CENTER")
    message:Hide()
end

local function nav()
    if not snapshot then return { { key = "none", label = "Keine Daten" } }, "none" end
    local items = {}
    for _, zone in ipairs(zones) do
        items[#items + 1] = { key = tostring(zone.id), label = zone.name, count = #zone.ids, icon = "guides" }
    end
    return items, tostring(snapshot.zone or "")
end

if not UI.RegisterSection({
    key = SECTION,
    label = "Quests",
    icon = "guides",
    order = 35,
    build = build,
    render = refresh,
    nav = nav,
    onNav = function(key)
        local id = tonumber(key)
        if id and index and index[id] and id ~= S.zone then
            S.zone = id
            renderHub()
        end
    end,
    search = function(text)
        if not Picker.Query then
            needle = text
            scroll:SetVerticalScroll(0)
        end
        refresh(true)
    end,
    searchPlaceholder = "Questname oder Quest-ID suchen",
}) then return end

SlashCmdList.POLESTARQUESTCOMPLETION = function()
    Picker.ShowSection(SECTION)
    UI.ShowPicker()
end

local function scheduleRefresh(updateHub)
    dirty = true
    if not (root and root:IsVisible()) then return end
    rerenderHub = rerenderHub or updateHub
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        local renderNavigation = rerenderHub or not snapshot
        rerenderHub = nil
        pending = false
        if root:IsVisible() then
            if renderNavigation then renderHub() else refresh() end
        end
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
    "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "UPDATE_FACTION", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if waitForCodex and root and root:IsVisible() then loadDetails() end
        if waitForCombat then scheduleRefresh() end
    elseif root and (event ~= "UPDATE_FACTION" or hasCodex()) then
        scheduleRefresh()
    end
end)

if PS.On then
    PS.On("SETTING_CHANGED", function(path)
        if path == "qol.questDB" or path == "qol" or path == "" then scheduleRefresh(true) end
    end)
    PS.On("CODEX_LOADED", function() scheduleRefresh() end)
end
