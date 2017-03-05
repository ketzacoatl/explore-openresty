local cjson = require "cjson"
-- install lua-hiredis
local redis = require "hiredis"
-- names for our lists in redis
local q     = "enqueued"
local p     = "processing"
-- length of time (seconds) to sleep
local delay = 0.001
-- return redis client, or fail and exit
connect = function (host)
  local rc, err, err_code = hiredis.connect(host, 6379)
  if not rc then
    print("failed to connect to redis..")
    print("error: " .. err)
    print("code:  " .. err_code)
    os.exit(1)
  else
    return rc
  end
end
-- retrieve work from redis, store it in "processing" table
get_work = function()
  return rc:command("RPOPLPUSH", q, p)
end
-- "do" the work
process = function (i)
  print(i)
end
-- work is done, drop it from the processing table
dondrop = function (i)
  return rc:command("LREM", p, 1, i)
end
-- pause for a moment..
-- could also use socket.sleep(sec) from the "socket" library
sleep = function(t)
  os.execute("sleep " .. tonumber(t))
end
--
-- MAIN
rc = connect(os.getenv("REDIS_HOST"))
assert(rc)
-- loop doing work until you can't
while true do
  item, err, code = get_work(q, p)
  if item.name == "NIL" then
    -- pass
  else
    --print("got item!")
    process(item)
    dondrop(item)
  end
  sleep(delay)
end

rc:close()
