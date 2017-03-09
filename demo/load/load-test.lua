cjson = require("cjson")
hc = require("httpclient").new()
resp = hc:post('http://127.0.0.1:8000/',
               cjson.encode({ hello = "world" }),
               {content_type = 'application/json'})
getr = hc:get('http://127.0.0.1:8000/list')
if resp.code == 200 then
  print("success!")
end
print(resp.body)
print(resp.code)
print(resp.headers)
print(resp.status_line)
print(resp.err)

print(getr.body)
print(getr.code)
print(getr.headers)
print(getr.status_line)
print(getr.err)
