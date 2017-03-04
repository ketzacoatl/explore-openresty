local redis  = require "hiredis"
local client, err, err_code = hiredis.connect("127.0.0.1", 6379)
if not client then
  print("failed to connect to redis..")
  print("error: " .. err)
  print("code:  " .. err_code)
  return
end
print("PONG:")
print(client:command("PING") == hiredis.status.PONG)
client:close()
