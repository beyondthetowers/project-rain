--[[
    Project Rain — adaptive anti-cheat layer
    src/security/bypass.lua

    Replaces the constant-driven approach in src/features/hooking.lua.

    ── why the old layer stopped working ─────────────────────────────────────
    hooking.lua scanned getgc() for a table matching `#tbl == 13 and tbl[9] ==
    heaven_key`, where heaven_key is a compile-time constant folded out of the
    game's builder. Every Deepwoken update re-rolls that table, the constant
    goes stale, the scan never matches, KeyHandler never resolves — and then
    init.lua:174 kicks the player. The bypass did not get "detected"; it got
    invalidated, and the script's own fail-loud path killed the session.

    ── what this module does differently ─────────────────────────────────────
    1. STRUCTURE, NOT CONSTANTS. The KeyHandler remotes table is found by
       shape: a table whose values are RemoteEvents parented under
       ReplicatedStorage, six or more of them, alongside an encoder function.
       No magic number to go stale.
    2. ONE HOOK, NOT FIVE. The old layer did hookfunction() on
       RemoteEvent.FireServer, UnreliableRemoteEvent.FireServer and tostring.
       All three are visible to isfunctionhooked/getfunctionhash — the very
       APIs hooking.lua itself uses at line 419. Everything routes through a
       single __namecall chokepoint instead.
    3. SILENT DROP, NOT coroutine.yield(). Yielding inside a FireServer hook
       never returns to the caller. A dropped report now returns nil, which is
       indistinguishable from a successful FireServer.
    4. MODULES STAY ALIVE. `client_manager.Enabled = false` is a one-line
       signature and the numbered "error check (1)" log implies sibling checks
       were stripped. Nothing here disables a game module; the reports are
       intercepted on the way out instead.
    5. NO REPLICATED MUTATION. remote.Name is never rewritten — Instance.Name
       replicates, so the old renaming trick was broadcasting to the server.
    6. TAGS ARE NAMESPACED. Static tag strings ("PR_BREAKER_IGNORE" and
       friends) are a signature list on a public repo. Tags mint through a
       per-session namespace.
    7. NOTHING HERE KICKS. Every step is pcall'd and degrades to a no-op.
]]

local bypass = {};

-- ── windows of the game we touch ───────────────────────────────────────────
local rs            = game:GetService("ReplicatedStorage");
local players        = game:GetService("Players");
local local_player   = players.LocalPlayer;

bypass.salt = string.format("%06x", math.random(0, 0xFFFFFF));
bypass.verify_report = {};

-- ── logging ────────────────────────────────────────────────────────────────
function bypass.log(...)
    if getgenv().PR_DEBUG then
        print("[bypass]", ...);
    end;
end;

local function step(name, fn, ...)
    local results = table.pack(pcall(fn, ...));
    if not results[1] then
        bypass.verify_report[name] = tostring(results[2]);
        bypass.log(name, "failed:", results[2]);
        return nil;
    end;
    bypass.verify_report[name] = true;
    return table.unpack(results, 2, results.n);
end;
bypass.step = step;

-- ── executor introspection, with fallbacks ─────────────────────────────────
local raw_getupvalues =
    (type(getupvalues) == "function" and getupvalues)
    or (debug and type(debug.getupvalues) == "function" and debug.getupvalues)
    or nil;

local function upvalues_of(f)
    if raw_getupvalues then
        local ok, ups = pcall(raw_getupvalues, f);
        if ok and type(ups) == "table" then
            return ups;
        end;
    end;

    if debug and debug.getupvalue then
        local ups = {};
        for i = 1, 256 do
            local ok, name, value = pcall(debug.getupvalue, f, i);
            if not ok or name == nil then
                break;
            end;
            ups[i] = value;
        end;
        return ups;
    end;

    return nil;
end;

local function gc_snapshot()
    if type(getgc) ~= "function" then
        return {};
    end;
    local ok, snapshot = pcall(getgc, true);
    return ok and snapshot or {};
end;

-- ── shape classification ───────────────────────────────────────────────────
local function is_game_remote(value)
    if typeof(value) ~= "Instance" then
        return false;
    end;
    if not (value:IsA("RemoteEvent") or value:IsA("UnreliableRemoteEvent")) then
        return false;
    end;
    local parent = value.Parent;
    return parent ~= nil and (parent == rs or parent:IsDescendantOf(rs));
