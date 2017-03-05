local cjson = require "cjson"
local pgmoon = require "pgmoon"
local pg = pgmoon.new({
  host     = os.getenv("DB_HOST"),
  port     = "5432",
  user     = os.getenv("DB_USER"),
  password = os.getenv("DB_PASS"),
  database = os.getenv("DB_NAME")
})
assert(pg:connect())
local encode_json = require("pgmoon.json").encode_json

write = function(data)
  assert(pg:query("INSERT INTO posts (data) VALUES(" .. encode_json(data) .. ");"))
  print(data)
end

--
-- MAIN
for l=1, 500
do
  print("enqueue: " .. l)
  date_fmt = "%m-%d-%Y--%H-%M-%S"
  write(cjson.encode({timestamp = os.date(date_fmt), msg = "hi! this is " .. l}))
  l = l + 1
end
