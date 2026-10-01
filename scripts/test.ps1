# Runs the addon's tests in Docker (Lua 5.1 + busted), so nothing has to be installed on Windows.
# Docker Desktop must be running. The image is built on the first run and cached after that.
#
# Usage (from anywhere):
#   .\scripts\test.ps1                      # every test
#   .\scripts\test.ps1 spec\round_spec.lua  # one file
#   .\scripts\test.ps1 --filter "HiLo"      # tests whose name matches
# Any arguments are passed straight to busted.
#
# Known bugs are reported as pending. To check that each one still fails:
#   $env:AG_CHECK_KNOWN_BUGS = "1"; .\scripts\test.ps1; Remove-Item Env:AG_CHECK_KNOWN_BUGS

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$image = "aztecgambling-tests"

docker build --quiet --tag $image (Join-Path $root "spec") | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# busted runs from /addon, so file paths must use forward slashes. @() keeps a single
# argument as an array - splatting a lone string would pass it one character at a time
$bustedArgs = @($args | ForEach-Object { "$_" -replace "\\", "/" })

# --env without a value passes AG_CHECK_KNOWN_BUGS only when it's set here
docker run --rm --env AG_CHECK_KNOWN_BUGS --volume "${root}:/addon" $image busted @bustedArgs
exit $LASTEXITCODE
