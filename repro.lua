--[[
    repro.lua — detection bisect harness
    Project Rain, instant-permaban investigation

    A permaban that lands before you touch anything is server-authoritative,
    which means it is triggered by the first thing PR does. Reading the code
    narrows it to a list; only a bisect names the culprit.

    ── use ───────────────────────────────────────────────────────────────────
    1. put this file in your executor workspace next to the repo
    2. set SUSPECT below (or write the number into suspect.txt)
    3. inject on a burner account
    4. survive 60s -> suspect is clean. banned -> suspect is the trigger.

    Each run installs exactly ONE suspect. Do not batch them: a ban at
    suspect 6 with 1..5 also installed tells you nothing.

        SUSPECT   what it does
        -------   ------------------------------------------------------------
          0       control: does nothing at all
          1       writes a bare Lua closure into game.__namecall
          2       sets ClientManager.Enabled = false
          3       hookfunction on RemoteEvent.FireServer
          4       hookfunction on tostring
          5       writes a bare Lua closure into game.__newindex
          6       walks the whole heap with getgc(true)
          7       coroutine.yield() inside a FireServer hook
          8       the "#getconnections(remote.Changed) > 0" ban-remote heuristic
          9       writes into the shared table
         10       renames a KeyHandler remote
         11       control for the fix: newcclosure'd game.__namecall hook
]]

local SUSPECT = (function()
    local from_file = isfile("suspect.txt") and readfile("suspect.txt") or nil;
    return tonumber(from_file) or 1;
end)();

local NAMES = {
    [0]  = "control (no-op)",
    [1]  = "raw Lua closure in game.__namecall",
    [2]  = "ClientManager.Enabled = false",
    [3]  = "hookfunction(RemoteEvent.FireServer)",
    [4]  = "hookfunction(tostring)",
    [5]  = "raw Lua closure in game.__newindex",
    [6]  = "full-heap getgc(true) scan",
    [7]  = "coroutine.yield inside a FireServer hook",
    [8]  = "Changed-connection ban-remote heuristic",
    [9]  = "writes into the shared table",
    [10] = "rename a KeyHandler remote",
    [11] = "newcclosure'd game.__namecall hook (the fix)",
};

local suspects = {};

-- ── 0 ──────────────────────────────────────────────────────────────────────
suspects[0] = function() end;

-- ── 1 ──────────────────────────────────────────────────────────────────────
-- The vanilla slot is a C function. A Lua closure there fails
-- iscclosure(getrawmetatable(game).__namecall).
suspects[1] = function()
    local mt = getrawmetatable(game);
    local original = mt.__namecall;
    setreadonly(mt, false);
    mt.__namecall = function(self, ...)
        return original(self, ...);
    end;
    setreadonly(mt, true);
end;

-- ── 2 ──────────────────────────────────────────────────────────────────────
suspects[2] = function()
    local player = game:GetService("Players").LocalPlayer;
    local actor = player:WaitForChild("PlayerScripts"):WaitForChild("ClientActor");
    local manager = actor:WaitForChild("ClientManager");
    manager.Enabled = false;
end;

-- ── 3 ──────────────────────────────────────────────────────────────────────
suspects[3] = function()
    local original;
    original = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
        return original(self, ...);
    end);
end;

-- ── 4 ──────────────────────────────────────────────────────────────────────
suspects[4] = function()
    local original;
    original = hookfunction(tostring, function(value)
        return original(value);
    end);
end;

-- ── 5 ──────────────────────────────────────────────────────────────────────
suspects[5] = function()
    local mt = getrawmetatable(game);
    local original = mt.__newindex;
    setreadonly(mt, false);
    mt.__newindex = function(self, key, value, ...)
        return original(self, key, value, ...);
    end;
    setreadonly(mt, true);
end;

-- ── 6 ──────────────────────────────────────────────────────────────────────
suspects[6] = function()
    local walked = 0;
    for _, value in next, getgc(true) do
        walked = walked + 1;
    end;
    print("[repro] heap objects seen:", walked);
end;

-- ── 7 ──────────────────────────────────────────────────────────────────────
-- The original yields the anti-cheat's own coroutine to swallow its report.
suspects[7] = function()
    local requests = game:GetService("ReplicatedStorage"):WaitForChild("Requests");
    local target = requests:GetChildren()[1];
    if not target then
        return;
    end;

    local original;
    original = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
        if self == target then
            return coroutine.yield();
        end;
        return original(self, ...);
    end);
end;

-- ── 8 ──────────────────────────────────────────────────────────────────────
-- Harmless by itself: enumerates the signal PR treats as "this is a ban
-- remote". Included to confirm the heuristic still describes the live build.
suspects[8] = function()
    local requests = game:GetService("ReplicatedStorage"):WaitForChild("Requests");
    local reported = {};
    for _, remote in next, requests:GetChildren() do
        local ok, count = pcall(function()
            return #getconnections(remote.Changed);
        end);
        if ok and count and count > 0 then
            reported[#reported + 1] = remote.Name;
        end;
    end;
    print("[repro] remotes matching the Changed heuristic:", #reported);
    for _, name in next, reported do
        print("        ", name);
    end;
end;

-- ── 9 ──────────────────────────────────────────────────────────────────────
-- shared is a table game scripts can also read. PR writes b, unloaded and
-- damage_registry into it.
suspects[9] = function()
    shared.b = true;
    shared.unloaded = false;
    shared.damage_registry = {};
end;

-- ── 10 ──────────────────────────────────────────────────────────────────────
suspects[10] = function()
    local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
    local manager = modules:WaitForChild("ClientManager");
    local handler = manager:WaitForChild("KeyHandler");
    local victim = handler:FindFirstChildOfClass("RemoteEvent");
    if victim then
        victim.Name = string.format("%x", math.random(0, 0xFFFFFF));
    end;
end;

-- ── 11 ──────────────────────────────────────────────────────────────────────
-- Same shape as suspect 1, but the slot keeps its calling convention.
suspects[11] = function()
    local mt = getrawmetatable(game);
    local original = mt.__namecall;
    local handler = function(self, ...)
        return original(self, ...);
    end;
    if type(newcclosure) == "function" then
        handler = newcclosure(handler) or handler;
    end;
    setreadonly(mt, false);
    mt.__namecall = handler;
    setreadonly(mt, true);
end;

-- ── run ────────────────────────────────────────────────────────────────────
local label = NAMES[SUSPECT] or "unknown";
print(string.format("[repro] suspect %d — %s", SUSPECT, label));

local runner = suspects[SUSPECT];
if not runner then
    warn(string.format("[repro] no suspect %d; nothing installed", SUSPECT));
else
    local ok, err = pcall(runner);
    if not ok then
        print("[repro] suspect raised (still a signal):", err);
    else
        print("[repro] suspect installed cleanly");
    end;
end;

-- Keep the client alive and idle so the observation window is the same for
-- every suspect. Nothing here touches the game.
print("[repro] holding for 60s — watch for the ban");
task.wait(60);
print("[repro] survived 60s on suspect " .. SUSPECT);
