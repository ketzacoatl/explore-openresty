local redis  = require "hiredis"
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
-- send a PING to redis and print True/False for PONG as result
ping_pong = function(client)
  print("PONG:")
  print(client:command("PING") == hiredis.status.PONG)
end
-- push a few test keys simulating a writing producer
push_keys = function(client)
  rc:command("LPUSH", "enqueued", "a")
  rc:command("LPUSH", "enqueued", "b")
  rc:command("LPUSH", "enqueued", "c")
  rc:command("LPUSH", "enqueued", "d")
end
-- return the lua table that is the redis list, in full
get_list = function(client, list)
  return client:command("LRANGE", list, 0, -1)
end
-- for the lua table t, print the key/value pairs (one level)
print_table = function(t)
  for k,v in pairs(t) do
    print(k, v)
  end
end
-- wrap redis RPOPLPUSH
rpoplpush = function(q, p)
  return rc:command("RPOPLPUSH", q, p)
end
-- wrap redis LREM
drop = function(tbl, key)
  return rc:command("LREM", tbl, 1, key)
end
--
-- MAIN
rc = connect("127.0.0.1")
ping_pong(rc)
-- push some keys to the q
push_keys(rc)
-- print out those keys
print("LRANGE enqueued:")
q = get_list(rc, "enqueued")
print_table(q)
-- RPOPLPUSH one key over to processing
pop = rpoplpush("enqueued", "processing")
print("pop the queue, now processing: " .. pop)
-- retrieve and print the two lists as they are now..
q = get_list(rc, "enqueued")
print("queue is now:")
print_table(q)
--
p = get_list(rc, "processing")
print("processing is now:")
print_table(p)
-- ok, we're done with the key, let's drop it
print("done with:")
print(pop)
print("drop from processing..")
print(drop("processing", pop))
-- retrieve and print the two lists as they are now..
q = get_list(rc, "enqueued")
print("queue:")
print_table(q)
--
p = get_list(rc, "processing")
print("processing:")
print_table(p)
-- goodbye redis
rc:close()
