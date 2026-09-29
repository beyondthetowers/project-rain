--[[
    src/utility/console/hover.lua

    Hover effect for the CONSOLE theme: the element inverts.

    The library already has a hover, but it is only a faint tint -- it spawns a
    child Frame inside the hovered element with BackgroundColor3 =
    Library.AccentColor and tweens its transparency (ui.lua ~2156). On a black
    surface that is almost invisible, and it never touches the label.

    This inverts instead: a black row goes solid white with black text, a light
    element goes the other way, with a two-frame flicker on the way in. Same
    spirit as the "inversione dei colori" in the art brief.

    Finding targets: the library ships ZERO TextButtons -- everything clickable
    is a Frame with an input connection, which cannot be queried. So elements
    are matched on shape instead: a fill you can see, a label inside, 14-44px
    tall, at least 80px wide. That measured 463 elements on a live client.
]]

local hover = {};

local states = setmetatable({}, { __mode = "k" });
local attached_count = 0;

local FLICKER_STEPS = 3;
local FLICKER_DELAY = 0.028;

-- ── target selection ───────────────────────────────────────────────────────
local function has_label(object)
    for _, child in ipairs(object:GetDescendants()) do
        if child:IsA("TextLabel") then
            return true;
        end;
    end;
    return false;
end;

local function is_candidate(object)
    if states[object] then
        return false;
    end;

    local ok, result = pcall(function()
        if object:IsA("TextButton") or object:IsA("ImageButton") then
            return true;
        end;

        if not (object:IsA("Frame") or object:IsA("TextBox")) then
            return false;
        end;

        local height = object.AbsoluteSize.Y;
        if height < 14 or height > 44 then
            return false;
        end;
        if object.AbsoluteSize.X < 80 then
            return false;
        end;

        -- needs some fill to invert; a fully transparent layout row has nothing
        -- to turn white
        if object.BackgroundTransparency >= 0.9 then
            return false;
        end;

        return has_label(object);
    end);

    return ok and result == true;
end;

-- ── the effect ─────────────────────────────────────────────────────────────
local function collect_text(object)
    local list = {};
    for _, child in ipairs(object:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextBox") then
            list[#list + 1] = child;
        end;
    end;
    return list;
end;

-- Invert, whichever way round the element currently is. A white row would
-- otherwise "invert" to white and look like nothing happened.
local function invert_targets(background)
    local luminance = 0.299 * background.R + 0.587 * background.G + 0.114 * background.B;
    if luminance < 0.5 then
        return Color3.new(1, 1, 1), Color3.new(0, 0, 0);
    end;
    return Color3.new(0, 0, 0), Color3.new(1, 1, 1);
end;

local function paint(state, inverted)
    local object = state.object;

    if inverted then
        pcall(function()
            object.BackgroundColor3 = state.target_bg;
            object.BackgroundTransparency = state.target_transparency;
        end);
        for _, label in ipairs(state.targets) do
            pcall(function() label.TextColor3 = state.target_text end);
        end;
    else
        pcall(function()
            if state.original_bg then
                object.BackgroundColor3 = state.original_bg;
            end;
            object.BackgroundTransparency = state.original_transparency;
        end);
        for index, label in ipairs(state.targets) do
            local original = state.original_text[index];
            if original then
                pcall(function() label.TextColor3 = original end);
            end;
        end;
    end;
end;

-- Snapshot at enter, not at attach. The library repaints text colours on theme
-- changes, so a snapshot taken when the connection was made goes stale and
-- leaving the element would restore a colour from an earlier theme.
local function snapshot(state)
    local object = state.object;

    state.targets = collect_text(object);
    state.original_text = {};
    for index, label in ipairs(state.targets) do
        state.original_text[index] = label.TextColor3;
    end;

    state.original_bg = object.BackgroundColor3;
    state.original_transparency = object.BackgroundTransparency;

    local background, text = invert_targets(object.BackgroundColor3);
    state.target_bg = background;
    state.target_text = text;
    state.target_transparency = math.min(object.BackgroundTransparency, 0.06);
end;

local function on_enter(object)
    local state = states[object];
    if not state then
        return;
    end;

    snapshot(state);
    state.hovered = true;
    state.token = (state.token or 0) + 1;
    local token = state.token;

    -- flicker in rather than fade. 1-2 hard toggles over ~60ms.
    task.spawn(function()
        for step = 1, FLICKER_STEPS do
            if not state.hovered or state.token ~= token then
                return;
            end;
            paint(state, step % 2 == 1);
            task.wait(FLICKER_DELAY);
        end;
        if state.hovered and state.token == token then
            paint(state, true);
        end;
    end);
end;

local function on_leave(object)
    local state = states[object];
    if not state then
        return;
    end;

    state.hovered = false;
    state.token = (state.token or 0) + 1;   -- invalidate any in-flight flicker
    paint(state, false);
end;

-- ── attach ─────────────────────────────────────────────────────────────────
function hover.apply()
    if not Library or not Library.ScreenGui then
        return 0;
    end;

    local attached = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if is_candidate(descendant) then
            local state = { object = descendant };
            states[descendant] = state;

            local ok = pcall(function()
                descendant.MouseEnter:Connect(function() on_enter(descendant) end);
                descendant.MouseLeave:Connect(function() on_leave(descendant) end);
            end);

            if ok then
                attached = attached + 1;
                attached_count = attached_count + 1;
            else
                states[descendant] = nil;
            end;
        end;
    end;

    return attached;
end;

-- The library builds tab contents and dropdown options lazily, so new elements
-- keep appearing after the first pass.
function hover.start_watchdog()
    if hover.watching then
        return;
    end;
    hover.watching = true;

    task.spawn(function()
        for _ = 1, 8 do
            task.wait(2);
            pcall(hover.apply);
        end;
    end);
end;

function hover.count()
    return attached_count;
end;

return hover;
