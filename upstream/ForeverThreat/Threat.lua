local addonName, FT = ...

local function Clamp(value, low, high)
    if value < low then
        return low
    elseif value > high then
        return high
    end
    return value
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB then
        return false
    end

    local ok, same = pcall(UnitIsUnit, unitA, unitB)

    if not ok then
        return false
    end

    -- WoW Forever may return a protected/secret boolean here.
    -- Do not evaluate it as a boolean until it has been checked.
    if FT:IsSecret(same) then
        return false
    end

    return same == true
end

local function SafeUnitCanAttack(unitA, unitB)
    local ok, hostile = pcall(UnitCanAttack, unitA, unitB)

    if not ok or FT:IsSecret(hostile) then
        return nil
    end

    return hostile == true
end

local function SafeUnitGroupRole(unit)
    if type(_G.UnitGroupRolesAssigned) ~= "function" or not unit then
        return nil
    end

    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if not ok or FT:IsSecret(role) or type(role) ~= "string" then
        return nil
    end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end

    return nil
end

local RAID_STAGED_SCAN_MIN_MEMBERS = 30
local RAID_FULL_SCAN_INTERVAL = 1.25
local RAID_PRIORITY_COUNT = 8

local function SafeThreatUnitGUID(unit)
    if type(_G.UnitGUID) ~= "function" then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)
    if not ok or FT:IsSecret(guid) or guid == nil then
        return nil
    end

    return guid
end

local function CloneThreatEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local copy = {}
    for key, value in pairs(entry) do
        copy[key] = value
    end

    -- Derived fields are recalculated every display pass.
    copy.targetTarget = false
    copy.isAggroHolder = false
    copy.threatDelta = nil
    copy.threatGap = nil
    copy.threatRank = nil
    copy.tps = nil
    copy.scaledRate = nil
    copy.threatEta = nil
    copy.etaIsLead = nil
    return copy
end

function FT:GetThreatSourceUnit()
    if self.db and self.db.threatSource == "FOCUS" then
        return "focus"
    end

    return "target"
end

function FT:GetThreatSourceTargetUnit(sourceUnit)
    sourceUnit = sourceUnit or self:GetThreatSourceUnit()

    if sourceUnit == "focus" then
        return "focustarget"
    end

    return "targettarget"
end

local function AddUnit(units, unit, isPet, ownerUnit)
    if not UnitExists(unit) then
        return
    end

    local name = UnitName(unit)
    local _, classToken = UnitClass(unit)
    local ownerName = nil
    local groupRole = nil

    if ownerUnit and UnitExists(ownerUnit) then
        ownerName = UnitName(ownerUnit)
    end

    if not isPet then
        groupRole = SafeUnitGroupRole(unit)
    end

    units[#units + 1] = {
        unit = unit,
        isPet = isPet and true or false,
        ownerUnit = ownerUnit,

        -- Static roster metadata is cached so these lookups do not have to be
        -- repeated on every threat refresh in 20/40-player raids.
        name = name,
        classToken = classToken,
        ownerName = ownerName,
        isPlayer = SafeUnitIsUnit(unit, "player"),
        groupRole = groupRole,
        isGroupTank = groupRole == "TANK",
    }
end

function FT:ResetRaidThreatScanCache()
    self.raidThreatCache = nil
    self.raidThreatCacheSourceKey = nil
    self.raidThreatLastFullScan = nil
    self.raidThreatPriorityUnits = nil
end

function FT:InvalidateGroupUnitCache()
    self.groupUnitCache = nil
    self.groupUnitCacheKey = nil
    self:ResetRaidThreatScanCache()
end

