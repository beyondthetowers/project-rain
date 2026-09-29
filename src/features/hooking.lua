


local bypass = require("@src/security/bypass");

if game.PlaceId == 4111023553 then return true end

Logger.log_for_devs("beginning anticheat bypass...");

task.spawn(pcall, function()
    

    local client_manager = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientActor"):WaitForChild("ClientManager")

    -- Deliberately NOT set to false. Disabling the module is a one-line
    -- signature, and the "error check (1)" numbering implies sibling checks
    -- were stripped before release. The module stays alive; its outbound
    -- reports are intercepted in __namecall instead.
    bypass.preserve_client_manager();
    if not client_manager.Enabled then
        Logger.log_for_devs("[hooking] client manager was disabled elsewhere; re-enabled");
    end;
    Logger.log_for_devs("client manager preserved (report filter owns the drop)");
end);
local pi = (function() 
    return 0.125 + tonumber(STR_TBL_SF_INVOKE("3"))
end)();
-- heaven_key used to be a compile-time constant folded out of the game's
-- builder and matched against tbl[9] during a getgc() scan. Every game update
-- re-rolled it, so the scan silently stopped matching, KeyHandler never
-- resolved, and init.lua then kicked the player. Resolution now lives in
-- bypass.resolve_keyhandler() and works off the table's shape.
local KeyHandlerClass = {} do
    KeyHandlerClass.__index = KeyHandlerClass;
    
    KeyHandlerClass[STR_TBL_SF_INVOKE("get_key_internal")] = function(self, remote)
        if self.cache[remote] then
            return self[STR_TBL_SF_INVOKE("remotes")][self.cache[remote] ]        
end

        if not self[STR_TBL_SF_INVOKE("remotes")] or not self[STR_TBL_SF_INVOKE("enc_f")] then
            repeat task.wait() until self[STR_TBL_SF_INVOKE("remotes")] and self[STR_TBL_SF_INVOKE("enc_f")];
        end

        local encoded_remote = self.cache[remote] or self[STR_TBL_SF_INVOKE("enc_f")](remote); 
        self.cache[remote] = encoded_remote;

        return encoded_remote and self[STR_TBL_SF_INVOKE("remotes")][encoded_remote] or nil        
        
        
        
    
end;

    KeyHandlerClass[STR_TBL_SF_INVOKE("get_key")] = function(self, remote)
        local success, res = pcall(KeyHandlerClass[STR_TBL_SF_INVOKE("get_key_internal")], self, remote);
        if success then
            return res        
else
            
            return        
end
    end

    KeyHandlerClass[STR_TBL_SF_INVOKE("get_cache")] = function(self, remote)
        local encoded_remote = self.cache[remote];
        if not encoded_remote then
            return nil        
end

        return self[STR_TBL_SF_INVOKE("remotes")][encoded_remote]    
end;

    KeyHandlerClass[STR_TBL_SF_INVOKE("handle_gk")] = function(self)
        -- Shape-based, retrying: ReplicatedStorage.Modules may not have
        -- replicated yet on a fresh join.
        local resolved;
        local attempts = 0;
        repeat
            resolved = bypass.resolve_keyhandler();
            if resolved then break end
            attempts += 1;
            task.wait(attempts / 20);
        until resolved or attempts > 40;

        if not resolved then
            -- No kick. KeyHandler-dependent features stay inert.
            Logger.log_for_devs("[kh] could not resolve KeyHandler; continuing without it");
            return;
        end;

        self[STR_TBL_SF_INVOKE("remotes")] = resolved.remotes;
        self[STR_TBL_SF_INVOKE("enc_f")]   = resolved.encoder;

        if shared.b then return Logger.log_for_devs("[kh] already bypassed this session")end
        Logger.log_for_devs("[kh] grabbed remotes & enc_f");

        
        local key_handler_module = require(services.ReplicatedStorage:WaitForChild(STR_TBL_SF_INVOKE("Modules")):WaitForChild(STR_TBL_SF_INVOKE("ClientManager")):WaitForChild(STR_TBL_SF_INVOKE("KeyHandler")));
        local generate_guid = game:GetService("HttpService").GenerateGUID;

        local L_231 = function()
            local L_223 = generate_guid(game:GetService("HttpService"), false):lower():gsub("[%-]*", "");
            local L_224 = math.random(8, 16);
            local L_225 = L_223:sub(1, L_224);
            local L_226 = false;
            for L_227 = 1, L_224, 1 do
                local L_228 = L_225:sub(1, L_227 - 1);
                local L_229 = L_225:sub(L_227, L_227);
                local L_230 = L_225:sub(L_227 + 1);
                local n = tonumber(L_229)
                if n then
                    L_229 = string.char(103 + n);
                end;
                if L_227 == 1 or math.random(1, 6) == 1 and not L_226 and not (L_227 >= L_224) then
                    L_229 = L_229:upper();
                    L_226 = true;
                else
                    L_226 = false;
                end;
                L_225 = L_228 .. L_229 .. L_230;
            end;
            return (L_225:sub(1, L_224))        
