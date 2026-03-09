local addonName, addon = ...
local L = addon.L
local loader = CreateFrame("Frame")
local loaded = false
local onLoadCallbacks = {}
local sliderId = 1
local dialog

---@class MiniFramework
local M = {
	VerticalSpacing = 16,
	HorizontalSpacing = 20,
	TextMaxWidth = 600,
}
addon.Core.Framework = M

local function AddControlForRefresh(panel, control)
	panel.MiniControls = panel.MiniControls or {}
	panel.MiniControls[#panel.MiniControls + 1] = control

	if panel.MiniRefresh then
		return
	end

	panel.MiniRefresh = function(panelSelf)
		for _, c in ipairs(panelSelf.MiniControls or {}) do
			if c.MiniRefresh then
				c:MiniRefresh()
			end
		end

		if panel.OnMiniRefresh then
			panel:OnMiniRefresh()
		end
	end
end

local function ConfigureNumbericBox(box, allowNegative)
	if not allowNegative then
		box:SetNumeric(true)
		return
	end

	box:HookScript("OnTextChanged", function(boxSelf, userInput)
		if not userInput then
			return
		end

		local text = boxSelf:GetText()
		if text == "" or text == "-" or text:match("^%-?%d+$") then
			return
		end

		text = text:gsub("[^%d%-]", "")
		text = text:gsub("%-+", "-")

		if text:sub(1, 1) ~= "-" then
			text = text:gsub("%-", "")
		else
			text = "-" .. text:sub(2):gsub("%-", "")
		end

		boxSelf:SetText(text)
	end)
end

local function GetOrCreateDialog()
	if dialog then
		return dialog
	end

	dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	dialog:SetSize(360, 140)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetClampedToScreen(true)
	dialog:SetMovable(true)
	dialog:EnableMouse(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:Hide()

	dialog:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	dialog:SetBackdropColor(0, 0, 0, 0.9)

	dialog.Title = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	dialog.Title:SetPoint("TOP", dialog, "TOP", 0, -8)
	dialog.Title:SetText(L["Notification"])
	dialog.Title:SetTextColor(1, 0.82, 0)

	dialog.TitleDivider = dialog:CreateTexture(nil, "ARTWORK")
	dialog.TitleDivider:SetHeight(1)
	dialog.TitleDivider:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -28)
	dialog.TitleDivider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -8, -28)
	dialog.TitleDivider:SetColorTexture(1, 1, 1, 0.15)

	dialog.Text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	dialog.Text:SetPoint("TOPLEFT", 12, -40)
	dialog.Text:SetPoint("TOPRIGHT", -12, -40)
	dialog.Text:SetJustifyH("LEFT")
	dialog.Text:SetJustifyV("TOP")

	dialog.CloseButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	dialog.CloseButton:SetSize(80, 22)
	dialog.CloseButton:SetPoint("BOTTOM", 0, 12)
	dialog.CloseButton:SetText(CLOSE)
	dialog.CloseButton:SetScript("OnClick", function()
		dialog:Hide()
	end)

	return dialog
end

local function NilKeys(target)
	for k, v in pairs(target) do
		if type(v) == "table" then
			NilKeys(v)
		else
			target[k] = nil
		end
	end
end

function M:Notify(msg, ...)
	local formatted = string.format(msg, ...)
	print(addonName .. " - " .. formatted)
end

function M:NotifyCombatLockdown()
	M:Notify(L["Can't do that during combat."])
end

