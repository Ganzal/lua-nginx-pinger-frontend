---
-- Entry to Pinger-Host-Status.
--
-- Configuration directive: content_by_lua_file.
--
-- Package:     lua-nginx-pinger-frontend
-- Subpackage:  host-status
--
-- Copyright (c) 2016, Sergey D. Ivanov <me@dev.ganzal.com>
--
-- License: MIT License (see LICENSE file).
--


---
-- Checking of HTTP-Method.
--
local http_method = ngx.req.get_method()

if 'HEAD' ~= http_method and 'GET' ~= http_method then
  ---
  -- Block request.
  --
  ngx.header.content_type = 'text/plain'
  ngx.status = ngx.HTTP_NOT_ALLOWED
  ngx.say('Only GET,HEAD allowed')
  return ngx.exit(ngx.OK)
end
--


---
-- Attempting to load Pinger-Host-Status class.
--
local pinger_host_status_class = require "/usr/share/com-ganzal/lua-nginx-pinger-frontend/pinger-host-status-class"
local pinger_host_status = pinger_host_status_class:new()

if not pinger_host_status then
  ---
  -- Oooops.
  --
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
  if 'HEAD' ~= ngx.req.get_method() then
    ngx.header.content_type = 'text/plain'
    ngx.say('Pinger-Host-Status not ready...')
  end

  return ngx.exit(ngx.OK)
end
--


---
-- Preceed request.
--
pinger_host_status:main()
--


--- eof
