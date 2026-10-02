
local luarmor_finish_tick = tick();
require("@src/luarmor_init_script");

if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded();
end;

if getgenv().metamorphosis then
    pcall(function() 
        getgenv().metamorphosis(); 
    end)
end;


local function handle_dev_tools()
    local success, dev_tools_settings = pcall(game.HttpGet, game, "http://localhost:441/dev-tools");
    if not success or not dev_tools_settings then
        return    
end;
    
    local success_json, json_decoded = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), dev_tools_settings);
    if not success_json or not json_decoded then
        return    
end;

    getgenv().dev_tools_data = json_decoded;
     
    if json_decoded["queue-on-teleport"] then
        queue_on_teleport([[
            if getgenv().queued then return; end
            getgenv().queued = true;
            
            xpcall(function()
                local success, dev_script = pcall(game.HttpGet, game, "http://localhost:3067/dev-loader");
                if not success then
                    return print("failed to get loader, run dev-tools.js if not loaded:", dev_script);
                end;
            
                local func, err = loadstring(dev_script);
                if not func then
                    return print("failed to load loader:", err); 
                end;
                xpcall(func, warn);
            end, warn);
        ]])
    end;
end;
task.spawn(xpcall, handle_dev_tools, warn);

env = getgenv();
if not LPH_OBFUSCATED then
    require(LPH_ENCSTR("@src/utility/librarys/luraph_sdk"));
end; 

xpcall(function()
    if not isfolder("Frutiger") then
        makefolder("Frutiger");
    end;
    
    if not isfolder("Frutiger/Assets") then
        makefolder("Frutiger/Assets");
    end;

    if not isfolder("Frutiger/Assets/Hit Sounds") then
        makefolder("Frutiger/Assets/Hit Sounds");
    end;

    if not isfolder("Frutiger/Assets/Parry Sounds") then
        makefolder("Frutiger/Assets/Parry Sounds");
    end;

    if not isfolder("Frutiger/Fonts") then
        makefolder("Frutiger/Fonts");
    end;

    if not isfolder("Frutiger/Deepwoken-Config") then
        makefolder("Frutiger/Deepwoken-Config");
    end;

    if not isfolder("Frutiger/Deepwoken-Config/CustomGlobalOrnaments") then
        makefolder("Frutiger/Deepwoken-Config/CustomGlobalOrnaments");
    end;

    if not isfolder("Frutiger/Deepwoken-Config/CustomRaces") then
        makefolder("Frutiger/Deepwoken-Config/CustomRaces");
    end;

    if not isfolder("Frutiger/Deepwoken-Config/Preferences") then
        makefolder("Frutiger/Deepwoken-Config/Preferences");
    end;

    if not isfolder("Frutiger/Deepwoken-Config/CustomEnchantments") then
        makefolder("Frutiger/Deepwoken-Config/CustomEnchantments");
    end;

    if not isfile("Frutiger/script_state") then
        writefile("Frutiger/script_state", game:GetService("HttpService"):JSONEncode({
            ["last_executed"] = tick(),
            ["last_executed_version"] = LPH_ENCSTR("__BUILD__"),
            ["build_id"] = game:GetService("HttpService"):GenerateGUID(false)
        }));
    end;
end, warn);

if env.aztup then
    if env.Markers then   
        for _, marker in env.Markers:get() do
            marker:Destroy(); 
        end;
        table.clear(env.Markers._marked_instances);
        table.clear(env.Markers);
        getgenv().Markers = nil;
    end;

    xpcall(function()
        env.aztup:detach();
    end, warn);
    env.aztup = nil;
end;

env.aztup = {
    detach = function(self)
        if self.maid then
            self.maid:do_cleaning()
        end;
        
        if self.features then
            for _, feature in pairs(self.features) do
                xpcall(function()
                    feature:disable();
                end, function(...) 
                    warn(string.format("[detach %s]", feature.id or "none"), ...);
                end);
            end; 
        end;
 
        if self.ui then
            self.ui:Unload();
        end;
    end,
    features = {},
    flags = {}, 
    farms = {},
    tabs = {},
};

local hasnt_accepted_tos = not isfile("Frutiger/tos_accepted_82126_0822UTC0.txt");

env.persistent_data = require("@src/utility/persistent_data");
env.Logger = require(LPH_ENCSTR("@src/utility/logger"));   
aztup.automation = require(LPH_ENCSTR("@src/automation/loader"));
env.fflags = require("@src/utility/fflags");

if fflags:get("auto_load") and script_key then
    require("@src/utility/setup_auto_load");
end

