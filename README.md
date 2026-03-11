# Azure Arc Onboarding Toolkit

PowerShell scripts for onboarding servers to Azure Arc in bulk. Built this after manually running `azcmagent connect` on 50+ servers and deciding never to do that again.

Handles the stuff you run into at scale: proxy environments, custom tagging, error logging, and servers that are half-configured from a previous attempt.

## What's in here

- `Install-ArcAgent.ps1` — installs and connects the Arc agent on a single server
- `Invoke-BulkOnboarding.ps1` — reads a CSV of servers and runs the install against each one
- `Test-ArcConnectivity.ps1` — pre-flight check for all required Arc endpoints
- `Export-OnboardingReport.ps1` — generates a summary of what worked and what didn't

## Quick start

1. Fill in `config/onboarding-config.json` with your tenant, subscription, and resource group
2. Update `config/servers-sample.csv` with your server list (or create your own CSV)
3. Run the connectivity test first:

```powershell
.\scripts\Test-ArcConnectivity.ps1 -ConfigPath .\config\onboarding-config.json
```

4. If that passes, kick off the bulk onboarding:

```powershell
.\scripts\Invoke-BulkOnboarding.ps1 -ServerCsv .\config\servers-sample.csv -ConfigPath .\config\onboarding-config.json
```

5. Check the results:

```powershell
.\scripts\Export-OnboardingReport.ps1 -LogPath C:\ArcOnboarding\Logs -OutputPath .\report.html
```

## Prerequisites

See [docs/prerequisites.md](docs/prerequisites.md) for the full list — short version: you need a service principal with Azure Connected Machine Onboarding role, network access to the Arc endpoints, and PowerShell 5.1+.

## Notes

- Tested with Windows Server 2016/2019/2022 and a couple of RHEL 8 boxes
- Proxy support is baked in — set it in the config file and the scripts handle the rest
- If a server already has the agent installed, the script skips the download and just reconnects
- Logs go to `C:\ArcOnboarding\Logs` by default (configurable)

## License

MIT
