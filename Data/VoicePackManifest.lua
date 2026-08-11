---@type string, Addon
local _, addon = ...

-- Shipped voice-pack folder names under Media\. Regenerate when adding bundled packs.
-- Custom user folders: add via settings (saved in DB) or append here.
addon.Data.VoicePackManifest = {
	"夏一可1.25x",
	"夏一可",
	"夏一可1.5x",
}
