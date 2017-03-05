local cjson = require "cjson"
local redis = require "hiredis"
-- names for our lists in redis
local q     = "enqueued"
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
-- push a key to the queue
enqueue = function(key)
  rc:command("LPUSH", q, key)
end
--
-- MAIN
rc = connect(os.getenv("REDIS_HOST"))
assert(rc)
for l=1, 100000
do
  print("enqueue: " .. l)
  date_fmt = "%m-%d-%Y--%H-%M-%S"
  enqueue(cjson.encode({timestamp = os.date(date_fmt), msg = "hi! this is " .. l}))
  l = l + 1
end
