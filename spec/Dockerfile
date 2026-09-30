# Test image: Lua 5.1 (the version WoW uses) and the busted test framework.
# The addon itself isn't copied in: scripts/test.ps1 and CI mount the repo at /addon.
FROM alpine:3.20

RUN apk add --no-cache lua5.1 lua5.1-dev luarocks5.1 build-base \
 && luarocks-5.1 install busted 2.2.0

WORKDIR /addon
CMD ["busted"]
