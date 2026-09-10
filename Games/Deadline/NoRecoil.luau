local ReplicatedStorage = game:GetService("ReplicatedStorage")
local stats = require(ReplicatedStorage.module.shared_state).SHARED_STATE
if type(stats.plr_recoil) then
	--// Gun
	stats.plr_recoil.value = 0
	stats.plr_barrel_deviation.value = 0
	stats.plr_buck_barrel_deviation.value = 0

	--// Movement
	stats.plr_ergonomics_multiplier.value = 1000
	stats.plr_stamina_shake_multiplier.value = 0

	--// Effects
	stats.plr_suppression.value = false
end
