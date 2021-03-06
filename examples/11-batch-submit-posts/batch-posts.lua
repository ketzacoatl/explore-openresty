local cjson = require('cjson')
local cli   = require('cliargs')
local hc    = require('httpclient').new()
--
local default_url = 'http://127.0.0.1:8000'
local date_fmt    = '%m-%d-%Y--%H-%M-%S'
--
-- cli args, parsing, and help docs
cli:option('--limit=NUMBER', 'max number of posts to send', 100)
cli:option('--url=HTTP_URL', 'URL to POST messages to', default_url)
cli:flag('--list', 'hit the list endpoint to retrieve the latest posts', false)
--
-- auto-gen some JSON to send as a post/message
generate_post = function ()
  return { hello = world, now = os.date(date_fmt)}
end
-- where msg is some {}
send_post = function (url, msg)
  return hc:post(url,
                 cjson.encode(msg),
                 {content_type = 'application/json'})
end
-- hit the /list endpoint to retrieve the latest posts
get_posts = function (url)
  return hc:get(url)
end
-- our primary loop
batch_send = function (url, limit)
  while (limit > 0)
  do
    msg = generate_post()
    res = send_post(url, msg)
    if res.code == 200 then
      print('POST success! ' .. res.body)
    else
      print('non-200 return! ' .. res.code .. ' ' .. res.err)
    end
    limit = limit-1
  end
end
--
-- MAIN
--
local args, err = cli:parse()
-- if there's an error in parsing (or --help), print it!
if err then
  print(err)
  os.exit(0)
end
--
print('Let us post a bunch of messages to the service:')
i = math.random(0, args.limit)
print('We will print ' .. i .. ' messages this time..')
batch_send(args.url, i)


if args.list then
  print('Let us retrieve the top posts saved/written to the service:')
  posts = get_posts(args.url .. '/list').body
  print(posts)
end