function M:CopyTable(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = M:CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end

	return dst
end

function M:ClampInt(v, minV, maxV, fallback)
	v = tonumber(v)
	if not v then
		return fallback
	end
	v = math.floor(v + 0.5)
	if v < minV then return minV end
	if v > maxV then return maxV end
	return v
end

function M:ClampFloat(v, minV, maxV, fallback)
	v = tonumber(v)
	if not v then return fallback end
	if v < minV then return minV end
	if v > maxV then return maxV end
	return v
end

function M:CanOpenOptionsDuringCombat()
	if LE_EXPANSION_LEVEL_CURRENT == nil or LE_EXPANSION_MIDNIGHT == nil then
		return true
	end
	return LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_MIDNIGHT
end

function M:SettingsSize()
	local settingsContainer = SettingsPanel and SettingsPanel.Container
	if settingsContainer then
		return settingsContainer:GetWidth(), settingsContainer:GetHeight()
	end
	if InterfaceOptionsFramePanelContainer then
		return InterfaceOptionsFramePanelContainer:GetWidth(), InterfaceOptionsFramePanelContainer:GetHeight()
	end
	return 600, 600
end

function M:AddCategory(panel)
	if not panel then
		error("AddCategory - panel must not be nil.")
	end
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
		return category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		return panel
	end
	return nil
end

function M:CreateTabs(options)
	assert(options and options.Parent, "CreateTabs: options.Parent required")
	assert(options.Tabs and #options.Tabs > 0, "CreateTabs: options.Tabs required")

	local parent = options.Parent
	local tabHeight = options.TabHeight or 22
	local tabMinWidth = options.TabMinWidth or 80
	local tabSpacing = options.TabSpacing or 6
	local stripHeight = options.StripHeight or 28

	local insets = options.ContentInsets or {}
	local insetL = insets.Left or 0
	local insetR = insets.Right or 0
	local insetT = insets.Top or 10
	local insetB = insets.Bottom or 10

	local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	strip:SetHeight(stripHeight)

	local body = CreateFrame("Frame", nil, parent)
	body:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", insetL, -insetT)
	body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insetR, insetB)

	local tabs = {}
	local keyToIndex = {}
	local selectedKey

	local function GetIndex(keyOrIndex)
		if type(keyOrIndex) == "number" then
			return keyOrIndex
		end
		if type(keyOrIndex) == "string" then
			return keyToIndex[keyOrIndex]
		end
	end

	local function SizeToText(btn)
		local fs = btn.Text
		local w = tabMinWidth
		if fs and fs.GetUnboundedStringWidth then
			w = math.max(tabMinWidth, fs:GetUnboundedStringWidth() + 26)
		elseif fs and fs.GetStringWidth then
			w = math.max(tabMinWidth, fs:GetStringWidth() + 26)
		end
		btn:SetWidth(w)
	end

	local normalR, normalG, normalB = GameFontNormal:GetTextColor()

	local function SetSelected(btn, isSelected)
		if isSelected then
			btn:SetBackdropColor(0.14, 0.14, 0.14, 0.92)
			btn:SetBackdropBorderColor(0.9, 0.75, 0.2, 0.9)
			btn.Text:SetTextColor(1, 1, 1, 1)
			btn.BottomEdge:Hide()
			btn.BottomLeftCorner:Hide()
			btn.BottomRightCorner:Hide()
			btn.Highlight:SetAlpha(0)
		else
			btn:SetBackdropColor(0.08, 0.08, 0.08, 0.65)
			btn:SetBackdropBorderColor(0, 0, 0, 0.55)
			btn.Text:SetTextColor(normalR, normalG, normalB, 1)
			btn.BottomEdge:Show()
			btn.BottomLeftCorner:Show()
			btn.BottomRightCorner:Show()
			btn.Highlight:SetAlpha(0.08)
		end
	end

	local controller = {}

	function controller.GetSelected(_)
		return selectedKey
	end

	function controller.GetContent(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		return i and tabs[i] and tabs[i].Content
	end

	function controller.GetTabButton(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		return i and tabs[i] and tabs[i].Button
	end

	function controller.Select(_, keyOrIndex)
		local i = GetIndex(keyOrIndex)
		if not i or not tabs[i] then
			return
		end

		selectedKey = tabs[i].Key

		for j = 1, #tabs do
			local isSel = (j == i)
			tabs[j].Content:SetShown(isSel)
			SetSelected(tabs[j].Button, isSel)
		end

		if options.OnTabChanged then
			options.OnTabChanged(selectedKey, i)
		end
	end

	controller.Tabs = tabs

	local prev
	for i, def in ipairs(options.Tabs) do
		assert(def.Key and def.Key ~= "", "CreateTabs: each tab needs Key")
		assert(not keyToIndex[def.Key], "CreateTabs: duplicate Key: " .. def.Key)

		local btn = CreateFrame("Button", nil, strip, "BackdropTemplate")
		btn:SetHeight(tabHeight)
		btn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})

		btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
		btn.Text:SetText(def.Title or def.Key)

		btn.Highlight = btn:CreateTexture(nil, "HIGHLIGHT")
		btn.Highlight:SetAllPoints(btn)
		btn.Highlight:SetColorTexture(1, 1, 1, 1)

		btn.BottomEdge = btn:CreateTexture(nil, "OVERLAY")
		btn.BottomEdge:SetColorTexture(0, 0, 0, 0.55)
		btn.BottomEdge:SetHeight(1)
		btn.BottomEdge:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 0)
		btn.BottomEdge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 0)

		btn.BottomLeftCorner = btn:CreateTexture(nil, "OVERLAY")
		btn.BottomLeftCorner:SetColorTexture(0, 0, 0, 0.55)
		btn.BottomLeftCorner:SetSize(1, 1)
		btn.BottomLeftCorner:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)

		btn.BottomRightCorner = btn:CreateTexture(nil, "OVERLAY")
		btn.BottomRightCorner:SetColorTexture(0, 0, 0, 0.55)
		btn.BottomRightCorner:SetSize(1, 1)
		btn.BottomRightCorner:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

		SizeToText(btn)

		if not prev then
			btn:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 1)
		else
			btn:SetPoint("LEFT", prev, "RIGHT", tabSpacing, 0)
		end

		prev = btn

		local content = CreateFrame("Frame", nil, body)
		content:SetAllPoints(body)
		content:Hide()

		local tab = { Key = def.Key, Title = def.Title or def.Key, Button = btn, Content = content }
		tabs[i] = tab
		keyToIndex[def.Key] = i

		btn:SetScript("OnClick", function()
			controller:Select(i)
		end)

		if type(def.Build) == "function" then
			def.Build(content)
		end
	end

	local initialIndex = 1
	if options.InitialKey and keyToIndex[options.InitialKey] then
		initialIndex = keyToIndex[options.InitialKey]
	end

	for i = 1, #tabs do
		local isSel = (i == initialIndex)
		tabs[i].Content:SetShown(isSel)
		SetSelected(tabs[i].Button, isSel)
	end
	selectedKey = tabs[initialIndex].Key

	if options.OnTabChanged then
		options.OnTabChanged(selectedKey, initialIndex)
	end

	return controller
