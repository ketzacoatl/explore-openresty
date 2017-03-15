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
cli:flag('--exact', 'send `--limit` number of posts', false)
cli:flag('--list', 'hit the list endpoint to retrieve the latest posts', false)
--
-- auto-gen some JSON to send as a post/message
generate_post = function (count)
  return { hello = world, now = os.date(date_fmt), id = count}
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
  count = 1 -- first is first
  while (count < limit )
  do
    msg = generate_post(count)
    res = send_post(url, msg)
    if res.code == 200 then
      print('POST success! ' .. res.body)
    else
      print('non-200 return! ' .. tostring(res.code) .. ' ' .. res.err)
    end
    count = count+1
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
-- use --limit or generate a pseudorandom number below limit
if args.exact then
  print('--exact enabled, will use --limit as the number of posts to send')
  i = tonumber(args.limit)
else
  print('--exact disabled, pick a pseudo-random number up to --limit')
  min = (args.limit * 0.5)
  i = math.random(min, args.limit)
end
print('Let us post a bunch of messages to the service:')
print('We will print ' .. i .. ' messages this time..')
batch_send(args.url, i)

-- list mode
if args.list then
  print('Let us retrieve the top posts saved/written to the service:')
  posts = get_posts(args.url .. '/list').body
  print(posts)
end
