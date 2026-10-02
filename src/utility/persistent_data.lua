local storage_service = identifyexecutor() == "Synapse Z" and services.MemStorageService or services.MemStorageService;

if identifyexecutor() == "Synapse Z" then
    local existing_data = storage_service:GetItem("persistent_data");
    if not existing_data or #existing_data <= 0 then
        storage_service:SetItem("persistent_data", "{}");
    end
elseif not storage_service:HasItem("persistent_data") then
    storage_service:SetItem("persistent_data", "{}");
end

local persistent_data = {} do
    persistent_data.__index = persistent_data;
    persistent_data.current = storage_service:GetItem("persistent_data") or "{}";

    function persistent_data:wipe()
        self.current = "{}";
        storage_service:SetItem("persistent_data", self.current);
    end

    -- Decode, garantendo SEMPRE una tabella.
    --
    -- JSONDecode restituisce nil quando il testo non e' JSON valido, e il
    -- salvataggio puo' corrompersi (scrittura interrotta, valore vuoto, dato
    -- di una versione precedente). Prima ogni funzione usava il risultato
    -- direttamente:
    --
    --     JSONDecode(self.current)[key]
    --
    -- quindi un salvataggio corrotto diventava "attempt to index nil with ..."
    -- a OGNI chiamata. E get viene chiamato di continuo dal ciclo
    -- dell'automazione, quindi un solo valore corrotto produceva errori su un
    -- percorso caldo -- osservato dal vivo:
    --     ":60513: attempt to index nil with 'auto_ferryman'"
    --
    -- Un salvataggio illeggibile adesso viene azzerato invece di rompere tutto.
    local function decode()
        local ok, decoded = pcall(services.HttpService.JSONDecode, services.HttpService, persistent_data.current);
        if ok and type(decoded) == "table" then
            return decoded;
        end;

        persistent_data.current = "{}";
        pcall(function() storage_service:SetItem("persistent_data", "{}") end);
        return {};
    end;

    function persistent_data:set(key, value)
        local decoded = decode();
        decoded[key] = value;
        
        self.current = services.HttpService:JSONEncode(decoded);
        storage_service:SetItem("persistent_data", self.current);
    end;

    function persistent_data:remove(key)
        local decoded = decode();
        decoded[key] = nil;
        self.current = services.HttpService:JSONEncode(decoded);
        storage_service:SetItem("persistent_data", self.current);
    end;

    function persistent_data:get(key, or_default)
        return decode()[key] or or_default
    end;
end;

return persistent_data