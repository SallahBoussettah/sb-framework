-- ============================================================================
-- SB Phone V2 — Server Notifications
-- Author: Salah Eddine Boussettah
-- ============================================================================

local SB = exports['sb_core']:GetCoreObject()

RegisterNetEvent('sb_phone:server:notifyOfflineMessage', function(receiverNumber, senderName, messageText)
    -- Fallback: primary notification via sb_phone:client:newMessage
end)

print('^2[sb_phone]^7 Notifications module loaded')
