Appearance = {}

local PREFIX = '[MONO_APPEARANCE]'

local MALE_HASH = joaat('mp_m_freemode_01')
local FEMALE_HASH = joaat('mp_f_freemode_01')

local function Log(message)
    if AppearanceConfig.Debug then
        print(('%s %s'):format(PREFIX, message))
    end
end

local function Float(value, fallback)
    return (tonumber(value) or fallback or 0.0) + 0.0
end

local function Int(value, fallback)
    return math.tointeger(tonumber(value) or fallback or 0) or (fallback or 0)
end

local function IsFreemode(ped)
    local model = GetEntityModel(ped)

    return model == MALE_HASH or model == FEMALE_HASH
end

local function ApplyHeadBlend(ped, appearance)
    local blend = appearance.headBlend

    if type(blend) ~= 'table' then
        return
    end

    SetPedHeadBlendData(
        ped,
        Int(blend.shapeFirst), Int(blend.shapeSecond), Int(blend.shapeThird),
        Int(blend.skinFirst), Int(blend.skinSecond), Int(blend.skinThird),
        Float(blend.shapeMix, 0.5), Float(blend.skinMix, 0.5), Float(blend.thirdMix, 0.0),
        false
    )

    local deadline = GetGameTimer() + 5000

    while not HasPedHeadBlendFinished(ped) and GetGameTimer() < deadline do
        Wait(10)
    end
end

local function ApplyFaceFeatures(ped, appearance)
    local features = appearance.faceFeatures

    if type(features) ~= 'table' then
        return
    end

    for index, field in ipairs(AppearanceDefs.FACE_FEATURES) do
        SetPedFaceFeature(ped, index - 1, Float(features[field], 0.0))
    end
end

local function ApplyEyeColor(ped, appearance)
    local eyes = appearance.eyeColor

    if type(eyes) == 'table' then
        SetPedEyeColor(ped, Int(eyes.color))
    end
end

local function ApplyHair(ped, appearance)
    local hair = appearance.hair

    if type(hair) ~= 'table' then
        return
    end

    local style = Int(hair.style)

    if style >= GetNumberOfPedDrawableVariations(ped, 2) then
        style = 0
    end

    SetPedComponentVariation(ped, 2, style, 0, 2)
    SetPedHairColor(ped, Int(hair.color), Int(hair.highlight))
end

local function ApplyOverlays(ped, appearance)
    local overlays = appearance.overlays

    if type(overlays) ~= 'table' then
        return
    end

    for _, overlay in ipairs(AppearanceDefs.OVERLAYS) do
        local style = Int(overlays[overlay.key .. 'Style'], -1)
        local opacity = Float(overlays[overlay.key .. 'Opacity'], 1.0)

        -- GTA: 255 = brak overlaya. Zbyt wysoki styl (inny model) tez traktujemy jak brak.
        if style < 0 or style >= GetPedHeadOverlayNum(overlay.id) then
            SetPedHeadOverlay(ped, overlay.id, 255, 0.0)
        else
            SetPedHeadOverlay(ped, overlay.id, style, opacity)

            if overlay.colorType > 0 then
                SetPedHeadOverlayColor(
                    ped,
                    overlay.id,
                    overlay.colorType,
                    Int(overlays[overlay.key .. 'Color']),
                    Int(overlays[overlay.key .. 'Color2'])
                )
            end
        end
    end
end

local function ApplyComponents(ped, appearance)
    local components = appearance.components

    if type(components) ~= 'table' then
        return
    end

    for _, id in ipairs(AppearanceDefs.COMPONENTS) do
        local drawable = Int(components['c' .. id .. 'Drawable'])
        local texture = Int(components['c' .. id .. 'Texture'])

        if drawable >= GetNumberOfPedDrawableVariations(ped, id) then
            drawable = 0
        end

        if texture >= GetNumberOfPedTextureVariations(ped, id, drawable) then
            texture = 0
        end

        SetPedComponentVariation(ped, id, drawable, texture, 2)
    end
end

local function ApplyProps(ped, appearance)
    local props = appearance.props

    if type(props) ~= 'table' then
        return
    end

    for _, id in ipairs(AppearanceDefs.PROPS) do
        local drawable = Int(props['p' .. id .. 'Drawable'], -1)
        local texture = Int(props['p' .. id .. 'Texture'])

        if drawable < 0 or drawable >= GetNumberOfPedPropDrawableVariations(ped, id) then
            ClearPedProp(ped, id)
        else
            if texture >= GetNumberOfPedPropTextureVariations(ped, id, drawable) then
                texture = 0
            end

            SetPedPropIndex(ped, id, drawable, texture, true)
        end
    end
end

local SECTION_ORDER = { 'headBlend', 'faceFeatures', 'eyeColor', 'hair', 'overlays', 'components', 'props' }

local SECTION_APPLY = {
    headBlend = ApplyHeadBlend,
    faceFeatures = ApplyFaceFeatures,
    eyeColor = ApplyEyeColor,
    hair = ApplyHair,
    overlays = ApplyOverlays,
    components = ApplyComponents,
    props = ApplyProps
}

function Appearance.ApplyToPed(ped, appearance, sections)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    if type(appearance) ~= 'table' then
        return false
    end

    if not IsFreemode(ped) then
        Log('Ped nie jest freemode - pomijam appearance.')

        return true
    end

    if type(sections) ~= 'table' or next(sections) == nil then
        sections = nil
    end

    for _, name in ipairs(SECTION_ORDER) do
        if not sections or sections[name] then
            SECTION_APPLY[name](ped, appearance)
        end
    end

    return true
end

function Appearance.Apply(data)
    if type(data) ~= 'table' or type(data.appearance) ~= 'table' then
        Log('Appearance.Apply: nieprawidlowe dane.')

        return false
    end

    return Appearance.ApplyToPed(PlayerPedId(), data.appearance)
end

exports('ApplyToPed', function(ped, appearance, sections)
    return Appearance.ApplyToPed(ped, appearance, sections)
end)

exports('GetDefaultAppearance', function(gender)
    return AppearanceDefs.BuildDefault(gender == 'female' and 'female' or 'male')
end)

exports('GetDefinitions', function()
    return {
        overlays = AppearanceDefs.OVERLAYS,
        components = AppearanceDefs.COMPONENTS,
        props = AppearanceDefs.PROPS,
        faceFeatures = AppearanceDefs.FACE_FEATURES
    }
end)