function FT:GetGroupUnits()
    local showPets = self.db and self.db.showPets and true or false
    local showRaidPets = self.db and self.db.showRaidPets and true or false
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()
    local count = 1

    if inRaid then
        count = GetNumGroupMembers()
    elseif inGroup then
        count = GetNumSubgroupMembers() + 1
    end

    local cacheKey = table.concat({
        inRaid and "R" or (inGroup and "P" or "S"),
        tostring(count),
        showPets and "1" or "0",
        showRaidPets and "1" or "0",
    }, ":")

    if self.groupUnitCache and self.groupUnitCacheKey == cacheKey then
        return self.groupUnitCache
    end

    local units = {}

    if inRaid then
        local raidCount = GetNumGroupMembers()

        for i = 1, raidCount do
            AddUnit(units, "raid" .. i, false, nil)

            if showPets and showRaidPets then
                AddUnit(units, "raidpet" .. i, true, "raid" .. i)
            end
        end

        -- With normal pet display enabled we still keep the player's own pet
        -- visible in raids. Scanning every raid pet is a separate opt-in
        -- because it can nearly double the unit workload in pet-heavy raids.
        if showPets and not showRaidPets then
            AddUnit(units, "pet", true, "player")
        end

    elseif inGroup then
        AddUnit(units, "player", false, nil)

        if showPets then
            AddUnit(units, "pet", true, "player")
        end

        local partyCount = GetNumSubgroupMembers()

        for i = 1, partyCount do
            AddUnit(units, "party" .. i, false, nil)

            if showPets then
                AddUnit(units, "partypet" .. i, true, "party" .. i)
            end
        end

    else
        AddUnit(units, "player", false, nil)

        if showPets then
            AddUnit(units, "pet", true, "player")
        end
    end

    self.groupUnitCache = units
    self.groupUnitCacheKey = cacheKey
    return units
end

function FT:GetThreatEntry(unitInfo, sourceUnit)
    sourceUnit = sourceUnit or self:GetThreatSourceUnit()

    local unit = type(unitInfo) == "table" and unitInfo.unit or unitInfo
    local isPet = type(unitInfo) == "table" and unitInfo.isPet or false
    local ownerUnit = type(unitInfo) == "table" and unitInfo.ownerUnit or nil

    if not unit or not UnitExists(unit) then
        return nil
    end

    local cached = type(unitInfo) == "table" and unitInfo or nil

    local name = cached and cached.name or UnitName(unit)
    if not name then
        return nil
    end

    local classToken = cached and cached.classToken or nil
    if not classToken then
        _, classToken = UnitClass(unit)
    end

    local connected = UnitIsConnected(unit)
    if connected == nil then
        connected = true
    end

    local dead = UnitIsDeadOrGhost(unit)

    local ownerName = cached and cached.ownerName or nil
    if not ownerName and ownerUnit and UnitExists(ownerUnit) then
        ownerName = UnitName(ownerUnit)
    end

    local isPlayer
    if cached and cached.isPlayer ~= nil then
        isPlayer = cached.isPlayer == true
    else
        isPlayer = SafeUnitIsUnit(unit, "player")
    end

    local groupRole = cached and cached.groupRole or nil
    if not groupRole and not isPet then
        groupRole = SafeUnitGroupRole(unit)
    end

    local entry = {
        unit = unit,
        name = name,
        classToken = classToken,
        connected = connected ~= false,
        dead = dead and true or false,
        isPlayer = isPlayer,
        isPet = isPet and true or false,
        ownerUnit = ownerUnit,
        ownerName = ownerName,
        groupRole = groupRole,
        isGroupTank = groupRole == "TANK",

        isTanking = false,
        status = nil,
        scaled = nil,
        rawPct = nil,
        rawThreat = nil,
        restricted = false,
        targetTarget = false,

        isAggroHolder = false,
        threatDelta = nil,
        threatGap = nil,
    }

    if entry.connected and not entry.dead then
        local ok, isTanking, status, scaled, rawPct, rawThreat =
            pcall(UnitDetailedThreatSituation, unit, sourceUnit)

        if ok then
            if FT:IsSafe(isTanking) then
                entry.isTanking = isTanking and true or false
            elseif isTanking ~= nil then
                entry.restricted = true
            end

            if FT:IsSafe(status) then
                entry.status = status
            elseif status ~= nil then
                entry.restricted = true
            end

            if FT:IsSafe(scaled) then
                entry.scaled = scaled
            elseif scaled ~= nil then
                entry.restricted = true
            end

            if FT:IsSafe(rawPct) then
                entry.rawPct = rawPct
            elseif rawPct ~= nil then
                entry.restricted = true
            end

            if FT:IsSafe(rawThreat) then
                entry.rawThreat = rawThreat
            elseif rawThreat ~= nil then
                entry.restricted = true
            end
        end

        if entry.status == nil then
            local okStatus, fallbackStatus = pcall(UnitThreatSituation, unit, sourceUnit)

            if okStatus and FT:IsSafe(fallbackStatus) then
                entry.status = fallbackStatus
            elseif okStatus and fallbackStatus ~= nil then
                entry.restricted = true
            end
        end

    end

    return entry
end


function FT:GetRaidThreatSourceKey(sourceUnit)
    local guid = SafeThreatUnitGUID(sourceUnit)
    if guid then
        return guid
    end

    local ok, name = pcall(UnitName, sourceUnit)
    if ok and not self:IsSecret(name) and name and name ~= "" then
        return tostring(sourceUnit) .. ":" .. tostring(name)
    end

    return tostring(sourceUnit or "target")
end

function FT:ShouldUseStagedRaidScan()
    if not self.db
        or self.db.adaptiveRaidUpdates == false
        or self.db.optimizedRaidScan ~= true
        or not IsInRaid() then
        return false
    end

    local count = GetNumGroupMembers()
    return type(count) == "number" and count >= RAID_STAGED_SCAN_MIN_MEMBERS
end

function FT:CollectThreatEntries(sourceUnit)
    local units = self:GetGroupUnits()

    if not self:ShouldUseStagedRaidScan() then
        if self.raidThreatCache then
            self:ResetRaidThreatScanCache()
        end

        local data = {}
        for _, unitInfo in ipairs(units) do
            local entry = self:GetThreatEntry(unitInfo, sourceUnit)
            if entry then
                data[#data + 1] = entry
            end
        end
        return data
    end

    local sourceKey = self:GetRaidThreatSourceKey(sourceUnit)
    if self.raidThreatCacheSourceKey ~= sourceKey then
        self:ResetRaidThreatScanCache()
        self.raidThreatCacheSourceKey = sourceKey
    end

    self.raidThreatCache = self.raidThreatCache or {}
    self.raidThreatPriorityUnits = self.raidThreatPriorityUnits or {}

    local now = GetTime()
    local fullScan = not self.raidThreatLastFullScan
        or (now - self.raidThreatLastFullScan) >= RAID_FULL_SCAN_INTERVAL

    local sourceTargetUnit = self:GetThreatSourceTargetUnit(sourceUnit)
    local data = {}

    for _, unitInfo in ipairs(units) do
        local unit = unitInfo.unit
        local shouldScan = fullScan
            or unitInfo.isPlayer == true
            or self.raidThreatPriorityUnits[unit] == true

        if not shouldScan and UnitExists(sourceTargetUnit) then
            shouldScan = SafeUnitIsUnit(sourceTargetUnit, unit)
        end

        local entry
        if shouldScan or not self.raidThreatCache[unit] then
            entry = self:GetThreatEntry(unitInfo, sourceUnit)
            if entry then
                self.raidThreatCache[unit] = CloneThreatEntry(entry)
            else
                self.raidThreatCache[unit] = nil
            end
        else
            entry = CloneThreatEntry(self.raidThreatCache[unit])
        end

        if entry then
            data[#data + 1] = entry
        end
    end

    if fullScan then
        self.raidThreatLastFullScan = now
    end

    return data
end

function FT:UpdateRaidThreatPriority(data, tankEntry)
    if not self:ShouldUseStagedRaidScan() then
        return
    end

    local priority = {}

    if tankEntry and tankEntry.unit then
        priority[tankEntry.unit] = true
    end

    for _, entry in ipairs(data or {}) do
        if entry.isGroupTank and entry.unit then
            priority[entry.unit] = true
        end
    end

    for _, entry in ipairs(data or {}) do
        if self:IsPlayerThreatEntry(entry) and entry.unit then
            priority[entry.unit] = true
            break
        end
    end

    local count = 0
    for _, entry in ipairs(data or {}) do
        if entry.unit and not priority[entry.unit] then
            priority[entry.unit] = true
            count = count + 1
            if count >= RAID_PRIORITY_COUNT then
                break
            end
        end
    end

    self.raidThreatPriorityUnits = priority
end

local function AggroPriority(entry)
    if entry.targetTarget then
        return 4
    end

    if entry.isTanking then
        return 3
    end

    if entry.status ~= nil and entry.status >= 2 then
        return 2
    end

    if entry.status == 1 then
        return 1
    end

    return 0
end

local function ThreatSort(a, b)
    local aPriority = AggroPriority(a)
    local bPriority = AggroPriority(b)

    if aPriority ~= bPriority then
        return aPriority > bPriority
    end

    if a.rawThreat ~= nil or b.rawThreat ~= nil then
        if a.rawThreat == nil then
            return false
        elseif b.rawThreat == nil then
            return true
        elseif a.rawThreat ~= b.rawThreat then
            return a.rawThreat > b.rawThreat
        end
    end

    if a.scaled ~= nil or b.scaled ~= nil then
        if a.scaled == nil then
            return false
        elseif b.scaled == nil then
            return true
        elseif a.scaled ~= b.scaled then
            return a.scaled > b.scaled
        end
    end

    if a.status ~= b.status then
        return (a.status or -1) > (b.status or -1)
    end

    if a.isPlayer ~= b.isPlayer then
        return a.isPlayer
    end

    if a.isPet ~= b.isPet then
        return not a.isPet
    end

    return a.name < b.name
end

function FT:IsPlayerThreatEntry(entry)
    if not entry then
        return false
    end

    if entry.isPlayer or entry.unit == "player" then
        return true
    end

    local ok, playerName = pcall(UnitName, "player")
    if not ok or self:IsSecret(playerName) or playerName == nil then
        return false
    end

    return entry.name == playerName
end

function FT:GetEffectiveThreatMode(tankEntry)
    local mode = self.db and self.db.threatMode or "AUTO"

    if mode == "TANK" or mode == "DPS" or mode == "HEALER" then
        return mode
    end

    if tankEntry and self:IsPlayerThreatEntry(tankEntry) then
        return "TANK"
    end

    return "DPS"
end

function FT:GetTargetTargetName(sourceUnit)
    if not self.db or self.db.showTargetTarget == false then
        return nil
    end

    local sourceTargetUnit = self:GetThreatSourceTargetUnit(sourceUnit)

    if not UnitExists(sourceTargetUnit) then
        return nil
    end

    local ok, name = pcall(UnitName, sourceTargetUnit)
    if not ok or self:IsSecret(name) or name == nil or name == "" then
        return nil
    end

    return name
end

function FT:GetThreatData()
    local sourceUnit = self:GetThreatSourceUnit()

    if not UnitExists(sourceUnit) then
        if sourceUnit == "focus" then
            return {}, FT:L("NO_FOCUS"), nil, sourceUnit
        end

        return {}, FT:L("NO_TARGET"), nil, sourceUnit
    end

    local hostile = SafeUnitCanAttack("player", sourceUnit)
    if hostile == false then
        return {}, sourceUnit == "focus" and FT:L("FOCUS_NOT_HOSTILE") or FT:L("TARGET_NOT_HOSTILE"), nil, sourceUnit
    end

    -- If hostility is protected, keep gathering what the threat API safely
    -- exposes instead of trying to evaluate the protected boolean.
    local okName, sourceName = pcall(UnitName, sourceUnit)
    if not okName or self:IsSecret(sourceName) or sourceName == nil or sourceName == "" then
        sourceName = FT:L("UNKNOWN")
    end

    local data = self:CollectThreatEntries(sourceUnit)

    -- Identify the mob's actual target with a short-circuit pass instead of
    -- running UnitIsUnit(targettarget, unit) inside every GetThreatEntry call.
    local sourceTargetUnit = self:GetThreatSourceTargetUnit(sourceUnit)
    if UnitExists(sourceTargetUnit) then
        for _, entry in ipairs(data) do
            if SafeUnitIsUnit(sourceTargetUnit, entry.unit) then
                entry.targetTarget = true
                break
            end
        end
    end

    table.sort(data, ThreatSort)

    for index, entry in ipairs(data) do
        entry.threatRank = index
    end

    local tankEntry = nil

    -- Prefer the mob's real current target.
    for _, entry in ipairs(data) do
        if entry.targetTarget then
            tankEntry = entry
            break
        end
    end

    -- Fallback to Blizzard's tanking state.
    if not tankEntry then
        for _, entry in ipairs(data) do
            if entry.isTanking or (entry.status ~= nil and entry.status >= 2) then
                tankEntry = entry
                break
            end
        end
    end

    -- Last fallback: first sorted entry.
    if not tankEntry then
        tankEntry = data[1]
    end

    if tankEntry then
        tankEntry.isAggroHolder = true

        if tankEntry.rawThreat ~= nil then
            for _, entry in ipairs(data) do
                if entry.rawThreat ~= nil then
                    entry.threatDelta = entry.rawThreat - tankEntry.rawThreat
                    entry.threatGap = tankEntry.rawThreat - entry.rawThreat
                end
            end
        end
    end

    self:UpdateRaidThreatPriority(data, tankEntry)
    return data, sourceName, tankEntry, sourceUnit
end

function FT:GetTestThreatData()
    local playerName = UnitName("player") or self:L("TEST_PLAYER")
    local _, playerClass = UnitClass("player")

    local specs = {
        { name = self:L("TEST_TANK"), classToken = "WARRIOR", scaled = 100, threat = 100000, tps = 1850, status = 3, tank = true },
        { name = self:L("TEST_MAGE"), classToken = "MAGE", scaled = 96, threat = 96000, tps = 2140, status = 2 },
        { name = self:L("TEST_ROGUE"), classToken = "ROGUE", scaled = 88, threat = 88000, tps = 1760, status = 1 },
        { name = playerName, classToken = playerClass, scaled = 82, threat = 82000, tps = 1490, player = true },
        { name = self:L("TEST_PRIEST"), classToken = "PRIEST", scaled = 74, threat = 74000, tps = 920 },
        { name = self:L("TEST_DRUID"), classToken = "DRUID", scaled = 66, threat = 66000, tps = 1050 },
        { name = self:L("TEST_HUNTER"), classToken = "HUNTER", scaled = 58, threat = 58000, tps = 1310 },
        { name = self:L("TEST_WARLOCK"), classToken = "WARLOCK", scaled = 50, threat = 50000, tps = 1240 },
        { name = self:L("TEST_PALADIN"), classToken = "PALADIN", scaled = 42, threat = 42000, tps = 780 },
        { name = self:L("TEST_SHAMAN"), classToken = "SHAMAN", scaled = 34, threat = 34000, tps = 690 },
    }

    local data = {}
    local tankEntry = nil

    for index, spec in ipairs(specs) do
        local entry = {
            unit = spec.player and "player" or ("test" .. index),
            name = spec.name,
            classToken = spec.classToken,
            connected = true,
            dead = false,
            isPlayer = spec.player and true or false,
            isPet = false,
            ownerUnit = nil,
            ownerName = nil,
            isTanking = spec.tank and true or false,
            groupRole = spec.tank and "TANK" or nil,
            isGroupTank = spec.tank and true or false,
            status = spec.status,
            scaled = spec.scaled,
            rawPct = spec.scaled,
            rawThreat = spec.threat,
            tps = spec.tps,
            scaledRate = spec.player and 1.8 or (spec.tank and nil or 1.2),
            threatEta = spec.tank and 8.4 or ((100 - spec.scaled) / 1.2),
            etaIsLead = spec.tank and true or false,
            restricted = false,
            targetTarget = spec.tank and true or false,
            isAggroHolder = spec.tank and true or false,
            threatDelta = spec.threat - 100000,
            threatGap = 100000 - spec.threat,
            threatRank = index,
        }

        data[#data + 1] = entry

        if spec.tank then
            tankEntry = entry
        end
    end

    return data, self:L("TEST_ENEMY"), tankEntry, "target"
end

function FT:IsRaidDangerEntry(entry)
    if not entry or entry.isPet or entry.isAggroHolder then
        return false
    end

    if entry.status ~= nil and entry.status >= 1 then
        return true
    end

    local threshold = tonumber(self.db and self.db.highThreatThreshold) or 90
    if type(entry.scaled) == "number" and entry.scaled >= threshold then
        return true
    end

    local etaThreshold = tonumber(self.db and self.db.etaWarningThreshold) or 5
    if entry.etaIsLead ~= true and type(entry.threatEta) == "number" and entry.threatEta <= etaThreshold then
        return true
    end

    return false
end

function FT:GetDisplayThreatData(data, maxVisibleRows, effectiveMode)
    if type(data) ~= "table" then
        return {}
    end

    if not IsInRaid() or not self.db then
        return data
    end

    if self.db.raidDangerViewEnabled then
        local limit = tonumber(self.db.raidTopRows) or 10
        limit = math.max(1, math.min(40, math.floor(limit + 0.5)))
        if maxVisibleRows then
            limit = math.min(limit, math.max(1, math.floor(maxVisibleRows)))
        end

        local result = {}
        local seen = {}

        local function AddUnique(entry)
            if not entry or #result >= limit then
                return
            end

            local key = entry.unit or entry.name
            if key and seen[key] then
                return
            end

            if key then
                seen[key] = true
            end
            result[#result + 1] = entry
        end

        local aggroEntry
        local playerEntry

        for _, entry in ipairs(data) do
            if entry.isAggroHolder and not aggroEntry then
                aggroEntry = entry
            end
            if self:IsPlayerThreatEntry(entry) and not playerEntry then
                playerEntry = entry
            end
        end

        AddUnique(aggroEntry)

        -- Keep assigned tanks visible even when they are not currently holding
        -- the boss. If the client does not expose group roles, the aggro holder
        -- above still guarantees a useful tank reference.
        for _, entry in ipairs(data) do
            if entry.isGroupTank then
                AddUnique(entry)
            end
        end

        AddUnique(playerEntry)

        -- Only add non-tanks when they are actually close enough to matter.
        for _, entry in ipairs(data) do
            if self:IsRaidDangerEntry(entry) then
                AddUnique(entry)
            end
        end

        return result
    end

    if self.db.raidTankViewEnabled and effectiveMode == "TANK" then
        local limit = math.min(6, maxVisibleRows or 6)
        limit = math.max(1, math.floor(limit))

        local result = {}
        local seen = {}

        local function AddUnique(entry)
            if not entry or #result >= limit then
                return
            end

            local key = entry.unit or entry.name
            if key and seen[key] then
                return
            end

            if key then
                seen[key] = true
            end
            result[#result + 1] = entry
        end

        local playerEntry
        local aggroEntry

        for _, entry in ipairs(data) do
            if entry.isAggroHolder and not aggroEntry then
                aggroEntry = entry
            end
            if self:IsPlayerThreatEntry(entry) and not playerEntry then
                playerEntry = entry
            end
        end

        AddUnique(aggroEntry)
        AddUnique(playerEntry)

        for _, entry in ipairs(data) do
            AddUnique(entry)
            if #result >= limit then
                break
            end
        end

        return result
    end

    if not self.db.raidTopEnabled then
        return data
    end

    local limit = tonumber(self.db.raidTopRows) or 10
    limit = math.max(1, math.min(40, math.floor(limit + 0.5)))

    if maxVisibleRows then
        limit = math.min(limit, math.max(1, math.floor(maxVisibleRows)))
    end

    if #data <= limit then
        return data
    end

    local result = {}
    local playerIncluded = false

    for i = 1, limit do
        local entry = data[i]
        result[#result + 1] = entry

        if self:IsPlayerThreatEntry(entry) then
            playerIncluded = true
        end
    end

    -- Keep the player visible even when outside the configured Top-X. The
    -- lowest currently displayed entry is replaced so the row limit remains
    -- stable and the UI never grows unexpectedly.
    if self.db.raidAlwaysShowPlayer and not playerIncluded then
        for i = limit + 1, #data do
            local entry = data[i]
            if self:IsPlayerThreatEntry(entry) then
                result[#result] = entry
                break
            end
        end
    end

    return result
end

function FT:GetBarValue(entry)
    if entry.scaled ~= nil then
        return Clamp(entry.scaled, 0, 100)
    end

    if entry.isAggroHolder or entry.isTanking or entry.targetTarget then
        return 100
    end

    if entry.status ~= nil then
        if entry.status >= 2 then
            return 100
        elseif entry.status == 1 then
            return 90
        elseif entry.status == 0 then
            return 25
        end
    end

    return 0
end

function FT:GetThreatLabel(entry)
    if entry.restricted and entry.scaled == nil and entry.rawPct == nil and entry.rawThreat == nil then
        return FT:L("PROTECTED")
    end

    if entry.scaled ~= nil then
        return string.format("%.0f%%", entry.scaled)
    end

    if entry.isAggroHolder or entry.isTanking or entry.targetTarget then
        return FT:L("TANK")
    end

    if entry.status == 1 then
        return FT:L("HIGH")
    elseif entry.status == 2 or entry.status == 3 then
        return FT:L("AGGRO")
    end

    return "-"
end
