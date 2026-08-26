local _, Addon = ...

local Theme = Addon.OptionsTheme
local Fonts = Addon.OptionsFonts

--- The header every page and the welcome window share: title, subtitle, the
--- rule and its accent. Given an icon, the mark sits in the corner and the
--- text starts after it.
---@class OptionsHeader
local OptionsHeader = {}

---@param frame table
---@param options { title: string, subtitle: string?, icon: string? }
function OptionsHeader.Build(frame, options)
	local textLeft = Theme.PADDING

	if options.icon then
		local mark = frame:CreateTexture(nil, "ARTWORK")
		mark:SetTexture(options.icon)
		mark:SetSize(Theme.HEADER_ICON_SIZE, Theme.HEADER_ICON_SIZE)
		mark:SetPoint("TOPLEFT", Theme.PADDING, -Theme.HEADER_ICON_TOP)

		textLeft = textLeft + Theme.HEADER_ICON_SIZE + Theme.HEADER_ICON_GAP
	end

	local title = frame:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(Fonts.TITLE)
	title:SetPoint("TOPLEFT", textLeft, -Theme.HEADER_TOP)
	title:SetText(options.title)
	title:SetTextColor(Theme.TEXT_COLOR.red, Theme.TEXT_COLOR.green, Theme.TEXT_COLOR.blue)

	if options.subtitle then
		local subtitle = frame:CreateFontString(nil, "ARTWORK")
		subtitle:SetFontObject(Fonts.SUBTITLE)
		subtitle:SetPoint("TOPLEFT", textLeft, -Theme.HEADER_SUBTITLE_GAP)
		subtitle:SetPoint("RIGHT", -Theme.PADDING, 0)
		subtitle:SetJustifyH("LEFT")
		subtitle:SetText(options.subtitle)
		subtitle:SetTextColor(Theme.MUTED_COLOR.red, Theme.MUTED_COLOR.green, Theme.MUTED_COLOR.blue)
	end

	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(
		Theme.BORDER_COLOR.red,
		Theme.BORDER_COLOR.green,
		Theme.BORDER_COLOR.blue,
		Theme.BORDER_COLOR.alpha
	)
	rule:SetHeight(Theme.RULE_THICKNESS)
	rule:SetPoint("TOPLEFT", Theme.PADDING, -Theme.HEADER_RULE_GAP)
	rule:SetPoint("TOPRIGHT", -Theme.PADDING, -Theme.HEADER_RULE_GAP)

	local accent = frame:CreateTexture(nil, "OVERLAY")
	accent:SetColorTexture(
		Theme.ACCENT_COLOR.red,
		Theme.ACCENT_COLOR.green,
		Theme.ACCENT_COLOR.blue,
		Theme.ACCENT_COLOR.alpha
	)
	accent:SetSize(Theme.HEADER_ACCENT_WIDTH, Theme.RULE_THICKNESS)
	accent:SetPoint("TOPLEFT", rule, "TOPLEFT")
end

Addon.OptionsHeader = OptionsHeader
