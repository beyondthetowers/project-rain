local fflags = {} do
    fflags.current = isfile("Decay/fflags.txt") and readfile("Decay/fflags.txt") or "{}";

    function fflags:get_main()
        if not self.cached then
            self.cached = services.HttpService:JSONDecode(self.current or "{}");
        end
        return self.cached    
end

    function fflags:get(flag)
        return self:get_main()[flag]    
end;

    function fflags:set(flag, value)
        local decoded = services.HttpService:JSONDecode(self.current);
        decoded[flag] = value;
        self.current = services.HttpService:JSONEncode(decoded);
        self.cached = services.HttpService:JSONDecode(self.current or "{}");
        writefile("Decay/fflags.txt", self.current);
    end;
end

return fflags 