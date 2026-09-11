$ErrorActionPreference = 'Stop'

$harnessPath = 'C:\Tools\AI\model\deepseek-harness'
$webUrl = 'http://127.0.0.1:3080'

function Invoke-Checked([string]$FilePath, [string[]]$Arguments) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

Set-Location -LiteralPath $harnessPath
$env:DSH_PERMISSION_MODE = 'danger-full-access'

$listener = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    Start-Process $webUrl
    exit 0
}

Write-Host 'Checking DeepSeek Harness updates...' -ForegroundColor Cyan
$branch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Warning 'Cannot determine the current Git branch. Skipping update.'
} else {
    $ignoredLauncherFiles = @(
        'start_deepseek_harness.bat',
        'start_deepseek_harness.ps1',
        '启动 DeepSeek Harness.bat',
        '启动 DeepSeek Harness.ps1'
    )
    $changes = @(git status --porcelain | Where-Object {
        $path = ($_ -replace '^...\s+', '').Trim('"')
        $ignoredLauncherFiles -notcontains $path
    })
    if ($changes.Count -gt 0) {
        Write-Warning 'Local changes detected. Skipping automatic update to protect your changes:'
        $changes | Select-Object -First 12 | ForEach-Object { Write-Host "  $_" }
    } else {
        try {
            Invoke-Checked 'git' @('fetch', 'origin', $branch)
            $localCommit = (git rev-parse 'HEAD').Trim()
            $remoteCommit = (git rev-parse "origin/$branch").Trim()

            if ($localCommit -ne $remoteCommit) {
                $isBehind = git merge-base --is-ancestor HEAD "origin/$branch"
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Local branch and origin/$branch have diverged. Skipping automatic update."
                } else {
                    Write-Host "New version found. Updating from origin/$branch..." -ForegroundColor Yellow
                    Invoke-Checked 'git' @('pull', '--ff-only', 'origin', $branch)
                    Write-Host 'Installing dependencies...' -ForegroundColor Yellow
                    Invoke-Checked 'corepack' @('pnpm', 'install')
                    Write-Host 'Building DeepSeek Harness...' -ForegroundColor Yellow
                    Invoke-Checked 'corepack' @('pnpm', 'run', 'build')
                    Write-Host 'Update and build completed.' -ForegroundColor Green
                }
            } else {
                Write-Host 'Already up to date.' -ForegroundColor Green
            }
        } catch {
            Write-Warning "Automatic update failed. Starting the current version instead: $($_.Exception.Message)"
        }
    }
}

$launchCommand = "Set-Location -LiteralPath '$harnessPath'; `$env:DSH_PERMISSION_MODE='danger-full-access'; corepack pnpm dsh web"
Start-Process powershell.exe -WorkingDirectory $harnessPath -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-NoExit',
    '-Command', $launchCommand
)

for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) {
        Start-Process $webUrl
        exit 0
    }
}

Write-Warning 'Harness did not start within 30 seconds. Check the PowerShell window for details.'
