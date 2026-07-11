# Remote deploy helper (Windows OpenSSH client → Ubuntu server)
# Usage: powershell -File scripts/remote.ps1 <check|sync|up|down|restart|logs|ps|status|pull|ssh> [extra ssh args]

param(
  [Parameter(Position = 0, Mandatory = $true)]
  [ValidateSet('check', 'sync', 'up', 'down', 'restart', 'logs', 'ps', 'status', 'pull', 'ssh')]
  [string]$Action,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Read-DotEnv {
  param([string]$Path)
  $map = @{}
  if (-not (Test-Path $Path)) { return $map }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $k = $line.Substring(0, $eq).Trim()
    $v = $line.Substring($eq + 1).Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
      $v = $v.Substring(1, $v.Length - 2)
    }
    $map[$k] = $v
  }
  return $map
}

function Require-Cmd([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing '$Name'. Install OpenSSH Client (Windows Settings → Optional features) or use WSL/Ubuntu."
  }
}

$envMap = Read-DotEnv (Join-Path $Root '.env')
$hostName = $envMap['DEPLOY_HOST']
$user = if ($envMap['DEPLOY_USER']) { $envMap['DEPLOY_USER'] } else { 'ubuntu' }
$path = if ($envMap['DEPLOY_PATH']) { $envMap['DEPLOY_PATH'] } else { '/opt/zeroclaw' }
$port = if ($envMap['DEPLOY_SSH_PORT']) { $envMap['DEPLOY_SSH_PORT'] } else { '22' }
$key = $envMap['DEPLOY_SSH_KEY']

if (-not $hostName) {
  throw "Set DEPLOY_HOST in .env (e.g. DEPLOY_HOST=myserver.example.com)"
}

Require-Cmd ssh
Require-Cmd scp

$sshArgs = @('-p', $port, '-o', 'StrictHostKeyChecking=accept-new')
if ($key) {
  if (-not (Test-Path $key)) { throw "DEPLOY_SSH_KEY not found: $key" }
  $sshArgs += @('-i', $key)
}
$target = "${user}@${hostName}"

function Invoke-Remote([string]$RemoteCmd) {
  & ssh @sshArgs $target $RemoteCmd
  if ($LASTEXITCODE -ne 0) { throw "Remote command failed ($LASTEXITCODE): $RemoteCmd" }
}

switch ($Action) {
  'check' {
    Write-Host "Checking SSH: $target:$port → $path"
    Invoke-Remote "echo ok && uname -a && docker --version && docker compose version"
    Write-Host "Remote OK"
  }
  'sync' {
    # Render config locally first if node is available
    if (Get-Command node -ErrorAction SilentlyContinue) {
      node (Join-Path $Root 'scripts/sync-config.js')
    }

    Write-Host "Ensuring remote dir $path"
    Invoke-Remote "mkdir -p '$path/data/.zeroclaw' '$path/data/data' '$path/config' '$path/scripts' '$path/docs'"

    $files = @(
      'docker-compose.yml',
      'Makefile',
      '.env',
      '.env.example',
      'Dockerfile',
      'config/config.toml.example',
      'scripts/sync-config.js',
      'docs/telegram.md',
      'README.md'
    )
    foreach ($f in $files) {
      $local = Join-Path $Root $f
      if (-not (Test-Path $local)) {
        Write-Host "Skip missing $f"
        continue
      }
      $remote = "$target`:$path/$f"
      Write-Host "scp $f"
      & scp @sshArgs $local $remote
      if ($LASTEXITCODE -ne 0) { throw "scp failed: $f" }
    }

    $cfg = Join-Path $Root 'data/.zeroclaw/config.toml'
    if (Test-Path $cfg) {
      Write-Host "scp data/.zeroclaw/config.toml"
      & scp @sshArgs $cfg "$target`:$path/data/.zeroclaw/config.toml"
      if ($LASTEXITCODE -ne 0) { throw "scp failed: config.toml" }
    }

    Write-Host "Synced to $target:$path"
  }
  'up' {
    Invoke-Remote "cd '$path' && docker compose pull && docker compose up -d"
  }
  'down' {
    Invoke-Remote "cd '$path' && docker compose down"
  }
  'restart' {
    Invoke-Remote "cd '$path' && docker compose restart"
  }
  'logs' {
    & ssh @sshArgs -t $target "cd '$path' && docker compose logs -f --tail=100"
  }
  'ps' {
    Invoke-Remote "cd '$path' && docker compose ps"
  }
  'status' {
    Invoke-Remote "cd '$path' && docker compose exec -T zeroclaw zeroclaw status --format=exit-code && echo OK"
  }
  'pull' {
    Invoke-Remote "cd '$path' && docker compose pull"
  }
  'ssh' {
    if ($Rest -and $Rest.Count -gt 0) {
      $cmd = ($Rest -join ' ')
      & ssh @sshArgs -t $target "cd '$path' && $cmd"
    } else {
      & ssh @sshArgs -t $target "cd '$path' && exec `$SHELL -l"
    }
  }
}
