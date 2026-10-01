# Runs the tests with luacov and prints how much of each addon file they run.
# The full line-by-line report is written to luacov.report.out (lines marked
# with ***0 never ran). Both output files are ignored by git.
#
# Usage:
#   .\scripts\coverage.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$image = "aztecgambling-tests"

docker build --quiet --tag $image (Join-Path $root "spec") | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Fresh stats each run; then the summary table at the end of the report
docker run --rm --volume "${root}:/addon" $image sh -c "rm -f luacov.stats.out luacov.report.out && busted --coverage > /dev/null; status=`$?; luacov && sed -n '/^Summary/,`$p' luacov.report.out; exit `$status"
exit $LASTEXITCODE
