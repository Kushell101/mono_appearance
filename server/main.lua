local PREFIX = '[MONO_APPEARANCE]'

local function Log(message)
    print(('%s %s'):format(
        PREFIX,
        message
    ))
end

CreateThread(function()
    Log('Resource mono_appearance zostal uruchomiony.')
end)