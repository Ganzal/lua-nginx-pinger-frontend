---
--  Точка входа в сценарий Pinger-Frontend
--
--  Директива nginx: content_by_lua_file
--
--  @since 2016-01-31
--

local pinger_frontend_class = require "pinger-frontend"
local pinger_frontend = pinger_frontend_class:new()

if not pinger_frontend then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR

    if 'HEAD' ~= ngx.req.get_method() then
      ngx.header.content_type = 'text/plain'
      ngx.say('Pinger-Frontend not ready...')
    end

    return ngx.exit(ngx.OK)
end

pinger_frontend:main()

--- eof