if aztup.automation:should_auto_start() then
    local requests = services.ReplicatedStorage:WaitForChild("Requests");
    local start = requests:WaitForChild("StartMenu"):WaitForChild("Start")
    repeat
        start:FireServer()
        task.wait(0.5)
    until game:GetService("Players").LocalPlayer.Character;
    task.wait(1);
end;

local success, result = pcall(function()
    return require(LPH_ENCSTR("@src/features/hooking"))
end);

if not success or not result then 
    return game:GetService("Players").LocalPlayer:Kick("[frutiger] failed to hook, kicking to prevent bans\n" .. result)
end; 

do 
    LPH_NO_VIRTUALIZE(function()
        function decode_asset(asset)
            local decoded = services.EncodingService:Base64Decode(buffer.fromstring(asset));
            local decompress = services.EncodingService:DecompressBuffer(decoded, Enum.CompressionAlgorithm.Zstd);
            return buffer.tostring(decompress)        
end;
        
        task.spawn(pcall, function()  
            if not isfile("Frutiger/Assets/proximity.mp3") then
                writefile("Frutiger/Assets/proximity.mp3", decode_asset(inline_asset_b96("@assets/proximity.mp3")));
            end;

            if not isfile("Frutiger/Assets/Parry Sounds/Ultrakill Parry.mp3") then
                writefile("Frutiger/Assets/Parry Sounds/Ultrakill Parry.mp3", decode_asset(inline_asset_b96("@assets/Ultrakill Parry.mp3")));
            end;

            if not isfile("Frutiger/Assets/notification.mp3") then 
                writefile("Frutiger/Assets/notification.mp3", decode_asset(inline_asset_b96("@assets/notification.mp3")));
            end;

            if not isfile("Frutiger/Deepwoken-Config/GuiItself.rbxm") then
                writefile("Frutiger/Deepwoken-Config/GuiItself.rbxm", decode_asset(inline_asset_b96("@assets/DeepwokenMorphs/GuiItself.rbxm")));
            end;
        end)
        
        if not isfile("Frutiger/Fonts/Lexend.ttf") then 
            writefile("Frutiger/Fonts/Lexend.ttf", decode_asset(inline_asset_b96("@assets/lexend.ttf")));
        end; 

        if not isfile("Frutiger/Fonts/Lexend-Bold.ttf") then 
            writefile("Frutiger/Fonts/Lexend-Bold.ttf", decode_asset(inline_asset_b96("@assets/lexend-bold.ttf")));
        end; 

        if not isfile("Frutiger/Fonts/Lexend-Medium.ttf") then 
            writefile("Frutiger/Fonts/Lexend-Medium.ttf", decode_asset(inline_asset_b96("@assets/lexend-medium.ttf")));
        end; 
    end)(); 
end; 

lexend = require("@src/utility/custom_font");

user_service = require("@src/security/user_service");

if not LPH_OBFUSCATED then
    getgenv().user_service = user_service;
end;

if hasnt_accepted_tos then
    require(LPH_ENCSTR("@src/ui/tos"));
    
    if not isfile("Frutiger\\Deepwoken-Config\\settings\\default_conf.json") and not isfile("Frutiger/inquired_about_default_config.txt") and not isfile("Frutiger\\Deepwoken-Config\\settings\\autoload.txt") then
        writefile("Frutiger/inquired_about_default_config.txt", "true");
        require(LPH_ENCSTR("@src/ui/choice_frame")).set(nil,
            function()
	    	    local config_fetch_success, config_content = pcall(game.HttpGet, game, "https://files.frutiger/configs/premade.json");
                if config_fetch_success then
                    writefile("Frutiger\\Deepwoken-Config\\settings\\default_conf.json", config_content);
                    writefile("Frutiger\\Deepwoken-Config\\settings\\autoload.txt", "default_conf");
                end;
            end,
            function()
            end
        );
    end;

    task.wait(1.5);
end; 

if game.PlaceId == 4111023553 then 
    
    
    
    
    
    
    

    
    
    
    
    

    
    
    
    
    
    
    
    task.spawn(xpcall, function() 
        require("@src/main_menu/loader");
    end, warn)

    return true
end;

env.signal = require("@src/utility/signal");
loaded_signal = env.signal.new();
env.LOAD_START_TIME = tick();
aztup.silent_mode = isfile(LPH_ENCSTR("Frutiger/silent_mode_toggle"));
aztup.maid = require(("@src/utility/maid")).new(); 

if not aztup.ui then
    aztup.ui = require(("@src/utility/librarys/ui"));
end;