end;

        local function create_key(remote)
            self[STR_TBL_SF_INVOKE("remotes")][self[STR_TBL_SF_INVOKE("enc_f")](remote.Name)] = remote;
            remote.Name = L_231();
        end

        local function get_key(remote)
            if typeof(remote) ~= "string" then
                return            
end

            return self[STR_TBL_SF_INVOKE("remotes")][self[STR_TBL_SF_INVOKE("enc_f")](remote)]        
end

        hookfunction(key_handler_module, function() 
            return {
                [1] = get_key,
                [2] = create_key,
                [3] = "made with <3 from uni, hon, temped, soggy!!!",
            }
        end)

        for _, tbl in getgc(true) do
            if typeof(tbl) ~= "table" then continue end
            if getrawmetatable(tbl) then continue end
            if #tbl ~= 2 then continue end
            if typeof(tbl[1]) ~= "function" or typeof(tbl[2]) ~= "function" then continue end

            local create = tbl[2];
            local get = tbl[1];

            if getinfo(get).source:find("KeyHandler") and getinfo(create).source:find("KeyHandler") then
                hookfunction(get, get_key);
                hookfunction(create, create_key);
                tbl[1] = get_key;
                tbl[2] = create_key; 
                break            
end 
        end

        
        shared.b = true;
    end; 

    function KeyHandlerClass.new()
        local self = setmetatable({}, KeyHandlerClass);
        self.cache = {};

        local start = tick();
        task.spawn(function()
            Logger.log_for_devs("[kh] starting bypass");
            self[STR_TBL_SF_INVOKE("handle_gk")](self);
            Logger.log_for_devs("[kh] finished");
            
        end); 

        return self    
end;
end;


local old_hmm = hookmetamethod;
local parallel_hooks_allowed = parallel_hooks_allowed;
local hookmetamethod = not parallel_hooks_allowed and function(t, method, hook)
    local old;

    -- The vanilla __namecall / __newindex slots hold C functions. Writing a
    -- bare Lua closure over them is a one-line detection:
    --     iscclosure(getrawmetatable(game).__namecall) --> false
    -- Route every handler through newcclosure so the slot keeps the calling
    -- convention the game expects.
    if type(newcclosure) == "function" then
        local wrapped = newcclosure(hook);
        if wrapped then
            hook = wrapped;
        end;
    end;

    local mt = getrawmetatable(t)
    setreadonly(mt, false);
    old = mt[method];
    mt[method] = hook;
    setreadonly(mt, true);

    return old
end or hookmetamethod;


getgenv().KeyHandler = KeyHandlerClass.new();


local requests = services.ReplicatedStorage:WaitForChild("Requests")
local ban_remotes = 0
local bans = {};

Logger.log_for_devs("[hooking] grabbing ban_remotes");

for _, remote in requests:GetChildren() do
    local changed_connections = #getconnections(remote.Changed)
    if changed_connections <= 0 then
        continue
    end

    ban_remotes = ban_remotes + 1
    bans[remote] = true
end

























-- Was: Kick("Failed to get BanRemote[3]") when this remote was absent. An
-- upstream rename turned that into a guaranteed kick on inject. Absence now
-- just means one signal is unavailable; the shape scan still runs.
local analytics_remote = requests:FindFirstChild("ReportGoogleAnalyticsEvent");
if analytics_remote then
    bans[analytics_remote] = true;
else
    Logger.log_for_devs("[hooking] ReportGoogleAnalyticsEvent absent; relying on shape scan");
end;

-- Was hookfunction(Instance.new("RemoteEvent").FireServer, ...). That is
-- visible to isfunctionhooked / getfunctionhash. The __namecall hook below
-- already intercepts FireServer, so the separate C-method hook is gone.
Logger.log_for_devs("[hooking] FireServer filtering folded into __namecall");

local animations = {} do
    for _, v in next, services.ReplicatedStorage:WaitForChild(STR_TBL_SF_INVOKE("Assets")):WaitForChild(STR_TBL_SF_INVOKE("Anims")):WaitForChild(STR_TBL_SF_INVOKE("Gestures")):GetChildren() do
        if v:FindFirstChild(STR_TBL_SF_INVOKE("Pack1")) or v:FindFirstChild(STR_TBL_SF_INVOKE("Pack2")) or v:FindFirstChild(STR_TBL_SF_INVOKE("MetalPromo")) then
            animations[v.Name] = v
        end
    end