end

function M:TextLine(options)
	if not options or not options.Parent then
		error("TextLine - invalid options.")
	end
	local fstring = options.Parent:CreateFontString(nil, "ARTWORK", options.Font or "GameFontWhite")
	fstring:SetSpacing(0)
	fstring:SetWidth(M.TextMaxWidth)
	fstring:SetJustifyH("LEFT")
	fstring:SetText(options.Text or "")
	return fstring
end

function M:TextBlock(options)
	if not options or not options.Parent or not options.Lines then
		error("TextBlock - invalid options.")
	end

	local verticalSpacing = options.VerticalSpacing or M.VerticalSpacing
	local container = CreateFrame("Frame", nil, options.Parent)
	container:SetWidth(M.TextMaxWidth)

	local anchor
	local totalHeight = 0

	for i, line in ipairs(options.Lines) do
		local fstring = M:TextLine({
			Text = line,
			Parent = container,
			Font = options.Font,
		})

		local gap = (i == 1) and 0 or (verticalSpacing / 2)

		if i == 1 then
			fstring:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
			totalHeight = totalHeight + fstring:GetStringHeight()
		else
			fstring:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
			totalHeight = totalHeight + gap + fstring:GetStringHeight()
		end

		anchor = fstring
	end

	container:SetHeight(math.max(1, totalHeight))
	return container
end

function M:Divider(options)
	if not options or not options.Parent then
		error("Divider - invalid options.")
	end

	local container = CreateFrame("Frame", nil, options.Parent)
	container:SetHeight(20)

	local leftLine = container:CreateTexture(nil, "ARTWORK")
	leftLine:SetColorTexture(1, 1, 1, 0.15)
	leftLine:SetHeight(1)

	local rightLine = container:CreateTexture(nil, "ARTWORK")
	rightLine:SetColorTexture(1, 1, 1, 0.15)
	rightLine:SetHeight(1)

	local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(options.Text or "")
	label:SetPoint("CENTER", container, "CENTER")

	leftLine:SetPoint("LEFT", 0, 0)
	leftLine:SetPoint("RIGHT", label, "LEFT", -8, 0)

	rightLine:SetPoint("LEFT", label, "RIGHT", 8, 0)
	rightLine:SetPoint("RIGHT", 0, 0)

	return container
