-- sb_mechanic_v2 | Repair VFX
-- Particle effects for welding, fluid, electrical work

RepairVFX = {}

-- Active particle handles
local ActiveParticles = {}

-- ===== PARTICLE DEFINITIONS =====
local ParticleDefs = {
    welding_sparks = {
        asset = 'core',
        name = 'ent_ray_sparks',
        scale = 0.8,
        boneId = 57005,  -- SKEL_R_Hand
        offset = vector3(0.05, 0.0, 0.0),
        rotation = vector3(0.0, 0.0, 0.0),
    },
    fluid_pour = {
        asset = 'core',
        name = 'ent_ray_drip',
        scale = 0.5,
        boneId = 57005,
        offset = vector3(0.0, 0.0, -0.1),
        rotation = vector3(0.0, 0.0, 0.0),
    },
    electrical_spark = {
        asset = 'core',
        name = 'ent_ray_sparks',
        scale = 0.3,
        boneId = 57005,
        offset = vector3(0.02, 0.0, 0.0),
        rotation = vector3(0.0, 0.0, 0.0),
    },
}

-- ===== LOAD PARTICLE ASSET =====
local function LoadPtfxAsset(assetName)
    RequestNamedPtfxAsset(assetName)
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(assetName) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    return HasNamedPtfxAssetLoaded(assetName)
end

-- ===== START PARTICLE EFFECT =====
function RepairVFX.Start(effectKey)
    local def = ParticleDefs[effectKey]
    if not def then return end

    -- Stop any existing particles first
    RepairVFX.StopAll()

    if not LoadPtfxAsset(def.asset) then return end

    local ped = PlayerPedId()
    UseParticleFxAssetNextCall(def.asset)

    local ptfx = StartParticleFxLoopedOnPedBone(
        def.name,
        ped,
        def.offset.x, def.offset.y, def.offset.z,
        def.rotation.x, def.rotation.y, def.rotation.z,
        def.boneId,
        def.scale,
        false, false, false
    )

    if ptfx and ptfx ~= 0 then
        table.insert(ActiveParticles, { handle = ptfx, asset = def.asset })
    end
end

-- ===== STOP ALL PARTICLES =====
function RepairVFX.StopAll()
    for i = #ActiveParticles, 1, -1 do
        local p = ActiveParticles[i]
        if p.handle and DoesParticleFxLoopedExist(p.handle) then
            StopParticleFxLooped(p.handle, false)
            RemoveParticleFx(p.handle, false)
        end
        ActiveParticles[i] = nil
    end
    ActiveParticles = {}
end

-- ===== RESOURCE STOP CLEANUP =====
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RepairVFX.StopAll()
end)
