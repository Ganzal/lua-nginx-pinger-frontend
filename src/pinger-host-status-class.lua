---
-- Pinger-Host-Status - front-end to Pinger Service.
--
-- Get Host-Label from Request URI, fetch assocciated
-- data from Redis, response with some HTTP-Status.
--
-- Package:     lua-nginx-pinger-frontend
-- Subpackage:  host-status
--
-- Copyright (c) 2016, Sergey D. Ivanov <me@dev.ganzal.com>
--
-- License: MIT License (see LICENSE file).
--


---
-- Dependencies.
--
local resty_redis = require "resty.redis"
local resty_string = require "resty.string"
local bit = require "bit"
local debug = require "debug"
--


---
-- Lua-class magick.
--
local _M = {}
_M.__index = _M
_M._VERSION = '0.1.1'
local mt = { __index = _M }
--

-- -----------------------------------------------------------------------------

---
-- Constructor of Pinger-Host-Status.
--
function _M.new ()
    local self = setmetatable({}, mt)

    -- HTTP-Method.
    self.http_method = ngx.req.get_method()

    if 'HEAD' ~= ngx.req.get_method() then
      ngx.header.content_type = 'text/plain'
    end

    -- Redis connection.
    self.redis = nil

    ---
    -- Configurable variables.
    --
    self.redis_host = ngx.var.pinger_redis_host or '127.0.0.1'
    self.redis_port = tonumber(ngx.var.pinger_redis_port) or 6379
    self.redis_sock = ngx.var.pinger_redis_sock or false
    self.redis_namespace = ngx.var.pinger_redis_namespace or 'pinger'
    self.redis_database = tonumber(ngx.var.pinger_redis_database) or 0
    self.uri_regexp = ngx.var.pinger_uri_regexp or '/([^/]+)/'
    --

    return self
end
-- // function _M.new ()

-- -----------------------------------------------------------------------------

---
-- Initialize and return connection to Redis Server.
--
function _M.get_redis_connection (self)
  if self.redis then
    ---
    -- Return connection if it ready.
    --
    return self.redis
  end

  local ok, err = nil

  ---
  -- New instance.
  --
  local redis = resty_redis:new()

  if not redis then
    if 'HEAD' ~= self.http_method then
      ngx.say('redis:new() failed: ', err)
    end

    return ngx.exit(ngx.OK)
  end

  redis:set_timeout(1000)

  ---
  -- Attempt to connect.
  --
  if self.redis_sock then
    ok, err = redis:connect(self.redis_sock)
  else
    ok, err = redis:connect(self.redis_host, self.redis_port)
  end

  if not ok then
    ---
    -- Fatal error.
    --
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    if 'HEAD' ~= self.http_method then
      ngx.say('redis:connect() failed:', err)
    end

    return ngx.exit(ngx.OK)
  end
  --

  ---
  -- Attempt to select database by index.
  --
  ok, err = redis:select(self.redis_database)

  if not ok then
    ---
    -- Fatal error.
    --
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    if 'HEAD' ~= self.http_method then
      ngx.say('redis:select() failed:', err)
    end

    return ngx.exit(ngx.OK)
  end
  --

  ---
  -- Fatal success.
  --
  self.redis = redis
  return redis
end
-- // function _M.get_redis_connection (self)

-- -----------------------------------------------------------------------------

---
-- Pinger-Host-Status main routine.
--
-- Get Host-Label from Request URI, fetch assocciated
-- data from Redis, response with some HTTP-Status.
--
-- Response statuses:
--  200 - Host available (pingable).
--  503 - Host unavailable (unpingable).
--  404 - Host not found (in Redis cache).
--  400 - Invalid URI format (failed to apply Regexp).
--  500 - Internal server error.
--
function _M.main (self)
  ngx.log(ngx.INFO, 'debug = ', self.debug)

  ---
  -- Parse Request URI, get Host-Label.
  --
  ngx.log(ngx.INFO, 'uri = ', ngx.var.uri)

  local label = string.match(ngx.var.uri, '^' .. self.uri_regexp .. '$')
  ngx.log(ngx.INFO, 'label = "', label, '"')

  if not label then
    ---
    -- Parse error.
    --
    ngx.status = ngx.HTTP_BAD_REQUEST
    if 'HEAD' ~= self.http_method then
      ngx.say('Invalid URI format')
    end

    return ngx.exit(ngx.OK)
  end
  --

  local redis = self:get_redis_connection()

  ---
  -- Fetch Host data from Redis.
  --
  ngx.log(ngx.INFO, 'fetch ', self.redis_namespace .. ':hosts:data:'.. label)
  local data_raw, err = redis:hgetall(self.redis_namespace .. ':hosts:data:'.. label)

  if not data_raw then
    ---
    -- Reading failed.
    --
    ngx.log(ngx.ERR, '500 redis:hgetall() failed: ', err)

    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    if 'HEAD' ~= self.http_method then
      ngx.say('Unable to read registry data')
    end

    return ngx.exit(ngx.OK)
  end

  if 0 == table.getn(data_raw) then
    ---
    -- Host not found.
    --
    ngx.status = ngx.HTTP_NOT_FOUND
    if 'HEAD' ~= self.http_method then
      ngx.say('Not found')
    end

    return ngx.exit(ngx.OK)
  end
  --

  ---
  -- Convert array to table.
  --
  local data = {}
  for idx = 1, #data_raw, 2 do
      data[data_raw[idx]] = data_raw[idx + 1]
  end

  for k,v in pairs(data) do
    ngx.log(ngx.INFO, k, ' = ', v)
  end
  --


  ---
  -- Final work.
  --
  local state = tonumber(data.state)
  ngx.log(ngx.INFO, 'state = "', state, '"')

  local state_tail = bit.band(1, data.state)
  if 1 ~= state_tail then
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE

    if 'HEAD' ~= self.http_method then
      ngx.say('Offline')
    end

    return ngx.exit(ngx.OK)
  end

  ngx.status = ngx.HTTP_OK
  if 'HEAD' ~= self.http_method then
    ngx.say('Online')
  end

  return ngx.exit(ngx.OK)
end
-- // function _M.main (self)

-- -----------------------------------------------------------------------------

---
-- Lua-class magick. Part 2.
--
return _M
--


--- eof