end

Logger.log_for_devs("[hooking] hooking game_mt.__namecall");
local safety = require("@src/utility/safety");
local is_a = game.IsA;
local old_namecall;
old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod();
    if checkcaller() and method ~= "GetAttribute" or not aztup or not aztup.flags then
        if method ~= "FireServer" or self and self.Name ~= "DrawWeapon" then
            return old_namecall(self, ...)
        end;
    end;

    local flags = aztup.flags

    if method == "GetAttribute" and (flags.optimize_game or flags.streamer_mode) then
        local attr_name = ...;
        if flags.optimize_game and table.find({
            "SailLength",
            "ClientC1",
            "ClientCF"
        }, attr_name) then
            return        
elseif flags.streamer_mode then
            if attr_name == "FirstName" then
                return ""            
elseif attr_name == "CharacterName" then
                return ""            
elseif attr_name == "GuildColor" then
                return Color3.new(0.752941, 0.854902, 0.87451)            
elseif attr_name == "GuildEmblemA" or attr_name == "GuildEmblemB" then
                return 0            
end
        end;
    elseif method == "Raycast" then
        local _, _, params = ...;
        local caller = getcallingscript();

        if caller.Name == "ClientPhysics" and general and general.collision_utils and params == general.collision_utils.geomParams then
            return
        end;
    elseif method == "FindFirstChild" then
        local looking_for = ...;
        local caller = getcallingscript();

        if looking_for == "CharacterHandler" and caller.Name == "KeyHandler" then
            warn("CharacterHandler reparent attempt from KeyHandler");
            return coroutine.yield()        
end
    elseif method == "Create" and self == services.TweenService then
        local instance, info, data = ...;
        local new_args = {...};

        if instance == services.Lighting then
            if flags.no_fog and rawget(data, "FogEnd") then
                rawset(data, "FogEnd", nil);
            end

            if flags.full_bright and (rawget(data, "Brightness") or rawget(data, "Ambient")) then
                rawset(data, "Ambient", nil);
                rawset(data, "Brightness", nil);
            end

            new_args[3] = data;
        elseif is_a(instance, "Atmosphere") then
            if flags.no_fog and rawget(data, "Density") then
                rawset(data, "Density", 0);
            end

            new_args[3] = data;
        end;

        return old_namecall(self, unpack(new_args))    
elseif method == "FireServer" then
        -- folded in from the removed UnreliableRemoteEvent hookfunction
        if aztup and aztup.flags and aztup.flags.no_one_bit
            and aztup.features.no_one_bit and aztup.features.no_one_bit.removed
            and self == aztup.features.no_one_bit.server_swim
        then
            return
        end;

        if flags.block_input and self then

            if BlockInputManager:should_block_input() then
                if self == KeyHandler:get_cache(STR_TBL_SF_INVOKE("OffhandAttack")) and aztup_options.blocked_safe_input_user_moves.Value.M2s then
                    return
                end
                if self == KeyHandler:get_cache(STR_TBL_SF_INVOKE("LeftClick")) and aztup_options.blocked_safe_input_user_moves.Value.M1s then
                    return
                end
            end

            local critical_click = KeyHandler:get_cache("CriticalClick");
            if critical_click and self == critical_click and BlockInputManager:should_block_input() and aztup_options.blocked_safe_input_user_moves.Value.Criticals then
                return            
end;
        end
        
        if flags.give_animation_gamepass and self then
            local anim = ...;
            if self.Name == "Gesture" and animations[anim] then
                task.spawn(function()  
                    local fake_anim = local_player.humanoid:LoadAnimation(animations[anim]);
                    local listener;
                    listener = local_player.humanoid.AnimationPlayed:Connect(function(animation_track)
                        if animation_track.Animation.AnimationId == "rbxassetid://6291247414" then
                            animation_track:Stop();
                            fake_anim:Play();
                            
                            local_player.humanoid:GetPropertyChangedSignal("MoveDirection"):Once(function()
                                fake_anim:Stop();
                                listener:Disconnect();
                            end);
                        end
                    end);
                end)

                return old_namecall(self, "Thinking")            
end
        end

        if self.Name == "ClientEffectBatch" then
            return        
end;

        if self.Name == "ActivateMantra" and local_player and local_player.tracker then
            local mantra = ...;
            task.defer(function()
                local_player.tracker:activate_request(mantra);
            end);
        end

        if self.Name == "DrawWeapon" and local_player and local_player.tracker then
            local hold = ...;
            task.defer(function()
                local_player.tracker.last_equip_call = hold;
            end);
        end;

        if self.Name == "UpdateMouse" and flags.silent_aim then
            return        
