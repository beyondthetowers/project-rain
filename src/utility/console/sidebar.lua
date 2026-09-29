--[[
    src/utility/console/sidebar.lua

    Turns the library's horizontal tab strip into a left sidebar, and moves the
    window title into that sidebar as its header.

    Same philosophy as console/theme.lua: this is a post-pass over the built UI,
    not an edit to the 2500-line library. The library stays swappable.

    The layout it operates on (measured from the live tree):

        Outer (550x550)
          Inner (548x548)
            TextLabel  "CONSOLE // USER_xxx"   546x19   <- title, moves to sidebar
            TextBox    search                136x21   top-right, shifts by W
            container (546x525)
              holder (546x525)
                separator                     546x2
                STRIP                         546x22   <- becomes the sidebar
                  [ 110, 109, 109, 109, 109 ]          5 tab frames
                content (546x525 at y+22)
                  column A 266 wide
                  column B 266 wide

    The window is widened by SIDEBAR_WIDTH rather than squeezing the two 266px
    content columns, so nothing inside a groupbox reflows or clips. Content
    keeps its exact width and just moves right.
]]

local sidebar = {};

local SIDEBAR_WIDTH = 132;
local TAB_HEIGHT = 22;
local TAB_PADDING = 3;

-- ── helpers ────────────────────────────────────────────────────────────────
local function gui_children(parent)
    local out = {};
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            out[#out + 1] = child;
        end;
    end;
    return out;
end;

local function add_width(object, delta)
    object.Size = UDim2.new(
        object.Size.X.Scale, object.Size.X.Offset + delta,
        object.Size.Y.Scale, object.Size.Y.Offset
    );
end;

local function shift_x(object, delta)
    object.Position = UDim2.new(
        object.Position.X.Scale, object.Position.X.Offset + delta,
        object.Position.Y.Scale, object.Position.Y.Offset
    );
end;

local function text_of(object)
    local ok, text = pcall(function() return object.Text end);
    if not ok or type(text) ~= "string" then
        return "";
    end;
    return (text:gsub("<[^>]+>", ""));
end;

-- ── locate ─────────────────────────────────────────────────────────────────
-- The tab strip is the only wide, short Frame carrying a horizontal
-- UIListLayout with a handful of children. Matching on shape rather than on a
-- name or child index survives the library renaming or reordering things.
local function find_strip(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Frame") then
            local layout = descendant:FindFirstChildOfClass("UIListLayout");
            if layout and layout.FillDirection == Enum.FillDirection.Horizontal then
                local count = #gui_children(descendant);
                if count >= 2 and count <= 12
                    and descendant.AbsoluteSize.X > descendant.AbsoluteSize.Y * 4 then
                    return descendant, layout;
                end;
            end;
        end;
    end;
    return nil;
end;

-- The window title: a TextLabel near the top of the window carrying the brand.
local function find_title(root)
    local best;
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local text = text_of(descendant);
            if text:find("DECAY") then
                if not best or descendant.AbsolutePosition.Y < best.AbsolutePosition.Y then
                    best = descendant;
                end;
            end;
        end;
    end;
    return best;
end;

local function find_search_box(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextBox") then
            return descendant;
        end;
    end;
    return nil;
end;

-- ── apply ──────────────────────────────────────────────────────────────────
local function build(outer)
    local strip, layout = find_strip(outer);
    if not strip or not layout then
        return false, "no horizontal tab strip found";
    end;

    local holder = strip.Parent;
    local container = holder and holder.Parent;

    -- Inner is the first *direct* child Frame that isn't the theme overlay.
    -- FindFirstChildWhichIsA would hand back CONSOLE_OVERLAY, which is also a
    -- Frame, and we would widen the overlay instead of the window body.
    local inner;
    for _, child in ipairs(gui_children(outer)) do
        if child.Name ~= "CONSOLE_OVERLAY" then
            inner = child;
            break;
        end;
    end;

    if not holder or not container or not inner then
        return false, "could not resolve the frame chain";
    end;

    local siblings = gui_children(holder);
    local separator, content;
    for _, sibling in ipairs(siblings) do
        if sibling ~= strip then
            if sibling.AbsoluteSize.Y <= 6 then
                separator = separator or sibling;
            elseif sibling.AbsoluteSize.Y > 100 then
                content = content or sibling;
            end;
        end;
    end;

    local search = find_search_box(inner);
    local title = find_title(inner);

    -- Measure before touching anything. Once the window is resized these
    -- values are gone.
    local content_width = content and content.AbsoluteSize.X or nil;
    local separator_height = separator and separator.AbsoluteSize.Y or nil;

    -- ── widen ──────────────────────────────────────────────────────────────
    -- Only the window itself is widened outright. Its descendants are mostly
    -- scale-sized (Inner is 1,-2 of Outer, and so on), so they follow on their
    -- own -- explicitly widening those double-counts. The earlier version did
    -- exactly that and produced an 812px Inner inside a 682px window.
    add_width(outer, SIDEBAR_WIDTH);

    -- Only genuinely fixed-width frames along the chain need help. Threshold is
    -- on Scale, not Offset: anything mostly scaled is already relative.
    for _, object in ipairs({ inner, container, holder }) do
        if object and object.Size.X.Scale <= 0.5 then
            add_width(object, SIDEBAR_WIDTH);
        end;
    end;

    -- The separator is a hairline that should span whatever the window is now.
    if separator then
        separator.Size = UDim2.new(1, 0, 0, separator_height or separator.Size.Y.Offset);
    end;

    -- Content is pinned to the width it had and pushed right by the sidebar.
    -- Left to scale it would stretch across the new window and drag both 266px
    -- columns out of position.
    if content and content_width then
        content.Size = UDim2.new(0, content_width, content.Size.Y.Scale, content.Size.Y.Offset);
        content.Position = UDim2.new(0, SIDEBAR_WIDTH, content.Position.Y.Scale, content.Position.Y.Offset);
    end;

    -- Right-anchored widgets keep their gap to the edge by shifting by the same
    -- amount -- but only when they are fixed-offset. One anchored with scale 1
    -- is already following the widened parent, and shifting it again pushes it
    -- clean off the window (measured: search box at x=1260 in a window that
    -- ends at 1301).
    if search and search.Position.X.Scale <= 0.5 then
        shift_x(search, SIDEBAR_WIDTH);
    end;

    -- ── the strip becomes the sidebar ──────────────────────────────────────
    strip.Position = UDim2.new(0, 6, 0, 24);
    strip.Size = UDim2.new(0, SIDEBAR_WIDTH - 12, 1, -30);

    layout.FillDirection = Enum.FillDirection.Vertical;
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
    layout.Padding = UDim.new(0, TAB_PADDING);

    -- ── the title becomes the sidebar header ───────────────────────────────
    if title then
        title.Position = UDim2.new(0, 8, 0, 5);
        title.Size = UDim2.new(0, SIDEBAR_WIDTH - 16, 0, 16);
        title.TextXAlignment = Enum.TextXAlignment.Left;
        pcall(function() title.TextSize = 13 end);
        pcall(function()
            local stroke = title:FindFirstChildOfClass("UIStroke");
            if stroke then stroke.Transparency = 0.35 end;
        end);
    end;

    sidebar.strip = strip;
    sidebar.layout = layout;
    sidebar.title = title;
    sidebar.content = content;
    sidebar.outer = outer;

    return true;
end;

-- The library re-sizes and re-shows tab buttons on switch, which can undo the
-- row sizing. Cheap to re-assert; called on tab click and by a short watchdog.
function sidebar.reassert()
    if not sidebar.strip or not sidebar.strip.Parent then
        return false;
    end;

    local ok = pcall(function()
        local children = gui_children(sidebar.strip);
        local count = #children;
        if count == 0 then
            return;
        end;

        -- fill the column, sharing any leftover height across the tabs so a
        -- short sidebar doesn't leave a ragged gap at the bottom
        local available = sidebar.strip.AbsoluteSize.Y - (TAB_PADDING * (count - 1));
        local height = math.floor(available / count);
        if height < TAB_HEIGHT then
            height = TAB_HEIGHT;
        end;
        if height > 34 then
            height = 34;
        end;

        for _, tab in ipairs(children) do
            tab.Size = UDim2.new(1, 0, 0, height);
        end;
    end);

    return ok;
end;

function sidebar.apply()
    if sidebar.applied then
        return true;
    end;

    if not Library then
        return false;
    end;

    local outer = Library.ConsoleWindow and Library.ConsoleWindow.Holder;
    if not outer then
        return false;
    end;

    local ok, result, reason = pcall(build, outer);
    if not ok then
        warn("[console] sidebar failed:", result);
        return false;
    end;
    if not result then
        warn("[console] sidebar skipped:", reason);
        return false;
    end;

    sidebar.applied = true;
    sidebar.reassert();

    -- re-assert on tab clicks: the library touches sizes on switch
    pcall(function()
        for _, tab in ipairs(gui_children(sidebar.strip)) do
            tab.InputBegan:Connect(function()
                task.wait();
                sidebar.reassert();
            end);
        end;
    end);

    -- and once more shortly after, covering the library's own post-build pass
    task.spawn(function()
        for _ = 1, 6 do
            task.wait(0.25);
            sidebar.reassert();
        end;
    end);

    return true;
end;

return sidebar;
