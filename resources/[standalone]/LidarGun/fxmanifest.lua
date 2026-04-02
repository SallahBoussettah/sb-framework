--[[
    LidarGun - ProLaser 4 Custom Weapon
    Defines WEAPON_PROLASER4 via meta files with NonViolent flag (NPCs don't react)
    Model: w_pi_prolaser4 (ProLaser 4 LIDAR gun)
    Used by sb_police radar gun system
    Based on: github.com/TrevorBarns/ProLaser4 (meta files + model)
]]

fx_version 'cerulean'
game 'gta5'

author 'Everyday Chaos RP'
description 'ProLaser 4 LIDAR Gun - Custom weapon definition + model'
version '2.0.0'

files {
    'metas/*.meta',
}

data_file 'WEAPONINFO_FILE' 'metas/weapons.meta'
data_file 'WEAPON_METADATA_FILE' 'metas/weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'metas/weaponanimations.meta'
data_file 'CONTENT_UNLOCKING_META_FILE' 'metas/contentunlocks.meta'
data_file 'PED_PERSONALITY_FILE' 'metas/pedpersonality.meta'
