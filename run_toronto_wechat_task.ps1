$ErrorActionPreference = 'Stop'

$harnessPath = 'C:\Tools\AI\model\deepseek-harness'
$taskPath = Join-Path $harnessPath 'tasks\toronto-wechat-real-estate.md'

Set-Location -LiteralPath $harnessPath
$env:DSH_PERMISSION_MODE = 'danger-full-access'

if (-not (Test-Path -LiteralPath $taskPath)) {
    throw "Task file not found: $taskPath"
}

$task = Get-Content -LiteralPath $taskPath -Raw
$prompt = @"
执行下面的任务文件。你必须实际读取公开资料、分析内容并写入任务规定的 output 和 data 文件，不要只给计划：

$task
"@

corepack pnpm dsh --profile headless $prompt
