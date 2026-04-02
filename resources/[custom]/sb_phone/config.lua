Config = {}

-- Phone item name in sb_items
Config.ItemName = 'phone'

-- Phone prop and animation
Config.Prop = 'prop_amb_phone'
Config.PropBone = 28422  -- Right hand
Config.PropOffset = vector3(0.0, 0.0, 0.0)
Config.PropRotation = vector3(0.0, 0.0, 0.0)

-- Limits
Config.MaxContacts = 50
Config.MaxMessageLength = 256
Config.MaxPostCaptionLength = 200

-- Transfer limits
Config.MinTransfer = 1
Config.MaxTransfer = 1000000

-- Call settings
Config.CallTimeout = 30  -- Seconds before unanswered call becomes missed

-- Sound settings
Config.SoundVolume = 0.3       -- Default volume for UI sound effects (0.0 - 1.0)
Config.KeyboardSounds = true   -- Play subtle click sounds when typing in text fields

-- Camera / Screenshot settings
-- Upload service: 'fivemanager', 'imgur', 'discord', or 'custom'
Config.CameraUploadMethod = 'fivemanager'
-- API tokens are read from server convars (set in server.cfg):
--   set sb_phone_fivemanager_token "YOUR_TOKEN_HERE"
--   set sb_phone_imgur_clientid "YOUR_CLIENT_ID"
--   set sb_phone_discord_webhook "YOUR_WEBHOOK_URL"
--   set sb_phone_custom_upload_url "YOUR_URL"
Config.CustomUploadField = 'file'
-- Screenshot quality
Config.ScreenshotQuality = 0.85

-- Face ID (cosmetic unlock animation)
Config.FaceIdEnabled = true

-- Phone number format prefixes (area codes)
Config.PhoneNumber = {
    Prefixes = { '555', '310', '213', '323', '818' }
}

-- Shared phone number formatter: ensures (XXX) XXX-XXXX format
function Config.FormatPhoneNumber(rawNumber)
    if not rawNumber or rawNumber == '' then
        local prefix = Config.PhoneNumber.Prefixes[math.random(#Config.PhoneNumber.Prefixes)]
        return '(' .. prefix .. ') ' .. string.format('%03d', math.random(0, 999)) .. '-' .. string.format('%04d', math.random(0, 9999))
    end
    if rawNumber:match('^%(%d%d%d%) %d%d%d%-%d%d%d%d$') then return rawNumber end
    local digits = rawNumber:gsub('%D', '')
    if #digits == 10 then
        return '(' .. digits:sub(1,3) .. ') ' .. digits:sub(4,6) .. '-' .. digits:sub(7,10)
    elseif #digits == 7 then
        return '(555) ' .. digits:sub(1,3) .. '-' .. digits:sub(4,7)
    else
        local prefix = Config.PhoneNumber.Prefixes[math.random(#Config.PhoneNumber.Prefixes)]
        return '(' .. prefix .. ') ' .. string.format('%03d', math.random(0, 999)) .. '-' .. string.format('%04d', math.random(0, 9999))
    end
end

-- Ringtones (filenames without extension in html/audio/ringtones/)
Config.Ringtones = { 'default', 'harp', 'apex', 'radar', 'sencha', 'silk', 'summit' }

-- Animations
Config.Anims = {
    -- On foot
    OpenDict   = 'cellphone@',
    OpenAnim   = 'cellphone_text_in',
    BaseDict   = 'cellphone@',
    BaseAnim   = 'cellphone_text_read_base',
    CloseDict  = 'cellphone@',
    CloseAnim  = 'cellphone_text_out',
    CallDict   = 'cellphone@',
    CallAnim   = 'cellphone_call_listen_base',
    -- In vehicle
    CarOpenDict   = 'cellphone@in_car@ds',
    CarOpenAnim   = 'cellphone_text_in',
    CarBaseDict   = 'cellphone@in_car@ds',
    CarBaseAnim   = 'cellphone_text_read_base',
    CarCloseDict  = 'cellphone@in_car@ds',
    CarCloseAnim  = 'cellphone_text_out',
    CarCallDict   = 'cellphone@in_car@ds',
    CarCallAnim   = 'cellphone_call_listen_base',
}

-- Obstructing helmets (Face ID)
Config.ObstructingHelmets = {
    male = {
        [0] = false,
    },
    female = {
        [0] = false,
    }
}
