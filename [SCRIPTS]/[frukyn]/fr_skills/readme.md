exports.fr_skills:AddSkill('strength', 0.5)

-- Nebo zjistit aktuální hodnotu (např. pro práci, která vyžaduje sílu alespoň 30 %):
local silak = exports.fr_skills:GetSkill('strength')
if silak >= 30.0 then
    -- Může dělat práci
end