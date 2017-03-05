cjson = require("cjson")
hc = require("httpclient").new()
resp = hc:post('127.0.0.1:8000/', cjson.encode({ hello = "world" }))
if resp.code == 200 then
  print("success!")
end
print(resp.body)
print(resp.code)
print(resp.headers)
print(resp.status_line)
print(resp.err)
