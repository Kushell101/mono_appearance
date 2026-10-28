local PREFIX = '[MONO_APPEARANCE]'

local function Log(message)
    if not AppearanceConfig.Debug then
        return
    end

    print(('%s %s'):format(PREFIX, message))
end

local function IsValidCharacter(character)
    return type(character) == 'table'
        and character.id
        and character.first_name
        and character.last_name
        and (character.gender == 'male' or character.gender == 'female')
end

CreateThread(function()
    Log('Resource mono_appearance zostal uruchomiony.')
end)

RegisterNetEvent('mono_core:characterSelected', function(character)
    Log('Otrzymano wybrana postac z mono_core.')

    if not IsValidCharacter(character) then
        return Log('Otrzymano nieprawidlowe dane postaci.')
    end

    Log(('Postac: %s %s | ID: %s | Plec: %s'):format(
        character.first_name,
        character.last_name,
        tostring(character.id),
        character.gender
    ))

    TriggerServerEvent('mono_appearance:request')
end)

RegisterNetEvent('mono_appearance:loaded', function(data)
    if type(data) ~= 'table' then
        Log('Otrzymano nieprawidlowe dane appearance.')
        return
    end

    Log((
        'Appearance zaladowane | Character ID: %s | Model: %s'
    ):format(
        tostring(data.characterId),
        tostring(data.model)
    ))

    local success = Appearance.Apply(data)

    if not success then
        Log('Nie udalo sie zastosowac appearance.')

        TriggerEvent(
            'mono_appearance:appearanceFailed',
            'apply_failed'
        )

        return
    end

    TriggerEvent(
        'mono_appearance:appearanceReady',
        data
    )
end)

RegisterNetEvent('mono_appearance:failed', function(errorCode)
    Log(('Blad ladowania appearance: %s'):format(tostring(errorCode)))

    TriggerEvent('mono_appearance:appearanceFailed', errorCode)
end)