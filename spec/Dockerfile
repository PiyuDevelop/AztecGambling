# Test image: Lua 5.1 (the version WoW uses), the busted test framework,
# luacheck (static analysis) and luacov (test coverage).
# The addon itself isn't copied in: the scripts and CI mount the repo at /addon.
FROM alpine:3.20

RUN apk add --no-cache lua5.1 lua5.1-dev luarocks5.1 build-base \
 && luarocks-5.1 install busted 2.2.0 \
 && luarocks-5.1 install luacheck 1.2.0 \
 && luarocks-5.1 install luacov 0.15.0

WORKDIR /addon
CMD ["busted"]
