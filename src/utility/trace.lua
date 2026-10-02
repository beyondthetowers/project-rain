-- Registratore di eventi su file, per capire cosa fa l'auto-parry quando rompe.
--
-- Scrive in Frutiger/logs/trace.txt, che si legge direttamente dal disco: non
-- serve iniettare niente per leggere, e non passa dalla console, quindi non
-- puo' causare il lag che il logger dell'interfaccia causava.
--
-- Si attiva SOLO se esiste il file Frutiger/logs/TRACE_ON.txt, controllato una
-- volta al caricamento. Cosi':
--   * per accenderlo basta creare quel file (io lo faccio da fuori)
--   * se non c'e', questo modulo non costa praticamente niente
--   * non resta acceso per sbaglio in una build normale
--
-- Scrittura a blocchi: si accumula e si scrive al massimo una volta al secondo.
-- Un writefile per riga sarebbe esso stesso un problema di prestazioni.

local trace = {};

local FLAG_PATH = "Frutiger/logs/TRACE_ON.txt";
local PATH = "Frutiger/logs/trace.txt";
local MAX_BYTES = 160000;
local FLUSH_EVERY = 1.0;

local enabled = false;
pcall(function()
    enabled = isfile(FLAG_PATH) == true;
end);

local buffer = {};
local last_flush = 0;
local started = tick();

function trace.enabled()
    return enabled;
end;

function trace.write(tag, fmt, ...)
    if not enabled then
        return;
    end;

    local ok, line = pcall(string.format, "[%7.2f] %-7s " .. fmt .. "\n", tick() - started, tag, ...);
    if not ok then
        return;
    end;

    buffer[#buffer + 1] = line;

    local now = tick();
    if now - last_flush < FLUSH_EVERY then
        return;
    end;
    last_flush = now;

    local payload = table.concat(buffer);
    buffer = {};

    pcall(function()
        local existing = isfile(PATH) and readfile(PATH) or "";
        if #existing > MAX_BYTES then
            -- Tiene solo la coda: gli eventi recenti sono quelli che servono.
            existing = existing:sub(-math.floor(MAX_BYTES / 2));
        end;
        writefile(PATH, existing .. payload);
    end);
end;

-- Una nota all'avvio, per sapere che il file e' di questa sessione.
trace.write("BOOT", "trace attivo");

return trace;
