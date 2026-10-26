-- Elimina IN_ZOOM del input antes de que la predicción lo procese.
-- CreateMove corre antes de PlayerTick, así que el zoom nunca llega a activarse.
hook.Add("CreateMove", "DisableZoom_NoZoom", function(cmd)
	cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_ZOOM)))
end)