end;
bypass.is_game_remote = is_game_remote;

-- The KeyHandler registry is a 13-slot array. Slot 9 is the build key (the
-- original compared it against the hardcoded `heaven_key`, which went stale on
-- every update), slot 12 holds the remotes table, slot 13 the name -> key
-- encoder. Match the structure, drop the constant.
--
-- Two things this has to get right, both learned the hard way:
--
--   * Slot 12's remotes are NOT all parented under ReplicatedStorage. A live
--     read showed 16 entries, 15 of them RemoteEvents, of which only 5 were
--     RS-parented. Counting with `is_game_remote` here rejects the real table.
--   * The registry is not reachable from the KeyHandler module's upvalues —
--     there is no length-13 table in them. Only the whole-heap scan finds it.
local function classify_remote_table(value)
    if typeof(value) ~= "table" or #value ~= 13 then
        return nil;
    end;

    local build_key = rawget(value, 9);
    local remotes = rawget(value, 12);
    local encoder = rawget(value, 13);

    if typeof(build_key) ~= "number" then
        return nil;
    end;
    if typeof(remotes) ~= "table" or typeof(encoder) ~= "function" then
        return nil;
    end;

    local remote_count = 0;
    for _, item in next, remotes do
        if typeof(item) == "Instance"
            and (item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent"))
        then
            remote_count = remote_count + 1;
        end;
    end;

    if remote_count < 6 then
        return nil;
    end;

    return remotes, encoder;
end;

-- Recursively search a function's upvalue graph for the remotes table.
local function walk_for_remotes(f, depth)
    depth = depth or 0;
    if depth > 3 or typeof(f) ~= "function" then
        return nil;
    end;

    local ups = upvalues_of(f);
    if not ups then
        return nil;
    end;

    for _, value in next, ups do
        local tbl, encoder = classify_remote_table(value);
        if tbl then
            return tbl, encoder;
        end;
        if typeof(value) == "table" then
            for _, nested in next, value do
                local nested_tbl, nested_encoder = classify_remote_table(nested);
                if nested_tbl then
                    return nested_tbl, nested_encoder;
                end;
            end;
        end;
    end;

    for _, value in next, ups do
        if typeof(value) == "function" and value ~= f then
            local tbl, encoder = walk_for_remotes(value, depth + 1);
            if tbl then
                return tbl, encoder;
            end;
        end;
    end;

    return nil;
end;

-- ── KeyHandler resolution ──────────────────────────────────────────────────
-- Returns { remotes = <table>, encoder = <fn> } or nil. Never raises, never
-- kicks, never depends on a build constant.
function bypass.resolve_keyhandler()
    local module_root = rs:FindFirstChild("Modules");
    local client_manager = module_root and module_root:FindFirstChild("ClientManager");
    local key_handler = client_manager and client_manager:FindFirstChild("KeyHandler");

    if key_handler then
        local ok, module = pcall(require, key_handler);

        if ok then
            if typeof(module) == "table" then
                local tbl, encoder = classify_remote_table(module);
                if tbl then
                    return { remotes = tbl, encoder = encoder, module = module, source = "module" };
                end;
            end;

            local tbl, encoder = walk_for_remotes(module, 0);
            if tbl then
                return { remotes = tbl, encoder = encoder, module = module, source = "module_upvalues" };
            end;
        end;
    end;

    -- Fall back to a whole-heap shape scan. Slower, but constant-free: any
    -- table that looks like the KeyHandler registry will match.
    for _, value in next, gc_snapshot() do
        local tbl, encoder = classify_remote_table(value);
        if tbl then
            return { remotes = tbl, encoder = encoder, source = "gc_scan" };
        end;
    end;

    return nil;
end;

-- ── report-remote discovery ────────────────────────────────────────────────
-- The old layer required a remote literally named "ReportGoogleAnalyticsEvent"
-- and kicked the player if it was absent (hooking.lua:230). A rename upstream
-- turned into a self-inflicted kick. This unions four signals and treats an
-- empty result as "keep going", not as fatal.
local function collect_by_connections(blocked)
    local requests = rs:FindFirstChild("Requests");
    if not requests then
        return blocked;
    end;

    for _, remote in next, requests:GetChildren() do
        if not is_game_remote(remote) then
            continue;
        end;

        local ok, count = pcall(function()
            return #getconnections(remote.Changed);
        end);

        if ok and count and count > 0 then
            blocked[remote] = "changed_listener";
        end;
    end;

    return blocked;
end;

local function collect_by_clientmanager(blocked)
    local module_root = rs:FindFirstChild("Modules");
    local client_manager = module_root and module_root:FindFirstChild("ClientManager");
    if not client_manager then
        return blocked;
    end;

    local visited = {};

    local function walk(f, depth)
        if depth > 4 or typeof(f) ~= "function" or visited[f] then
            return;
        end;
        visited[f] = true;

        local ups = upvalues_of(f);
        if not ups then
            return;
        end;

        for _, value in next, ups do
            if is_game_remote(value) then
                blocked[value] = blocked[value] or "clientmanager_ref";
            elseif typeof(value) == "function" then
                walk(value, depth + 1);
            elseif typeof(value) == "table" then
                for _, nested in next, value do
                    if is_game_remote(nested) then
                        blocked[nested] = blocked[nested] or "clientmanager_ref";
                    elseif typeof(nested) == "function" then
                        walk(nested, depth + 1);
                    end;
                end;
            end;
        end;
    end;

    for _, child in next, client_manager:GetChildren() do
        local ok, module = pcall(require, child);
        if ok then
            walk(module, 0);
        end;
    end;

    return blocked;
end;

local function collect_by_name(blocked)
    local requests = rs:FindFirstChild("Requests");
    if not requests then
        return blocked;
    end;

    -- Deliberately narrow. "log" and "flag" were in here before and matched
    -- Dialogue, Login and Prologue — ordinary game remotes whose calls then got
    -- swallowed. Only tokens that cannot appear in normal traffic belong here.
    local needles = { "report", "analytics", "telemetry", "anticheat", "suspicious" };

    for _, remote in next, requests:GetChildren() do
        if not is_game_remote(remote) then
            continue;
        end;
        local lowered = remote.Name:lower();
        for _, needle in next, needles do
            if lowered:find(needle, 1, true) then
                blocked[remote] = blocked[remote] or ("name:" .. needle);
                break;
            end;
        end;
    end;

    return blocked;
end;

function bypass.collect_report_remotes()
    local blocked = {};
    step("collect.connections", collect_by_connections, blocked);
    step("collect.clientmanager", collect_by_clientmanager, blocked);
    step("collect.name", collect_by_name, blocked);

    -- Record what was matched, per remote. If a legitimate game remote shows up
    -- here its calls are being swallowed, which is the first thing to check
    -- when features or animations stop working.
    local listed = {};
    for remote, reason in next, blocked do
        local name = (typeof(remote) == "Instance") and remote.Name or tostring(remote);
        listed[#listed + 1] = string.format("%s (%s)", name, tostring(reason));
    end;
    table.sort(listed);
    bypass.blocked_list = listed;

    if #listed > 0 and getgenv().PR_DEBUG then
        print("[bypass] blocking", #listed, "remote(s):");
        for _, entry in next, listed do
            print("    ", entry);
        end;
    end;

    return blocked;
end;

-- ── caller attribution ─────────────────────────────────────────────────────
-- Attribution guesses "this call came from anti-cheat code" off a script name.
-- That guess has to be conservative. Deepwoken keeps its ENTIRE client module
-- tree under ReplicatedStorage.Modules.ClientManager.* — KeyHandler, the
-- gesture handlers, the character controllers (see features/hooking.lua:85,
-- which resolves Modules.ClientManager.KeyHandler). A bare "ClientManager"
-- marker therefore matches ordinary game code, and dropping its FireServer
-- calls is what makes the character stop animating.
--
-- Only leaf names that cannot mean anything else belong in this list. Matching
-- is done against the leaf only, never the full ancestor path.
bypass.ac_markers = {
    "AntiCheat",
    "Anti_Cheat",
    "Anti-Cheat",
    "Saturn",
    "Telemetry",
    "ReportGoogleAnalytics",
};

-- Off by default. Identity blocking (a remote positively recognised as a
-- report channel) cannot produce false positives. Attribution can, and a
-- wrong guess silently eats game traffic. Opt in with
--     getgenv().PR_ATTRIBUTION = true
bypass.attribution = false;

-- Last path segment of a source / full name.
local function leaf_of(identity)
    return identity:match("([^%./\\|]+)$") or identity;
end;

-- True when the frames above this one belong to anti-cheat code.
function bypass.caller_is_ac()
    if not bypass.attribution then
        return false;
    end;

    if type(getcallingscript) == "function" then
        local ok, caller = pcall(getcallingscript);
        if ok and typeof(caller) == "Instance" then
            local name = leaf_of(caller.Name);
            for _, marker in next, bypass.ac_markers do
                if name == marker then
                    return true, caller.Name;
                end;
            end;
        end;
    end;

    -- Reporters frequently run inside task.spawn, so the immediate caller is a
    -- thread rather than a script. Walk a few frames of source names, still
    -- comparing leaves only.
    for level = 2, 8 do
        local ok, source = pcall(debug.info, level, "s");
        if ok and type(source) == "string" then
            local leaf = leaf_of(source);
            for _, marker in next, bypass.ac_markers do
                if leaf == marker then
                    return true, source;
                end;
            end;
        end;
    end;

    return false;
end;

local function is_executor_caller()
    return type(checkcaller) == "function" and checkcaller();
end;

-- ── namecall chokepoint ────────────────────────────────────────────────────
-- Installs the drop logic in front of an existing __namecall chain. Pass the
-- previous handler so this composes with features/hooking.lua instead of
-- fighting it for the metamethod.
--
-- Two nets, in order:
--   1. identity   — the remote is one we recognised as a report channel
--   2. attribution — the call came out of anti-cheat code, whoever it is
-- Net 2 also covers InvokeServer, which the original only ever filtered for
-- FireServer.
function bypass.make_namecall_handler(blocked, previous)
    previous = previous or (function(_, ...) return end);

    return function(self, ...)
        local method = getnamecallmethod();

        if method == "FireServer" or method == "InvokeServer" then
            if not is_executor_caller() then
                if blocked and blocked[self] then
                    -- Return nil. A real FireServer returns nothing and a real
                    -- RemoteFunction that returns nothing yields nil, so the
                    -- caller cannot tell the report was dropped.
                    bypass.drops = (bypass.drops or 0) + 1;
                    bypass.log("dropped by identity:", tostring(self));
                    return;
                end;

                local is_ac, where = bypass.caller_is_ac();
                if is_ac then
                    bypass.drops = (bypass.drops or 0) + 1;
                    bypass.log("dropped by attribution:", where, method);
                    return;
                end;
            end;
        end;

        return previous(self, ...);
    end;
end;

function bypass.install_report_filter(blocked)
    if type(hookmetamethod) ~= "function" then
        return nil, "no hookmetamethod";
    end;

    local metatable = getrawmetatable(game);
    if not metatable then
        return nil, "no game metatable";
    end;

    local previous = rawget(metatable, "__namecall");
    local handler = bypass.make_namecall_handler(blocked, previous);

    -- The vanilla __namecall slot holds a C function. Installing a bare Lua
    -- closure there is detectable with iscclosure(getrawmetatable(game).__namecall).
    if type(newcclosure) == "function" then
        local wrapped = pcall(newcclosure, handler);
        if wrapped then
            handler = wrapped;
        end;
    end;

    local ok, previous_returned = pcall(hookmetamethod, game, "__namecall", handler);
    if not ok then
        return nil, tostring(previous_returned);
    end;

    return handler, previous_returned;
end;

-- ── ClientManager ──────────────────────────────────────────────────────────
-- Deliberately does NOT set Enabled = false. The module keeps running and
-- believing it is reporting; its outbound remote calls are what get dropped.
function bypass.preserve_client_manager()
    local player_scripts = local_player:FindFirstChild("PlayerScripts");
    local client_actor = player_scripts and player_scripts:FindFirstChild("ClientActor");
    local client_manager = client_actor and client_actor:FindFirstChild("ClientManager");

    if not client_manager then
        return false, "ClientManager not present";
    end;

    if not client_manager.Enabled then
        -- Something else in this session already killed it. Put it back so the
        -- module's own liveness expectations hold.
        client_manager.Enabled = true;
    end;

    return true;
end;

-- ── tag namespace ──────────────────────────────────────────────────────────
-- Static tag strings are a signature list. Use these two instead of literal
-- tags whose only job is to mark PR-owned objects.
-- NOTE: game-owned whitelist tags ("AllowedBM" and similar) must keep their
-- exact spelling or the game stops honouring them — those are handled at the
-- call site, not here.
function bypass.mint_tag(kind)
    return string.format("pr_%s_%s_%x", bypass.salt, kind, math.random(0, 0xFFFFFF));
end;

function bypass.retire_tag(tag)
    local CollectionService = game:GetService("CollectionService");
    for _, tagged in next, CollectionService:GetTagged(tag) do
        pcall(CollectionService.RemoveTag, CollectionService, tagged, tag);
    end;
end;

-- ── plausibility envelopes ─────────────────────────────────────────────────
-- The physics exploits currently write values no real character can reach:
-- mob_ai_breaker sets Velocity to Vector3.new(0, -9e9, 0), ap_breaker pushes
-- thousands of animation loads per second. Both are server-visible. These
-- clamps keep the same effect inside a range a real client could produce.
bypass.plausibility = {
    max_velocity      = 1024,   -- studs/sec, above Deepwoken terminal velocity
    max_anim_per_sec  = 8,
};

function bypass.clamp_velocity(vector)
    if typeof(vector) ~= "Vector3" then
        return vector;
    end;
    local limit = bypass.plausibility.max_velocity;
    if vector.Magnitude <= limit then
        return vector;
    end;
    return vector.Unit * limit;
end;

-- ── install ────────────────────────────────────────────────────────────────
function bypass.install()
    bypass.verify_report = {};

    -- Attribution is opt-in. With it off, only remotes positively identified as
    -- report channels are dropped, which cannot eat game traffic.
    bypass.attribution = getgenv().PR_ATTRIBUTION == true;
    bypass.verify_report.attribution = bypass.attribution;

    step("preserve_client_manager", bypass.preserve_client_manager);

    -- Resolve KeyHandler first: its registry is the authoritative list of
    -- "these are the game's own action remotes". Any remote in it must never be
    -- dropped, whatever the name/Changed heuristics say.
    local key_handler = step("resolve_keyhandler", bypass.resolve_keyhandler);
    bypass.key_handler = key_handler;
    if key_handler then
        getgenv().PR_key_handler = key_handler;
    end;

    local blocked = bypass.collect_report_remotes();

    -- A live read showed two remotes in both the registry and the block list
    -- (they carry a Changed listener, so collect_by_connections matched them).
    -- Dropping those swallows real input — block, parry, feint all route
    -- through these. The registry wins.
    local excluded = 0;
    if key_handler and typeof(key_handler.remotes) == "table" then
        for _, remote in next, key_handler.remotes do
            if blocked[remote] then
                blocked[remote] = nil;
                excluded = excluded + 1;
            end;
        end;
    end;
    bypass.verify_report.excluded_game_remotes = excluded;

    -- Rebuild the diagnostic list so it reflects what is actually filtered.
    -- (collect_report_remotes fills it before the exclusion above.)
    local listed = {};
    for remote, reason in next, blocked do
        local name = (typeof(remote) == "Instance") and remote.Name or tostring(remote);
        listed[#listed + 1] = string.format("%s (%s)", name, tostring(reason));
    end;
    table.sort(listed);
    bypass.blocked_list = listed;

    local blocked_count = 0;
    for _ in next, blocked do
        blocked_count = blocked_count + 1;
    end;

    bypass.verify_report.report_remotes = blocked_count;

    if blocked_count > 0 then
        step("install_report_filter", bypass.install_report_filter, blocked);
    else
        -- No kick. Nothing matched the heuristics this build; leave the
        -- namecall chain untouched and carry on.
        bypass.log("no report remotes identified; filter not installed");
    end;

    bypass.log("install complete", bypass.verify_report);
    return bypass.verify_report;
end;

return bypass;
