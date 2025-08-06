# Test script to simulate remote execution environment
# Simulate what happens when running via iex

# Clear the variables that would be empty in iex context
$MyInvocation.ScriptName = $null
$PSCommandPath = $null

# Now source the main script
. .\LMDT.ps1
