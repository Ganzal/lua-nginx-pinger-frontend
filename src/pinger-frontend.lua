---
-- Package:     pinger-nginx-lua
-- Subpackage:  pinger-frontend
--
-- Морда к Pinger Service, отвечающая различными
--  HTTP-статусами на запросы URL-ов определенного вида.
--

---
-- Зависимости
--
local resty_redis = require "resty.redis"
local resty_string = require "resty.string"
local bit = require "bit"
local debug = require "debug"
--


---
-- Сборка "класса" Lua.
--
local _M = {}
_M.__index = _M

_M._VERSION = '0.1.1'
local mt = { __index = _M }


---
-- Конструктор Pinger-Frontend
--
function _M.new ()
    local self = setmetatable({}, mt)

    ---
    -- Реестр локальных переменных
    --

    -- Метод HTTP
    self.http_method = ngx.req.get_method()

    if 'HEAD' ~= ngx.req.get_method() then
      ngx.header.content_type = 'text/plain'
    end

    -- Экземпляр подключения к Redis
    self.redis = nil

    ---
    -- Реестр переменных конфигурации
    --
    self.redis_host = ngx.var.pinger_redis_host or '127.0.0.1'
    self.redis_port = tonumber(ngx.var.pinger_redis_port) or 6379
    self.redis_sock = ngx.var.pinger_redis_sock or false
    self.redis_namespace = ngx.var.pinger_redis_namespace or 'pinger'
    self.redis_database = tonumber(ngx.var.pinger_redis_database) or 1
    self.uri_regexp = ngx.var.pinger_uri_regexp or '/([^/]+)/'


    return self
end
-- // function _M.new ()

-- -----------------------------------------------------------------------------

---
-- Получение экземпляра клиента Redis
--
function _M.get_redis_connection (self)
  if self.redis then
    return self.redis
  end

  local ok, err = nil

  local redis = resty_redis:new()

  if not redis then
    if 'HEAD' ~= self.http_method then
      ngx.say('redis:new() failed: ', err)
    end

    return ngx.exit(ngx.OK)
  end

  redis:set_timeout(1000)

  -- попытка подключения к серверу
  if self.redis_sock then
    ok, err = redis:connect(self.redis_sock)
  else
    ok, err = redis:connect(self.redis_host, self.redis_port)
  end

  -- подключение не удалось - выход
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR

    if 'HEAD' ~= self.http_method then
      ngx.say('redis:connect() failed:', err)
    end

    return ngx.exit(ngx.OK)
  end

  ok, err = redis:select(self.redis_database)
  if not ok then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR

    if 'HEAD' ~= self.http_method then
      ngx.say('redis:select() failed:', err)
    end

    return ngx.exit(ngx.OK)
  end

  -- подключение удалось
  self.redis = redis
  return redis
end
-- // function _M.get_redis_connection (self)

-- -----------------------------------------------------------------------------

---
-- Рутина проверки статуса хоста.
--
-- Из URI запроса выделяет лейбл хоста, получает из кэша Redis соответствующую
-- запись, анализирует значение поля state и отвечает HTTP-статусом и коротким
-- текстовым сообщением.
--
-- Статусы:
--  200 - хост доступен, последний Ping завершился удачей
--  400 - некорректный формат адреса запроса
--  404 - запись хоста не найдена в кэше Redis
--  503 - хост недоступен, последний Ping завершился неудачей
--  500 - собственные ошибки PingerFrontend
--
function _M.main (self)
  ngx.log(ngx.INFO, 'debug = ', self.debug)

  -- разбор адреса запроса
  ngx.log(ngx.INFO, 'uri = ', ngx.var.uri)

  local label = string.match(ngx.var.uri, '^' .. self.uri_regexp .. '$')
  ngx.log(ngx.INFO, 'label = "', label, '"')

  -- некорректный формат адреса запроса
  if not label then
    ngx.status = ngx.HTTP_BAD_REQUEST
    if 'HEAD' ~= self.http_method then
      ngx.say('Invalid URI format')
    end

    return ngx.exit(ngx.OK)
  end

  -- подключение к Redis
  local redis = self:get_redis_connection()

  -- чтение записи хоста
  ngx.log(ngx.INFO, 'fetch ', self.redis_namespace .. ':hosts:data:'.. label)
  local data_raw, err = redis:hgetall(self.redis_namespace .. ':hosts:data:'.. label)

  -- ошибка чтения
  if not data_raw then
    ngx.log(ngx.ERR, '500 redis:hgetall() failed: ', err)

    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    if 'HEAD' ~= self.http_method then
      ngx.say('Unable to read registry data')
    end

    return ngx.exit(ngx.OK)
  end

  -- успешное чтение, но нет такой записи
  if 0 == table.getn(data_raw) then
    ngx.status = ngx.HTTP_NOT_FOUND
    if 'HEAD' ~= self.http_method then
      ngx.say('Not found')
    end

    return ngx.exit(ngx.OK)
  end

  -- декодирование записи хоста
  local data = {}
  for idx = 1, #data_raw, 2 do
      data[data_raw[idx]] = data_raw[idx + 1]
  end

  for k,v in pairs(data) do
    ngx.log(ngx.INFO, k, ' = ', v)
  end

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


return _M

--- eof
