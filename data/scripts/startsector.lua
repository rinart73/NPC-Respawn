local npcRespawn_generate = SectorTemplate.generate
function SectorTemplate.generate(player, seed, x, y)
    npcRespawn_generate(player, seed, x, y)
    -- mark sector as 'startsector'
    Sector():setValue("generator_script", "startsector")
end