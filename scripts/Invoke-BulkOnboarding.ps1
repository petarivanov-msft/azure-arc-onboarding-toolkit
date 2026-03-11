<#
.SYNOPSIS
    Bulk onboards servers to Azure Arc from a CSV file.
.PARAMETER ServerCsv
    Path to the CSV file with server details.
.PARAMETER ConfigPath
    Path to the onboarding-config.json file.
.PARAMETER ThrottleLimit
    Max concurrent onboarding jobs. Default 5.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerCsv,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [int]$ThrottleLimit = 5
)

$ErrorActionPreference = 'Stop'

# Validate inputs
if (-not (Test-Path $ServerCsv)) {
    throw "Server CSV not found: $ServerCsv"
}
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$servers = Import-Csv $ServerCsv
Write-Host "Loaded $($servers.Count) servers from $ServerCsv"

# Validate CSV columns
$requiredColumns = @('ServerName', 'ResourceGroup', 'Location')
foreach ($col in $requiredColumns) {
    if ($col -notin $servers[0].PSObject.Properties.Name) {
        throw "CSV is missing required column: $col"
    }
}

$results = [System.Collections.ArrayList]::new()
$scriptPath = Join-Path $PSScriptRoot 'Install-ArcAgent.ps1'

foreach ($server in $servers) {
    $serverName = $server.ServerName.Trim()
    if ([string]::IsNullOrWhiteSpace($serverName)) {
        Write-Warning "Skipping blank server entry"
        continue
    }

    Write-Host "[$($results.Count + 1)/$($servers.Count)] Onboarding $serverName..." -ForegroundColor Cyan

    try {
        # For remote execution, use Invoke-Command
        # For local testing, run directly
        if ($serverName -eq $env:COMPUTERNAME) {
            & $scriptPath -ConfigPath $ConfigPath -ServerName $serverName -Verbose
        }
        else {
            Invoke-Command -ComputerName $serverName -ScriptBlock {
                param($script, $config, $name)
                & $script -ConfigPath $config -ServerName $name
            } -ArgumentList $scriptPath, $ConfigPath, $serverName -ErrorAction Stop
        }

        $results.Add([PSCustomObject]@{
            ServerName = $serverName
            Status     = 'Success'
            Error      = $null
            Timestamp  = Get-Date
        }) | Out-Null

        Write-Host "  $serverName - OK" -ForegroundColor Green
    }
    catch {
        $results.Add([PSCustomObject]@{
            ServerName = $serverName
            Status     = 'Failed'
            Error      = $_.Exception.Message
            Timestamp  = Get-Date
        }) | Out-Null

        Write-Warning "  $serverName - FAILED: $($_.Exception.Message)"
    }
}

# Summary
$succeeded = ($results | Where-Object Status -eq 'Success').Count
$failed = ($results | Where-Object Status -eq 'Failed').Count
Write-Host ""
Write-Host "Onboarding complete: $succeeded succeeded, $failed failed out of $($results.Count) total" -ForegroundColor Yellow

# Export results
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$resultsPath = Join-Path $config.logPath "onboarding-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$results | Export-Csv -Path $resultsPath -NoTypeInformation
Write-Host "Results exported to $resultsPath"
