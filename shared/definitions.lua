AppearanceDefs = {}

local DEFAULT_MOTHER = 21
local DEFAULT_FATHER = 0
local MAX_DRAWABLE = 1500
local MAX_TEXTURE = 255

AppearanceDefs.FACE_FEATURES = {
    'noseWidth', 'nosePeakHeight', 'nosePeakLength', 'noseBoneHigh',
    'nosePeakLowering', 'noseBoneTwist',
    'eyebrowHeight', 'eyebrowDepth',
    'cheekboneHeight', 'cheekboneWidth', 'cheekWidth',
    'eyeOpening', 'lipThickness',
    'jawBoneWidth', 'jawBoneBackLength',
    'chinBone', 'chinBoneLength', 'chinBoneShape', 'chinHole',
    'neckThickness'
}

AppearanceDefs.OVERLAYS = {
    { key = 'blemishes',  id = 0,  max = 23, colorType = 0 },
    { key = 'facialHair', id = 1,  max = 28, colorType = 1 },
    { key = 'eyebrows',   id = 2,  max = 33, colorType = 1 },
    { key = 'ageing',     id = 3,  max = 14, colorType = 0 },
    { key = 'makeup',     id = 4,  max = 74, colorType = 2 },
    { key = 'blush',      id = 5,  max = 6,  colorType = 2 },
    { key = 'complexion', id = 6,  max = 11, colorType = 0 },
    { key = 'sunDamage',  id = 7,  max = 10, colorType = 0 },
    { key = 'lipstick',   id = 8,  max = 9,  colorType = 2 },
    { key = 'moles',      id = 9,  max = 17, colorType = 0 },
    { key = 'chestHair',  id = 10, max = 16, colorType = 1 }
}

AppearanceDefs.COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
AppearanceDefs.PROPS = { 0, 1, 2, 6, 7 }

-- ---------------------------------------------------------------------
-- Specyfikacje { min, max, czy_calkowite } dla BuildSection
-- ---------------------------------------------------------------------

AppearanceDefs.EYE_COLOR_SPEC = {
    color = { 0, 31, true }
}

AppearanceDefs.HAIR_SPEC = {
    style = { 0, 255, true },
    color = { 0, 63, true },
    highlight = { 0, 63, true }
}

AppearanceDefs.OVERLAY_SPEC = {}

for _, overlay in ipairs(AppearanceDefs.OVERLAYS) do
    AppearanceDefs.OVERLAY_SPEC[overlay.key .. 'Style'] = { -1, 254, true } -- 255 = brak w GTA; -1 u nas
    AppearanceDefs.OVERLAY_SPEC[overlay.key .. 'Opacity'] = { 0.0, 1.0, false }
    AppearanceDefs.OVERLAY_SPEC[overlay.key .. 'Color'] = { 0, 63, true }
    AppearanceDefs.OVERLAY_SPEC[overlay.key .. 'Color2'] = { 0, 63, true }
end

AppearanceDefs.COMPONENT_SPEC = {}

for _, id in ipairs(AppearanceDefs.COMPONENTS) do
    AppearanceDefs.COMPONENT_SPEC['c' .. id .. 'Drawable'] = { 0, MAX_DRAWABLE, true }
    AppearanceDefs.COMPONENT_SPEC['c' .. id .. 'Texture'] = { 0, MAX_TEXTURE, true }
end

AppearanceDefs.PROP_SPEC = {}

for _, id in ipairs(AppearanceDefs.PROPS) do
    AppearanceDefs.PROP_SPEC['p' .. id .. 'Drawable'] = { -1, MAX_DRAWABLE, true }
    AppearanceDefs.PROP_SPEC['p' .. id .. 'Texture'] = { 0, MAX_TEXTURE, true }
end

-- ---------------------------------------------------------------------
-- Wartosci domyslne (argument gender: 'male' | 'female')
-- ---------------------------------------------------------------------

function AppearanceDefs.DefaultHeadBlend(gender)
    local mix = gender == 'female' and 0.0 or 1.0

    return {
        shapeFirst = DEFAULT_MOTHER,
        shapeSecond = DEFAULT_FATHER,
        shapeThird = 0,

        skinFirst = DEFAULT_MOTHER,
        skinSecond = DEFAULT_FATHER,
        skinThird = 0,

        shapeMix = mix,
        skinMix = mix,
        thirdMix = 0.0
    }
end

function AppearanceDefs.DefaultFaceFeatures()
    local features = {}

    for _, field in ipairs(AppearanceDefs.FACE_FEATURES) do
        features[field] = 0.0
    end

    return features
end

function AppearanceDefs.DefaultEyeColor()
    return { color = 0 }
end

function AppearanceDefs.DefaultHair()
    return { style = 0, color = 0, highlight = 0 }
end

function AppearanceDefs.DefaultOverlays()
    local overlays = {}

    for _, overlay in ipairs(AppearanceDefs.OVERLAYS) do
        overlays[overlay.key .. 'Style'] = -1
        overlays[overlay.key .. 'Opacity'] = 1.0
        overlays[overlay.key .. 'Color'] = 0
        overlays[overlay.key .. 'Color2'] = 0
    end

    return overlays
end

local BASE_COMPONENTS = {
    male =   { [1] = 0, [3] = 15, [4] = 21, [5] = 0, [6] = 34, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
    female = { [1] = 0, [3] = 15, [4] = 15, [5] = 0, [6] = 35, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 }
}

function AppearanceDefs.DefaultComponents(gender)
    local base = BASE_COMPONENTS[gender] or BASE_COMPONENTS.male
    local components = {}

    for _, id in ipairs(AppearanceDefs.COMPONENTS) do
        components['c' .. id .. 'Drawable'] = base[id] or 0
        components['c' .. id .. 'Texture'] = 0
    end

    return components
end

function AppearanceDefs.DefaultProps()
    local props = {}

    for _, id in ipairs(AppearanceDefs.PROPS) do
        props['p' .. id .. 'Drawable'] = -1
        props['p' .. id .. 'Texture'] = 0
    end

    return props
end

function AppearanceDefs.BuildDefault(gender)
    return {
        version = 1,
        headBlend = AppearanceDefs.DefaultHeadBlend(gender),
        faceFeatures = AppearanceDefs.DefaultFaceFeatures(),
        eyeColor = AppearanceDefs.DefaultEyeColor(),
        hair = AppearanceDefs.DefaultHair(),
        overlays = AppearanceDefs.DefaultOverlays(),
        components = AppearanceDefs.DefaultComponents(gender),
        props = AppearanceDefs.DefaultProps()
    }
end
