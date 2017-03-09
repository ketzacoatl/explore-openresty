### How to run the demo

I believe the only requirement is that docker is installed/available.. YMMV

```
$ cd demo
$ make build
$ make run-stats
# open localhost:3000 in your browser, and login with admin:admin
$ make run
$ make rerun-sink
$ make add-sinks
$ make load-test MAX=100
```

While that runs, open another shell to execute:

```
$ make cat-queue
$ make count-posts
$ make count-queue
$ make cat-posts
$ make cat-queue
```

To send in a larger load test, set `MAX=1000000` or similar. That will send in
some number of requests that is not higher than the max.

On an old quad-core desktop, I was able to process ~1,000 messages / second
through the stack, while running all my usual desktop stuff.

See the `Makefile` targets for all sorts of helpers for checking logs, running
a shell in a specific component, etc.

