<#
.SYNOPSIS
    Installs and connects the Azure Arc agent on a single server.
.DESCRIPTION
    Checks if the agent is already installed, downloads it if needed,
    and runs azcmagent connect with the provided configuration.
.PARAMETER ConfigPath
    Path to the onboarding-config.json file.
.PARAMETER ServerName
    Optional. Used for logging. Defaults to the local hostname.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [string]$ServerName = $env:COMPUTERNAME
)

$ErrorActionPreference = 'Stop'
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Set up logging
$logDir = $config.logPath
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir "$ServerName-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    $entry | Out-File -Append -FilePath $logFile
    if ($Level -eq 'ERROR') { Write-Error $Message } else { Write-Verbose $Message }
}

# Configure proxy if set
if ($config.proxyUrl) {
    Write-Log "Setting proxy to $($config.proxyUrl)"
    [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($config.proxyUrl)
    $env:HTTPS_PROXY = $config.proxyUrl
}

# Check if agent is already installed
$agentPath = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"
$agentInstalled = Test-Path $agentPath

if (-not $agentInstalled) {
    Write-Log "Arc agent not found. Downloading installer..."
    $installerUrl = "https://aka.ms/azcmagent-windows"
    $installerPath = Join-Path $env:TEMP "AzureConnectedMachineAgent.msi"

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Log "Installing Arc agent..."
        $installArgs = "/i `"$installerPath`" /quiet /norestart"
        $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Log "MSI install failed with exit code $($process.ExitCode)" -Level ERROR
            return
        }
        Write-Log "Agent installed successfully"
    }
    catch {
        Write-Log "Failed to download/install agent: $_" -Level ERROR
        return
    }
}
else {
    Write-Log "Agent already installed at $agentPath"
}

# Build connection arguments
$connectArgs = @(
    "connect"
    "--service-principal-id", $config.servicePrincipalId
    "--service-principal-secret", $config.servicePrincipalSecret
    "--tenant-id", $config.tenantId
    "--subscription-id", $config.subscriptionId
    "--resource-group", $config.resourceGroup
    "--location", $config.location
)

# Add tags if configured
if ($config.tags) {
    $tagString = ($config.tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","
    $connectArgs += @("--tags", $tagString)
}

# Add proxy if configured
if ($config.proxyUrl) {
    $connectArgs += @("--proxy-url", $config.proxyUrl)
}

Write-Log "Running azcmagent connect for $ServerName..."
try {
    $result = & $agentPath @connectArgs 2>&1
    $resultText = $result -join "`n"
    Write-Log "azcmagent output: $resultText"

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Successfully connected $ServerName to Azure Arc"
    }
    else {
        Write-Log "azcmagent connect failed with exit code $LASTEXITCODE" -Level ERROR
    }
}
catch {
    Write-Log "Exception during azcmagent connect: $_" -Level ERROR
}
