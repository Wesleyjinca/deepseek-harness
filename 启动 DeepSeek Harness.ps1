$ErrorActionPreference = 'Stop'

$harnessPath = 'C:\Tools\AI\model\deepseek-harness'
$webUrl = 'http://127.0.0.1:3080'

if (-not (Test-Path -LiteralPath $harnessPath)) {
    [System.Windows.Forms.MessageBox]::Show("找不到 Harness 目录：$harnessPath", 'DeepSeek Harness')
    exit 1
}

$listener = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
    $launchCommand = "Set-Location -LiteralPath '$harnessPath'; `$env:DSH_PERMISSION_MODE='danger-full-access'; corepack pnpm dsh web"
    Start-Process powershell.exe -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-NoExit',
        '-Command', $launchCommand
    )

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) {
            $ready = $true
            break
        }
    }

    if (-not $ready) {
        [System.Windows.Forms.MessageBox]::Show('Harness 启动时间超过 30 秒，请查看弹出的 PowerShell 窗口。', 'DeepSeek Harness')
        exit 1
    }
}

Start-Process $webUrl
