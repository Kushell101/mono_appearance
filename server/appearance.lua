local PREFIX = '[MONO_APPEARANCE]'

local REQUEST_COOLDOWN_MS = 1000
local SAVE_COOLDOWN_MS = 1000

local MAX_APPEARANCE_BYTES = 64 * 1024
local MAX_JSON_DEPTH = 16
local MAX_JSON_NODES = 5000
local MAX_STRING_LENGTH = 4096
local MAX_OBJECT_KEY_LENGTH = 64

local APPEARANCE_VERSION = 1

local DROP_UNKNOWN_SECTIONS = false

local MODELS = {
    male = AppearanceConfig.Default.maleModel,
    female = AppearanceConfig.Default.femaleModel
}

local FACE_FEATURES = AppearanceDefs.FACE_FEATURES

-- Reguly pol: { min, max, czy_calkowite }
local HEAD_BLEND_SPEC = {
    shapeFirst  = { 0, 45, true },
    shapeSecond = { 0, 45, true },
    shapeThird  = { 0, 45, true },
    skinFirst   = { 0, 45, true },
    skinSecond  = { 0, 45, true },
    skinThird   = { 0, 45, true },
    shapeMix    = { 0.0, 1.0, false },
    skinMix     = { 0.0, 1.0, false },
    thirdMix    = { 0.0, 1.0, false }
}

local FACE_FEATURE_SPEC = {}

for _, field in ipairs(FACE_FEATURES) do
    FACE_FEATURE_SPEC[field] = { -1.0, 1.0, false }
end

local editAllowed = {}

local function Debug(message)
    if AppearanceConfig.Debug then
        print(('%s %s'):format(PREFIX, message))
    end
end

-- Zawsze
local function Info(message)
    print(('%s %s'):format(PREFIX, message))
end

local function IsFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function ToInteger(value)
    local number = tonumber(value)

    return IsFiniteNumber(number) and math.tointeger(number) or nil
end

local function IsOnline(src)
    local name = src and GetPlayerName(src)

    return name ~= nil and name ~= '**Invalid**'
end

local function Query(kind, sql, params)
    local ok, result = pcall(function()
        return MySQL[kind].await(sql, params or {})
    end)

    if not ok then
        Info(('Blad SQL: %s'):format(tostring(result)))
        return false, nil
    end

    return true, result
end

local function NewGuard(cooldownMs)
    local lastStart, busy = {}, {}

    return {
        begin = function(src)
            local now = GetGameTimer()
            local last = lastStart[src]

            if busy[src] or (last and now >= last and (now - last) < cooldownMs) then
                return nil
            end

            local token = {}

            lastStart[src] = now
            busy[src] = token

            return token
        end,
        finish = function(src, token)
            if busy[src] == token then
                busy[src] = nil
            end
        end,
        isCurrent = function(src, token)
            return busy[src] == token
        end,
        clear = function(src)
            lastStart[src], busy[src] = nil, nil
        end
    }
end

local requestGuard = NewGuard(REQUEST_COOLDOWN_MS)
local saveGuard = NewGuard(SAVE_COOLDOWN_MS)

local function SendToClient(src, eventName, ...)
    if IsOnline(src) then
        TriggerClientEvent(eventName, src, ...)
    end
end

local function Fail(src, errorCode)
    SendToClient(src, 'mono_appearance:failed', errorCode)
end

local function SaveFailed(src, errorCode)
    SendToClient(src, 'mono_appearance:saveFailed', errorCode)
end

-- Aktywna postac gracza ustala serwer (mono_core), nie klient.
local function GetActiveCharacter(src)
    local ok, character = pcall(function()
        return exports.mono_core:GetActiveCharacter(src)
    end)

    if not ok then
        Info(('mono_core jest niedostepne: %s'):format(tostring(character)))
        return nil, 'core_unavailable'
    end

    if type(character) ~= 'table' then
        return nil, 'no_active_character'
    end

    local characterId = ToInteger(character.id)

    if not characterId or characterId < 1 then
        return nil, 'invalid_character_id'
    end

    if not MODELS[character.gender] then
        return nil, 'invalid_character_gender'
    end

    return character
end

local function IsSameActiveCharacter(src, characterId)
    local character = GetActiveCharacter(src)

    return character ~= nil and ToInteger(character.id) == characterId
end

local function CopyJsonValue(value, depth, budget)
    if depth > MAX_JSON_DEPTH then
        return nil, 'appearance_too_deep'
    end

    budget.nodes = budget.nodes + 1

    if budget.nodes > MAX_JSON_NODES then
        return nil, 'appearance_too_complex'
    end

    local valueType = type(value)

    if valueType == 'boolean' then
        return value
    end

    if valueType == 'number' then
        if not IsFiniteNumber(value) then
            return nil, 'invalid_appearance_number'
        end

        return value
    end

    if valueType == 'string' then
        if #value > MAX_STRING_LENGTH then
            return nil, 'appearance_string_too_long'
        end

        return value
    end

    if valueType ~= 'table' then
        return nil, 'invalid_appearance_value'
    end

    local copy = {}

    for key, child in pairs(value) do
        local keyType = type(key)

        local validKey = (keyType == 'string' and key ~= '' and #key <= MAX_OBJECT_KEY_LENGTH)
            or (keyType == 'number' and math.tointeger(key) ~= nil and key >= 1 and key <= MAX_JSON_NODES)

        if not validKey then
            return nil, 'invalid_appearance_key'
        end

        local copiedChild, errorCode = CopyJsonValue(child, depth + 1, budget)

        if errorCode then
            return nil, errorCode
        end

        copy[key] = copiedChild
    end

    return copy
end

local DefaultHeadBlend = AppearanceDefs.DefaultHeadBlend
local DefaultFaceFeatures = AppearanceDefs.DefaultFaceFeatures

local SECTIONS = {
    headBlend = {
        spec = HEAD_BLEND_SPEC,
        defaults = DefaultHeadBlend,
        errorCode = 'invalid_head_blend'
    },
    faceFeatures = {
        spec = FACE_FEATURE_SPEC,
        defaults = DefaultFaceFeatures,
        errorCode = 'invalid_face_features'
    }
}

SECTIONS.eyeColor = {
    spec = AppearanceDefs.EYE_COLOR_SPEC,
    defaults = AppearanceDefs.DefaultEyeColor,
    errorCode = 'invalid_eye_color'
}

SECTIONS.hair = {
    spec = AppearanceDefs.HAIR_SPEC,
    defaults = AppearanceDefs.DefaultHair,
    errorCode = 'invalid_hair'
}

SECTIONS.overlays = {
    spec = AppearanceDefs.OVERLAY_SPEC,
    defaults = AppearanceDefs.DefaultOverlays,
    errorCode = 'invalid_overlays'
}

SECTIONS.components = {
    spec = AppearanceDefs.COMPONENT_SPEC,
    defaults = AppearanceDefs.DefaultComponents,
    errorCode = 'invalid_components'
}

SECTIONS.props = {
    spec = AppearanceDefs.PROP_SPEC,
    defaults = AppearanceDefs.DefaultProps,
    errorCode = 'invalid_props'
}

local function BuildSection(raw, spec, defaults)
    if raw ~= nil and type(raw) ~= 'table' then
        return nil
    end

    raw = raw or {}

    local result = {}

    for field, rule in pairs(spec) do
        local value = raw[field]

        if value == nil then
            value = defaults[field]
        end

        if not IsFiniteNumber(value)
            or value < rule[1]
            or value > rule[2]
            or (rule[3] and math.tointeger(value) ~= value)
        then
            return nil
        end

        result[field] = rule[3] and math.tointeger(value) or value
    end

    return result
end

local function NormalizeAppearance(raw, gender, strict)
    if type(raw) ~= 'table' then
        return nil, 'invalid_appearance'
    end

    local copied, copyError = CopyJsonValue(raw, 0, { nodes = 0 })

    if not copied then
        return nil, copyError or 'invalid_appearance'
    end

    copied.version = APPEARANCE_VERSION

    for name, section in pairs(SECTIONS) do
        local defaults = section.defaults(gender)
        local built = BuildSection(copied[name], section.spec, defaults)

        if not built then
            if strict then
                return nil, section.errorCode
            end

            Info(('Sekcja "%s" ma nieprawidlowe dane - przywrocono domyslna.'):format(name))

            built = BuildSection(nil, section.spec, defaults)
        end

        copied[name] = built
    end

    if DROP_UNKNOWN_SECTIONS then
        for name in pairs(copied) do
            if name ~= 'version' and not SECTIONS[name] then
                copied[name] = nil
            end
        end
    end

    return copied
end

local function EncodeAppearance(appearance)
    local ok, encoded = pcall(json.encode, appearance)

    if not ok or type(encoded) ~= 'string' then
        return nil, 'json_encode_failed'
    end

    if #encoded > MAX_APPEARANCE_BYTES then
        return nil, 'appearance_too_large'
    end

    return encoded
end

local function DecodeAppearance(raw, gender)
    local decoded = raw

    if type(raw) == 'string' then
        local ok, result = pcall(json.decode, raw)

        if not ok then
            return nil, 'invalid_appearance_data'
        end

        decoded = result
    end

    if type(decoded) ~= 'table' then
        return nil, 'invalid_appearance_data'
    end

    return NormalizeAppearance(decoded, gender, false)
end

function GetCharacterAppearance(characterId)
    characterId = ToInteger(characterId)

    if not characterId or characterId < 1 then
        return nil, 'invalid_character_id'
    end

    local ok, row = Query(
        'single',
        'SELECT id, character_id, model, appearance FROM character_appearance WHERE character_id = ? LIMIT 1',
        { characterId }
    )

    if not ok then
        return nil, 'database_error'
    end

    if not row then
        return nil, 'appearance_not_found'
    end

    return row
end

local function SaveEncoded(characterId, model, appearanceJson)
    local ok = Query(
        'update',
        [[
            INSERT INTO character_appearance (character_id, model, appearance)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                model = VALUES(model),
                appearance = VALUES(appearance),
                updated_at = CURRENT_TIMESTAMP
        ]],
        { characterId, model, appearanceJson }
    )

    if not ok then
        return false, 'database_error'
    end

    return true
end

function SaveCharacterAppearance(characterId, model, appearance)
    characterId = ToInteger(characterId)

    if not characterId or characterId < 1 then
        return false, 'invalid_character_id'
    end

    local gender = (model == MODELS.male and 'male') or (model == MODELS.female and 'female') or nil

    if not gender then
        return false, 'invalid_model'
    end

    local normalized, normalizeError = NormalizeAppearance(appearance, gender, true)

    if not normalized then
        return false, normalizeError
    end

    local encoded, encodeError = EncodeAppearance(normalized)

    if not encoded then
        return false, encodeError
    end

    return SaveEncoded(characterId, model, encoded)
end

local function CreateDefaultAppearance(characterId, model, gender)
    local defaultAppearance = NormalizeAppearance({}, gender, true)
    local encoded, encodeError = EncodeAppearance(defaultAppearance)

    if not encoded then
        return false, encodeError
    end

    local ok = Query(
        'update',
        [[
            INSERT INTO character_appearance (character_id, model, appearance)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE character_id = character_id
        ]],
        { characterId, model, encoded }
    )

    if not ok then
        return false, 'database_error'
    end

    return true
end

local function LoadForPlayer(src, token)
    local character, coreError = GetActiveCharacter(src)

    if not character then
        return Fail(src, coreError)
    end

    local characterId = ToInteger(character.id)
    local model = MODELS[character.gender]

    local row, errorCode = GetCharacterAppearance(characterId)

    if not row and errorCode == 'appearance_not_found' then
        if not IsSameActiveCharacter(src, characterId) then
            return
        end

        local created, createError = CreateDefaultAppearance(characterId, model, character.gender)

        if not created then
            return Fail(src, createError)
        end

        row, errorCode = GetCharacterAppearance(characterId)
    end

    if not row then
        return Fail(src, errorCode or 'database_error')
    end

    if row.model ~= model then
        Info(('Nieprawidlowy model appearance dla character ID: %s'):format(characterId))
        return Fail(src, 'invalid_model_data')
    end

    local appearance, decodeError = DecodeAppearance(row.appearance, character.gender)

    if not appearance then
        Info(('Nieprawidlowe dane appearance dla character ID: %s (%s)'):format(
            characterId,
            tostring(decodeError)
        ))

        return Fail(src, decodeError or 'invalid_appearance_data')
    end

    if not requestGuard.isCurrent(src, token) or not IsSameActiveCharacter(src, characterId) then
        return
    end

    Debug(('Wczytano appearance dla character ID: %s'):format(characterId))

    SendToClient(src, 'mono_appearance:loaded', {
        characterId = characterId,
        model = row.model,
        appearance = appearance
    })
end

RegisterNetEvent('mono_appearance:request', function()
    local src = source

    if not IsOnline(src) then
        return
    end

    local token = requestGuard.begin(src)

    if not token then
        return
    end

    local ok, errorMessage = pcall(LoadForPlayer, src, token)

    if not ok then
        Info(('Nieobsluzony blad ladowania dla gracza %s: %s'):format(src, tostring(errorMessage)))
        Fail(src, 'internal_error')
    end

    requestGuard.finish(src, token)
end)

local function SaveForPlayer(src, data)
    if not (AppearanceConfig.Debug or editAllowed[src]) then
        return nil, 'edit_not_allowed'
    end

    if type(data) ~= 'table' then
        return nil, 'invalid_appearance'
    end

    local character, coreError = GetActiveCharacter(src)

    if not character then
        return nil, coreError
    end

    local characterId = ToInteger(character.id)
    local model = MODELS[character.gender]

    local rawAppearance = data

    if data.appearance ~= nil then
        rawAppearance = data.appearance

        if data.model ~= nil and data.model ~= model then
            return nil, 'invalid_model'
        end
    end

    local normalized, normalizeError = NormalizeAppearance(rawAppearance, character.gender, true)

    if not normalized then
        return nil, normalizeError
    end

    local encoded, encodeError = EncodeAppearance(normalized)

    if not encoded then
        return nil, encodeError
    end

    if not IsSameActiveCharacter(src, characterId) then
        return nil, 'character_changed'
    end

    local saved, saveError = SaveEncoded(characterId, model, encoded)

    if not saved then
        return nil, saveError
    end

    return characterId
end

local function HandleSave(src, data)
    if not IsOnline(src) then
        return
    end

    local token = saveGuard.begin(src)

    if not token then
        return
    end

    local ok, characterId, errorCode = pcall(SaveForPlayer, src, data)

    saveGuard.finish(src, token)

    if not ok then
        Info(('Nieobsluzony blad zapisu dla gracza %s: %s'):format(src, tostring(characterId)))
        return SaveFailed(src, 'internal_error')
    end

    if not characterId then
        Debug(('Zapis appearance odrzucony (%s): %s'):format(src, tostring(errorCode)))
        return SaveFailed(src, errorCode or 'database_error')
    end

    Debug(('Zapisano appearance dla character ID: %s'):format(characterId))

    SendToClient(src, 'mono_appearance:saved', characterId)
end

RegisterNetEvent('mono_appearance:save', function(data)
    HandleSave(source, data)
end)

if AppearanceConfig.Debug then
    RegisterNetEvent('mono_appearance:saveTest', function(data)
        HandleSave(source, data)
    end)
end

exports('NormalizeAppearance', function(appearance, gender)
    if not MODELS[gender] then
        return { ok = false, error = 'invalid_model' }
    end

    local normalized, errorCode = NormalizeAppearance(appearance, gender, true)

    if not normalized then
        return { ok = false, error = errorCode or 'invalid_appearance' }
    end

    return { ok = true, appearance = normalized }
end)

exports('GetCharacterAppearance', function(characterId, gender)
    if not MODELS[gender] then
        return { ok = false, error = 'invalid_model' }
    end

    local row, errorCode = GetCharacterAppearance(characterId)
    if not row then
        return { ok = false, error = errorCode or 'appearance_not_found' }
    end

    if row.model ~= MODELS[gender] then
        return { ok = false, error = 'appearance_model_mismatch' }
    end

    local appearance, decodeError = DecodeAppearance(row.appearance, gender)
    if not appearance then
        return { ok = false, error = decodeError or 'invalid_appearance_data' }
    end

    return { ok = true, appearance = appearance }
end)

exports('GetDefaultAppearance', function(gender)
    if not MODELS[gender] then
        return { ok = false, error = 'invalid_model' }
    end

    return { ok = true, appearance = AppearanceDefs.BuildDefault(gender) }
end)

-- Zapis wygladu nowej postaci (dostep tylko dla zasobow serwerowych).
exports('SaveAppearance', function(characterId, gender, appearance)
    local model = MODELS[gender]

    if not model then
        return { ok = false, error = 'invalid_model' }
    end

    local saved, errorCode = SaveCharacterAppearance(characterId, model, appearance)

    if not saved then
        return { ok = false, error = errorCode or 'database_error' }
    end

    return { ok = true }
end)

exports('SetAppearanceEditing', function(src, enabled)
    src = ToInteger(src)

    if src then
        editAllowed[src] = enabled and true or nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    requestGuard.clear(src)
    saveGuard.clear(src)
    editAllowed[src] = nil
end)

CreateThread(function()
    MySQL.ready(function()
        local ok, indexes = Query(
            'query',
            "SHOW INDEX FROM character_appearance WHERE Column_name = 'character_id' AND Non_unique = 0"
        )

        if ok and (not indexes or #indexes == 0) then
            Info('UWAGA: brak indeksu UNIQUE na character_appearance.character_id - '
                .. 'ON DUPLICATE KEY nie dziala, mozliwe zdublowane wiersze. SQL w komentarzu na gorze pliku.')
        end
    end)
end)