end

function M:Dropdown(options)
	if not options or not options.Parent or not options.GetValue or not options.SetValue or not options.Items then
		error("Dropdown - invalid options.")
	end

	if MenuUtil and MenuUtil.CreateRadioMenu then
		local dd = CreateFrame("DropdownButton", nil, options.Parent, "WowStyle1DropdownTemplate")
		dd:SetupMenu(function(_, rootDescription)
			for _, value in ipairs(options.Items) do
				local text = options.GetText and options.GetText(value) or tostring(value)
				rootDescription:CreateRadio(text, function(x)
					return x == options.GetValue()
				end, function()
					options.SetValue(value)
				end, value)
			end
		end)

		function dd.MiniRefresh(ddSelf)
			ddSelf:Update()
		end

		AddControlForRefresh(options.Parent, dd)
		return dd, true
	end

	error("Failed to create a dropdown control - requires modern WoW client")
end

function M:Checkbox(options)
	if not options or not options.Parent or not options.GetValue or not options.SetValue then
		error("Checkbox - invalid options.")
	end

	local checkbox = CreateFrame("CheckButton", nil, options.Parent, "UICheckButtonTemplate")
	checkbox.Text:SetText(" " .. options.LabelText)
	checkbox.Text:SetFontObject("GameFontNormal")
	checkbox:SetChecked(options.GetValue())
	checkbox:HookScript("OnClick", function()
		options.SetValue(checkbox:GetChecked())
		checkbox:SetChecked(options.GetValue())
	end)

	if options.Tooltip then
		checkbox:SetScript("OnEnter", function(chkSelf)
			GameTooltip:SetOwner(chkSelf, "ANCHOR_RIGHT")
			local tooltipTitle = options.LabelText
			if not tooltipTitle or tooltipTitle:match("^%s*$") then
				tooltipTitle = "Information"
			end
			GameTooltip:SetText(tooltipTitle, 1, 0.82, 0)
			GameTooltip:AddLine(options.Tooltip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		checkbox:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	function checkbox.MiniRefresh()
		checkbox:SetChecked(options.GetValue())
	end

	AddControlForRefresh(options.Parent, checkbox)
	return checkbox
end

function M:Slider(options)
	if not options or not options.Parent or not options.GetValue or not options.SetValue
		or not options.Min or not options.Max or not options.Step then
		error("Slider - invalid options.")
	end

	local slider = CreateFrame("Slider", addonName .. "Slider" .. sliderId, options.Parent, "OptionsSliderTemplate")
	sliderId = sliderId + 1

	local label = slider:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 8)
	label:SetText(options.LabelText)

	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(options.Min, options.Max)
	slider:SetValue(options.GetValue())
	slider:SetValueStep(options.Step)
	slider:SetObeyStepOnDrag(true)
	slider:SetHeight(20)
	slider:SetWidth(options.Width or 400)

	local low = _G[slider:GetName() .. "Low"]
	local high = _G[slider:GetName() .. "High"]
	if low and high then
		low:SetText(options.Min)
		high:SetText(options.Max)
	end

	local hasFloat = math.floor(options.Step) ~= options.Step
	local box = CreateFrame("EditBox", nil, options.Parent, "InputBoxTemplate")

	if not hasFloat then
		ConfigureNumbericBox(box, options.Min < 0)
	end

	local function GetMaxLetters(min, max, step)
		local function GetDecimalPlaces(s)
			local str = tostring(s)
			local dot = str:find("%.")
			if not dot then return 0 end
			return #str - dot
		end
		local decimals = GetDecimalPlaces(step)
		local maxAbs = math.max(math.abs(min), math.abs(max))
		local intDigits = #tostring(math.floor(maxAbs))
		local letters = intDigits
		if decimals > 0 then letters = letters + 1 + decimals end
		if min < 0 then letters = letters + 1 end
		return letters
	end

	box:SetPoint("CENTER", slider, "CENTER", 0, 30)
	box:SetFontObject("GameFontWhite")
	box:SetSize(50, 20)
	box:SetAutoFocus(false)
	box:SetMaxLetters(GetMaxLetters(options.Min, options.Max, options.Step))
	box:SetText(tostring(options.GetValue()))
	box:SetJustifyH("CENTER")
	box:SetCursorPosition(0)

	slider:SetScript("OnValueChanged", function(_, sliderValue, userInput)
		if userInput ~= nil and not userInput then return end
		box:SetText(tostring(sliderValue))
		options.SetValue(sliderValue)
	end)

	box:SetScript("OnTextChanged", function(_, userInput)
		if not userInput then return end
		local value = tonumber(box:GetText())
		if not value then return end
		slider:SetValue(value)
		options.SetValue(value)
	end)

	function box.MiniRefresh(boxSelf)
		local value = options.GetValue()
		boxSelf:SetText(tostring(value))
		boxSelf:SetCursorPosition(0)
	end

	function slider.MiniRefresh(sliderSelf)
		local value = options.GetValue()
		sliderSelf:SetValue(value)
	end

	AddControlForRefresh(options.Parent, slider)
	AddControlForRefresh(options.Parent, box)

	return { Slider = slider, EditBox = box, Label = label }
end

function M:ShowDialog(options)
	if not options or not options.Text then
		error("ShowDialog - invalid options.")
	end

	local dlg = GetOrCreateDialog()
	local width = options.Width or 360
	dlg:SetWidth(width)
	dlg.Title:SetText(options.Title or L["Notification"])
	dlg.Text:SetWidth(width - 40)
	dlg.Text:SetText(options.Text)
	dlg.Text:SetWordWrap(true)

	local textHeight = dlg.Text:GetStringHeight()
	dlg:SetHeight(textHeight + 110)
	dlg:ClearAllPoints()
	dlg:SetPoint("CENTER", UIParent, "CENTER")
	dlg:Show()
end

function M:OpenSettings(category, panel)
	if not category or not panel then return end
	if Settings and Settings.OpenToCategory then
		if not InCombatLockdown() or M:CanOpenOptionsDuringCombat() then
			Settings.OpenToCategory(category:GetID())
		else
			M:NotifyCombatLockdown()
		end
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function M:WaitForAddonLoad(callback)
	if not callback then
		error("WaitForAddonLoad - callback must not be nil.")
	end
	onLoadCallbacks[#onLoadCallbacks + 1] = callback
	if loaded then
		callback()
	end
end

function M:GetSavedVars(defaults)
	local name = "PVPSoundDB"  -- Match .toc SavedVariables declaration
	local vars = _G[name] or {}
	_G[name] = vars
	if defaults then
		return M:CopyTable(defaults, vars)
	end
	return vars
end

function M:ResetSavedVars(defaults)
	local name = "PVPSoundDB"  -- Match .toc SavedVariables declaration
	local vars = _G[name] or {}
	NilKeys(vars)
	if defaults then
		return M:CopyTable(defaults, vars)
	end
	return vars
end

function M:CleanTable(target, template, cleanValues, recurse)
	if type(target) ~= "table" or type(template) ~= "table" then
		return
	end
	for key, value in pairs(target) do
		local templateValue = template[key]
		if cleanValues and templateValue == nil then
			target[key] = nil
		elseif cleanValues and type(value) == "table" and type(templateValue) ~= "table" then
			target[key] = templateValue
		elseif recurse and type(value) == "table" and type(templateValue) == "table" then
			M:CleanTable(value, templateValue, cleanValues, recurse)
		end
	end
end

function M:ColumnWidth(columns, padding, spacingColumns)
	local settingsWidth, _ = M:SettingsSize()
	local usableWidth = settingsWidth - (padding * 2)
	local width = math.floor(usableWidth / (columns + spacingColumns))
	return width
end

local function OnAddonLoaded(_, _, name)
	if name ~= addonName then
		return
	end
	loaded = true
	loader:UnregisterEvent("ADDON_LOADED")
	for _, callback in ipairs(onLoadCallbacks) do
		callback()
	end
end

loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", OnAddonLoaded)
