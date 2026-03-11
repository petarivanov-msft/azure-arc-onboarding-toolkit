<#
.SYNOPSIS
    Pre-flight connectivity check for Azure Arc required endpoints.
.PARAMETER ConfigPath
    Path to the onboarding-config.json file (for proxy settings).
.PARAMETER Location
    Azure region. Defaults to 'uksouth'.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$Location = 'uksouth'
)

# Required endpoints for Azure Arc
# https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements
$endpoints = @(
    @{ Host = "management.azure.com";                      Port = 443; Description = "Azure Resource Manager" }
    @{ Host = "login.microsoftonline.com";                 Port = 443; Description = "Azure AD authentication" }
    @{ Host = "$Location.his.arc.azure.com";               Port = 443; Description = "Arc metadata service" }
    @{ Host = "guestconfiguration.azure.com";              Port = 443; Description = "Guest Configuration" }
    @{ Host = "gbl.his.arc.azure.com";                     Port = 443; Description = "Arc global endpoint" }
    @{ Host = "aka.ms";                                     Port = 443; Description = "Download redirector" }
    @{ Host = "packages.microsoft.com";                    Port = 443; Description = "Linux agent packages" }
    @{ Host = "download.microsoft.com";                    Port = 443; Description = "Windows agent download" }
)

# Configure proxy if config provided
if ($ConfigPath -and (Test-Path $ConfigPath)) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($config.proxyUrl) {
        Write-Host "Using proxy: $($config.proxyUrl)" -ForegroundColor Cyan
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($config.proxyUrl)
    }
}

Write-Host ""
Write-Host "Azure Arc Connectivity Test" -ForegroundColor Yellow
Write-Host "Region: $Location"
Write-Host ("-" * 70)

$passed = 0
$failed = 0

foreach ($ep in $endpoints) {
    $host_ = $ep.Host
    $port = $ep.Port

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($host_, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)

        if ($wait -and $tcp.Connected) {
            Write-Host "  PASS  $host_`:$port ($($ep.Description))" -ForegroundColor Green
            $passed++
        }
        else {
            Write-Host "  FAIL  $host_`:$port ($($ep.Description)) - Timeout" -ForegroundColor Red
            $failed++
        }
        $tcp.Close()
    }
    catch {
        Write-Host "  FAIL  $host_`:$port ($($ep.Description)) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ("-" * 70)
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "Some endpoints are unreachable. Check firewall rules and proxy config." -ForegroundColor Yellow
    Write-Host "Docs: https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements"
    exit 1
}
