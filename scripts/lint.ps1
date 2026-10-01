# Runs luacheck (static analysis, configured in .luacheckrc) in the same Docker image as the tests.
# It finds what the tests can't: leaked globals and unused variables in code the tests never run.
#
# Usage:
#   .\scripts\lint.ps1                    # the addon and the tests
#   .\scripts\lint.ps1 AztecGambling.lua  # one file
# Any arguments are passed straight to luacheck.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$image = "aztecgambling-tests"

docker build --quiet --tag $image (Join-Path $root "spec") | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$luacheckArgs = @($args | ForEach-Object { "$_" -replace "\\", "/" })
if ($luacheckArgs.Count -eq 0) { $luacheckArgs = @(".") }

docker run --rm --volume "${root}:/addon" $image luacheck @luacheckArgs --codes
exit $LASTEXITCODE
