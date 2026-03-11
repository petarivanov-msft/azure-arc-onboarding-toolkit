<#
.SYNOPSIS
    Generates an onboarding report from log files.
.PARAMETER LogPath
    Directory containing onboarding log files.
.PARAMETER OutputPath
    Where to save the report. Supports .html and .csv.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LogPath,

    [string]$OutputPath = ".\onboarding-report.html"
)

if (-not (Test-Path $LogPath)) {
    throw "Log directory not found: $LogPath"
}

$logFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -File
if ($logFiles.Count -eq 0) {
    Write-Warning "No log files found in $LogPath"
    return
}

Write-Host "Processing $($logFiles.Count) log files..."

$results = foreach ($file in $logFiles) {
    $content = Get-Content $file.FullName -Raw
    $serverName = $file.BaseName -replace '-\d{8}-\d{6}$', ''

    $status = if ($content -match 'Successfully connected') { 'Connected' }
              elseif ($content -match 'FAILED|ERROR') { 'Failed' }
              else { 'Unknown' }

    $errorMsg = if ($content -match '\[ERROR\]\s*(.+)') { $Matches[1] } else { $null }

    [PSCustomObject]@{
        Server    = $serverName
        Status    = $status
        Error     = $errorMsg
        LogFile   = $file.Name
        Timestamp = $file.LastWriteTime
    }
}

# Summary stats
$connected = ($results | Where-Object Status -eq 'Connected').Count
$failed = ($results | Where-Object Status -eq 'Failed').Count
$unknown = ($results | Where-Object Status -eq 'Unknown').Count
$total = $results.Count

Write-Host "Connected: $connected | Failed: $failed | Unknown: $unknown | Total: $total"

if ($OutputPath -like '*.csv') {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "CSV report saved to $OutputPath"
}
else {
    # Generate HTML report
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Arc Onboarding Report</title>
    <style>
        body { font-family: -apple-system, sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; }
        h1 { color: #333; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 6px; margin-bottom: 20px; }
        .summary span { margin-right: 20px; }
        .ok { color: #28a745; }
        .fail { color: #dc3545; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; }
        tr.failed td { background: #fff5f5; }
    </style>
</head>
<body>
    <h1>Azure Arc Onboarding Report</h1>
    <p>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
    <div class="summary">
        <span class="ok">Connected: $connected</span>
        <span class="fail">Failed: $failed</span>
        <span>Unknown: $unknown</span>
        <span>Total: $total</span>
    </div>
    <table>
        <tr><th>Server</th><th>Status</th><th>Error</th><th>Timestamp</th></tr>
$(foreach ($r in $results | Sort-Object Status, Server) {
    $class = if ($r.Status -eq 'Failed') { ' class="failed"' } else { '' }
    "        <tr$class><td>$($r.Server)</td><td>$($r.Status)</td><td>$($r.Error)</td><td>$($r.Timestamp.ToString('yyyy-MM-dd HH:mm'))</td></tr>"
})
    </table>
</body>
</html>
"@
    $html | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Host "HTML report saved to $OutputPath"
}