end;

        if aztup.flags.fall_multiplier and self == aztup.features.fall_multiplier.fall_remote then
            if aztup.flags.only_near_players then
                local players_are_near = false;
                for _, player in services.Players.GetPlayers(services.Players) do
                    if player == local_player.instance then continue end
                    if not player.Character then continue end
                    local pivot = player.Character.GetPivot(player.Character);
                    if not pivot then continue end

                    local dist = (local_player.root_part.Position - pivot.Position).Magnitude
                    if dist <= 550 then
                        players_are_near = true;
                    end
                end

                if not players_are_near then return end
            end

            local first_argument = ...;
            if aztup.flags.only_minimum_fall_dmg and first_argument >= 21 then
                local arguments = {...};
                arguments[1] = 20 + math.random();

                return old_namecall(self, unpack(arguments))            
end
        end
    end;

    if bans[self] then
        -- Return nil rather than yielding. A yield never returns to the
        -- anti-cheat's caller, which is itself observable; nil is exactly what
        -- a successful FireServer returns.
        return
    end

    return old_namecall(self, ...)
end)

Logger.log_for_devs("[hooking] hooking game_mt.__newindex");

if isfunctionhooked(getrawmetatable(game).__newindex) then
    restorefunction(getrawmetatable(game).__newindex);
end

local old_newindex;
old_newindex = hookmetamethod(game, "__newindex", (function(self, key, value, ...)
    if checkcaller() or not (key == "Ambient" or key == "Velocity" or key == "Text" or key == "ActiveController" or key == "WalkSpeed") then
        return old_newindex(self, key, value, ...)
    elseif aztup then
        local flags = aztup.flags;
        if flags.full_bright and self == services.Lighting then
            local level = 255 * (aztup.flags.fullbright_intensity / 100);
            return old_newindex(self, key, key == "Ambient" and Color3.fromRGB(level,level,level) or value)        
elseif flags.mob_ai_breaker and key == "Velocity" then
            if value.Magnitude < 0.2 then
                return            
end;
        elseif flags.streamer_mode and key == "Text" and (self.Name == "Character" or self.Name == "Slot") and self.Parent.Name == "CharacterInfo" then
            if self.Name == "Character" then
                return old_newindex(self, key, "", ...)            
else
                value = value:gsub(services.Players.LocalPlayer.UserId, "0");
                return old_newindex(self, key, value, ...)            
end
        elseif 
            (flags.fly or flags.noclip)
            and key == "ActiveController"
            and self.Parent == local_player.character
        then
            local airController = self.Parent:FindFirstChild("AirController")

            return old_newindex(self, key, airController or value)
        elseif  
            flags.multiply_s 
            and key == "WalkSpeed"
            and (function() 
                local caller = getcallingscript();
                return caller and caller.Name == "EffectsClient"
            end)()
        then
            local mult = aztup.features.multiply_s;
            mult = mult and mult.speed_mult or 0;
            mult /= 100;
            mult += 1;
            return old_newindex(self, key, mult and value and value * mult or value)        
end
        
    end;

    return old_newindex(self, key, value, ...)
end))

-- Was hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, ...).
-- Its two checks (blocked input, no_one_bit) now live in the __namecall
-- FireServer branch.
Logger.log_for_devs("[hooking] unreliable remote filtering folded into __namecall");

-- Was hookfunction(tostring, ...) keyed on the sentinel
-- "EEKEWAEJIWAJDOIWAJDIOJAWDIOJAWODJOAIW", which kicked the player with
-- "saturn (trapped-ts)" on match. Both the sentinel and the reason string are
-- public now, and isfunctionhooked(tostring) is a one-liner for the other
-- side. The hook is removed; nothing in the tree depends on it.

env.unhooked_newindex = old_newindex;
env.unhooked_namecall = old_namecall;

task.spawn(function() 
    Logger.log_for_devs("[hooking] hooking camera popper");

    local old_popper;
    old_popper = hookfunction(require(services.StarterPlayer:WaitForChild("PlayerModule"):WaitForChild("CameraModule"):WaitForChild("ZoomController"):WaitForChild("Popper")), function(...) 
        return (aztup and (aztup.flags.noclip or aztup.flags.noclip_camera)) and math.huge or old_popper(...)    
end);
end);

Logger.log_for_devs("[hooking] finished...");

-- Constant-free report filter + KeyHandler resolution.
task.spawn(function()
    local ok, report = pcall(bypass.install);
    if not ok then
        Logger.log_for_devs("[hooking] bypass.install failed", report);
    end;
end);

return true