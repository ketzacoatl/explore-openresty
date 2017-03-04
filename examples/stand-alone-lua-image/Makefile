build:
	docker build --tag=lua --rm .

run:
	docker run -it --rm -v `pwd`:/src lua

test:
	# Run the following two commands:
	#   make run
	#   luarocks-5.1 install lua-cjson && lua5.1 cjson-test.lua
