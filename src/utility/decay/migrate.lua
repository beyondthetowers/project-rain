--[[
    src/utility/decay/migrate.lua

    DECAY shipped previously as "Project Rain". Every install from before the
    rename still has a `Project Rain/` folder holding the user's configs,
    fflags, asset cache, logs and script state. A straight folder rename would
    present everyone with a blank slate.

    This copies the legacy tree forward once, and leaves the old folder in place
    untouched so a rollback still works. Runs from luarmor_init_script before
    src/init.lua creates any folder, because init.lua's `if not isfolder(...)
    then makefolder(...) end` checks would otherwise create empty directories
    first and the migration would skip.

    Note: `ProjectRainRewrite` handled elsewhere in src/ui/config_converter.lua
    is an even older layout and is deliberately not touched here.
]]

local migrate = {};

local LEGACY  = "Project Rain";
local CURRENT = "Decay";

local function normalize(path)
    return (path:gsub("\\", "/"));
end;

local function copy_tree(source, destination)
    if not isfolder(destination) then
        local ok = pcall(makefolder, destination);
        if not ok then
            return 0;
        end;
    end;

    local ok, entries = pcall(listfiles, source);
    if not ok or type(entries) ~= "table" then
        return 0;
    end;

    local prefix = normalize(source) .. "/";
    local copied = 0;

    for _, entry in next, entries do
        local normalized = normalize(entry);

        -- listfiles may hand back an absolute path; fall back to the leaf.
        local relative;
        if normalized:sub(1, #prefix) == prefix then
            relative = normalized:sub(#prefix + 1);
        else
            relative = normalized:match("([^/]+)$") or "";
        end;

        if relative ~= "" then
            local target = destination .. "/" .. relative;

            if isfolder(entry) then
                copied = copied + copy_tree(entry, target);
            elseif isfile(entry) then
                local read_ok, contents = pcall(readfile, entry);
                if read_ok and contents then
                    local write_ok = pcall(writefile, target, contents);
                    if write_ok then
                        copied = copied + 1;
                    end;
                end;
            end;
        end;
    end;

    return copied;
end;

local MARKER = CURRENT .. "/migrated_from_legacy.txt";

local function count_files(path)
    local ok, entries = pcall(listfiles, path);
    if not ok or type(entries) ~= "table" then
        return 0;
    end;

    local n = 0;
    for _, entry in next, entries do
        if isfile(entry) then
            n = n + 1;
        end;
    end;

    return n;
end;

-- Returns the number of files copied. Zero means "nothing to do", which is the
-- normal case on a fresh install and on every run after the first.
function migrate.run()
    local ok, result = pcall(function()
        if not isfolder(LEGACY) then
            return 0;                                  -- nothing to migrate from
        end;
        if isfile(MARKER) then
            return 0;                                  -- already done, once and for all
        end;

        -- Was: `if isfolder(CURRENT) then return 0 end`. That latch was wrong.
        -- A run that died partway leaves Decay/ present but partial, and the
        -- migration would then never fire again — stranding the user's configs
        -- in the old folder permanently with no message. Only treat the
        -- destination as done when it already holds at least as many files as
        -- the source.
        if isfolder(CURRENT) then
            local legacy_count = count_files(LEGACY);
            local current_count = count_files(CURRENT);
            if legacy_count > 0 and current_count >= legacy_count then
                return 0;
            end;
        end;

        local copied = copy_tree(LEGACY, CURRENT);

        -- Written on every attempt, so a partial destination is retried on the
        -- next run rather than being treated as finished.
        pcall(writefile, MARKER, string.format(
            "copied %d file(s) from '%s'\n%s\n",
            copied, LEGACY, os.date("%Y-%m-%d %H:%M:%S")
        ));

        return copied;
    end);

    if not ok then
        warn("[decay] migration failed:", result);
        return 0;
    end;

    if result and result > 0 then
        print(string.format("[decay] migrated %d file(s) from '%s' to '%s'", result, LEGACY, CURRENT));
    end;

    return result or 0;
end;

return migrate;
