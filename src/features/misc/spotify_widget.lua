--[[
    src/features/misc/spotify_widget.lua  — STUB

    Stripped from the OSS release. Required by src/ui/tabs/ui.lua:3, and
    src/utility/librarys/managers/SaveManager.lua reads
    aztup.spotify_widget.Position when saving window layout.

    Returns a table whose `new` yields a widget-shaped object with a settled
    Position, so the save path has something to serialise instead of nil.
]]

local widget = {};
widget.__index = widget;

widget.new = function()
    return setmetatable({
        Position = UDim2.fromOffset(0, 0),
        Visible = false,
    }, widget);
end;

function widget:SetVisible(value)
    self.Visible = value and true or false;
    return self;
end;

function widget:Destroy()
    return nil;
end;

return widget;
