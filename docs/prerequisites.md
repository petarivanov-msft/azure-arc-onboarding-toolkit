# Prerequisites

What you need before running the onboarding scripts.

## Azure side

- **Service principal** with the `Azure Connected Machine Onboarding` role assigned at the resource group or subscription level. You can create one with:

```bash
az ad sp create-for-rbac --name "arc-onboarding-sp" --role "Azure Connected Machine Onboarding" --scopes /subscriptions/YOUR-SUB-ID/resourceGroups/YOUR-RG
```

- **Resource group** already created in your target region

## On the servers

- **PowerShell 5.1+** (comes with Windows Server 2016+)
- **Local admin** access (agent install requires it)
- **Network access** to Azure Arc endpoints — run `Test-ArcConnectivity.ps1` to verify
- **WinRM enabled** if you're running bulk onboarding remotely (Invoke-Command uses WinRM)

## If you're behind a proxy

Set the `proxyUrl` in `onboarding-config.json`. The scripts will configure both the download client and the `azcmagent` proxy settings.

Endpoints that need to be allowed through the proxy:
- `management.azure.com`
- `login.microsoftonline.com`
- `*.his.arc.azure.com`
- `guestconfiguration.azure.com`
- `aka.ms`
- `download.microsoft.com`

Full list: https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements
