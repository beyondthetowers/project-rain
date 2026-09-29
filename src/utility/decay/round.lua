--[[
    src/utility/decay/round.lua

    Rounds the corners of every visible element in the UI.

    Post-pass again, same as theme.lua and sidebar.lua: nothing in the library
    is edited, elements are decorated after they exist.

    Rules, in order of how much they matter:

    1.  Never touch an element that already has a UICorner. Several controls in
        this library build their own (toggle knobs are circular), and
        overwriting those flattens them.

    2.  Only round things where a corner is actually visible: an element with a
        background you can see, or a UIStroke that needs to follow the shape.
        Rounding a transparent layout container does nothing except clip its
        children unexpectedly.

    3.  Skip pure image elements (icons). Rounding a bitmap crops its artwork.

    4.  The theme overlay gets the same radius as the window it sits in, and so
        do its layers. ClipsDescendants on a rounded frame does not reliably
        clip to the rounded shape, so without this the square grain and
        scanlines would show through the window's rounded corners.
]]

local round = {};

local RADIUS = 6.0;

local function add_corner(object, radius)
    if object:FindFirstChildOfClass("UICorner") then
        return false;
    end;

    local ok = pcall(function()
        local corner = Instance.new("UICorner");
        corner.CornerRadius = UDim.new(0, radius);

        -- UICorner is not affected by sibling order, but parenting last keeps
        -- it out of the way of the library's own child lookups.
        corner.Parent = object;
    end);

    return ok;
end;

local function should_round(object)
    if not object:IsA("GuiObject") then
        return false;
    end;

    -- already shaped by the library
    if object:FindFirstChildOfClass("UICorner") then
        return false;
    end;

    local stroke = object:FindFirstChildOfClass("UIStroke");

    -- a pure image element: rounding would crop the artwork
    if object:IsA("ImageLabel") and object.Image ~= "" and not stroke then
        return object.BackgroundTransparency < 0.95;
    end;

    -- visible fill, or a border that has to follow the shape
    if object.BackgroundTransparency < 0.95 then
        return true;
    end;

    return stroke ~= nil;
end;

function round.apply()
    if not Library or not Library.ScreenGui then
        return 0;
    end;

    local applied = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if should_round(descendant) then
            local radius = RADIUS;

            -- very short elements (the 2px separator hairlines) would turn into
            -- pills; half their height keeps them looking like lines
            local height = descendant.AbsoluteSize.Y;
            if height > 0 and height < RADIUS * 2 then
                radius = math.max(1, math.floor(height / 2));
            end;

            if add_corner(descendant, radius) then
                applied = applied + 1;
            end;
        end;
    end;

    -- the overlay has to match the window it lives in, layers included
    pcall(function()
        local window = Library.DecayWindow and Library.DecayWindow.Holder;
        local holder = window and window:FindFirstChild("DECAY_OVERLAY");
        if not holder then
            return;
        end;

        add_corner(holder, RADIUS);
        for _, child in ipairs(holder:GetChildren()) do
            if child:IsA("GuiObject") then
                add_corner(child, RADIUS);
            end;
        end;
    end);

    return applied;
end;

-- The library builds some elements lazily -- dropdown options, tooltips, tab
-- contents on first visit -- so a one-shot pass misses them. Cheap to re-scan.
function round.start_watchdog()
    if round.watching then
        return;
    end;
    round.watching = true;

    task.spawn(function()
        for _ = 1, 8 do
            task.wait(2);
            pcall(round.apply);
        end;
    end);
end;

return round;