env.server_utility = require("@src/utility/deepwoken/servers");
env.local_player = require(("@src/utility/player-data"));
env.general = require(("@src/utility/deepwoken/general_utilitys"));
env.InstanceWatcher = require(("@src/utility/instancewatcher"));
env.BindableFunction = require(("@src/utility/bindablefunction"));
env.Markers = require(("@src/utility/markers")).new();
env.MarkedInstanceCreator = require(("@src/utility/markedinstancecreator"));
env.StateMachine = require(("@src/utility/statemachine"));
env.Tween = require(("@src/utility/deepwoken/safe_tween"));
env.EffectReplicatorHandler = require(("@src/utility/deepwoken/effect_replicator_handler"));
env.LoopUtil = require(("@src/utility/loop"));
env.scheduler = require("@src/utility/scheduler");
env.TargetFilter = require("@src/features/auto-parry/util/target-filter")
env.ab_builder = require("@src/features/auto-builder/auto_builder");
aztup.automation.initialize();

require(("@src/features/auto-parry/block-input-manager"))
require(("@src/features/loader")).initialize();
task.spawn(pcall, function() 
    require(LPH_ENCSTR("@src/features/auto-parry/handlers/animator-handler"));
end)
chance_store = require("@src/features/auto-parry/data/chance_store")
getgenv().chance_store = chance_store;
require(LPH_ENCSTR("@src/ui/ui")).initialize();

-- FRUTIGER theme: palette, fonts and the grain/scanline/vignette overlay. Runs
-- after the UI exists so the overlay can parent above Library.ScreenGui, and
-- spawn'd so a failure here can never take init down with it.
task.spawn(xpcall, function()
    require("@src/utility/frutiger/theme").apply();

    -- Native chrome: replaces the library's window frame, tab strip and search
    -- row with our own shell, and transplants the widget tree into it.
    --
    -- Supersedes the sidebar pass, which restyled the library's own strip in
    -- place. sidebar.lua is left on disk but no longer wired -- undo this and
    -- re-add it if chrome ever misbehaves.
    require("@src/utility/frutiger/chrome").apply();

    -- Glass: translucency, gradient and edge lighting on the shell, plus panel
    -- depth. Runs after chrome so the shell exists to work on.
    require("@src/utility/frutiger/glass").apply();

    -- Dress: applies the material kit across the library tree. Dividers soft,
    -- cards glass, list spacing loosened. Appearance only -- no logic touched.
    require("@src/utility/frutiger/dress").apply();

    -- Rounds every visible element, and re-scans for the ones the library
    -- builds lazily (dropdown options, tab contents on first visit). Runs after
    -- chrome so the new shell gets corners too.
    local round = require("@src/utility/frutiger/round");
    round.apply();
    round.start_watchdog();

    -- Hover inversion. Runs after round so it can also catch the corners the
    -- library builds late, and re-scans for lazily created rows.
    local hover = require("@src/utility/frutiger/hover");
    hover.apply();
    hover.start_watchdog();

    -- HUD furniture: the keybind list, moved and stripped.
    require("@src/utility/frutiger/chrome").restyle_keybinds();
end, function(err)
    warn("[frutiger] theme failed:", err);
end);

require("@src/features/visuals/player_esp")();
require("@src/features/visuals/base_esp")();

if not fflags:get("dont_notify_on_first_exec") and aztup.silent_mode then
    if not persistent_data:get("has_executed_before") then
        messagebox("You have 'Silent Mode' enabled, Which means you wont see the UI until you open it with the keybind & have extra anti PC check features, If you would like to disable this, Go to UI settings and disable it, This notification is disablable in the fast flags area of UI", "Frutiger", 0)
    end;
    
    persistent_data:set("has_executed_before", true); 
end

shared.unloaded = false;
Library:OnUnload(function()
    if shared.unloaded then return end
    shared.unloaded = true;

    if env.aztup then
        if env.Markers then   
            for _, marker in env.Markers:get() do
                marker:Destroy();
            end;
            table.clear(env.Markers._marked_instances);
            table.clear(env.Markers);
            getgenv().Markers = nil;
        end;
    
        env.aztup:detach();
        env.aztup = nil;
    end;
    
    Library.Unloaded = true
end)
 
if not aztup.silent_mode then
    Logger.log("Not in silent mode.");
end;

if luarmor_preload_time_debug or LPH_OBFUSCATED and luarmor_preload_time then
    Logger.log(string.format("Loaded @ %.2fs, LRM %.2fs.", tick() - env.LOAD_START_TIME, luarmor_finish_tick - (luarmor_preload_time or luarmor_preload_time_debug)));
else
    Logger.log(string.format("Loaded in %.2fs.", tick() - env.LOAD_START_TIME));
end;

loaded_signal:fire(); 

aztup.automation:start(); 