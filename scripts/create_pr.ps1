# MagicSquare_xx — push 후 parent 브랜치로 PR 자동 생성
# 사용: .\scripts\create_pr.ps1 [-Head <branch>] [-Title <title>] [-Body <body>]
param(
    [string]$Head = "",
    [string]$Title = "",
    [string]$Body = "",
    [string]$Repo = "mrjini/MagicSquare_xx"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$ghDir = "C:\Program Files\GitHub CLI"
if ((Test-Path "$ghDir\gh.exe") -and ($env:Path -notlike "*GitHub CLI*")) {
    $env:Path = "$ghDir;$env:Path"
}

if (-not $Head) {
    $Head = git branch --show-current 2>$null
}
if (-not $Head) {
    Write-Error "Cannot detect current branch. Pass -Head."
}

function Get-ParentBranch([string]$branch) {
    switch ($branch) {
        "spec" { return "staging" }
        "staging" { return "main" }
        "main" { return $null }
        default { return "spec" }  # feature/*, chore/*, etc.
    }
}

$Base = Get-ParentBranch $Head
if (-not $Base) {
    Write-Host "[create_pr] Branch '$Head' is root (main). No PR created."
    exit 0
}

$owner, $repoName = $Repo -split "/", 2
$compareUrl = "https://github.com/$Repo/compare/${Base}...${Head}?expand=1"

if (-not $Title) {
    $lastMsg = (git log -1 --pretty=%s 2>$null)
    $Title = if ($lastMsg) { $lastMsg } else { "Merge $Head into $Base" }
}
if (-not $Body) {
    $Body = @"
## Summary
- Head: ``$Head`` → Base: ``$Base``
- Auto-created by ``scripts/create_pr.ps1``

## Test plan
- [ ] Review diff
- [ ] ``pytest -v`` (if code changed)
"@
}

function Test-ExistingPrGh {
    param([string]$b, [string]$h)
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) { return $null }
    $json = gh pr list --repo $Repo --base $b --head $h --state open --json url,number 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
    $arr = $json | ConvertFrom-Json
    if ($arr.Count -gt 0) { return $arr[0] }
    return $null
}

function New-PrGh {
    param([string]$b, [string]$h, [string]$t, [string]$bd)
    $args = @(
        "pr", "create",
        "--repo", $Repo,
        "--base", $b,
        "--head", $h,
        "--title", $t,
        "--body", $bd
    )
    & gh @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh pr create failed (exit $LASTEXITCODE)" }
}

function New-PrApi {
    param([string]$b, [string]$h, [string]$t, [string]$bd)
    $token = $env:GITHUB_TOKEN
    if (-not $token) { throw "GITHUB_TOKEN not set" }
    $uri = "https://api.github.com/repos/$Repo/pulls"
    $payload = @{
        title = $t
        head  = $h
        base  = $b
        body  = $bd
    } | ConvertTo-Json
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $payload -ContentType "application/json"
    return $resp.html_url
}

Write-Host "[create_pr] Head=$Head Parent(base)=$Base"

$existing = Test-ExistingPrGh -b $Base -h $Head
if ($existing) {
    Write-Host "[create_pr] Open PR already exists: $($existing.url) (#$($existing.number))"
    Write-Host "PR_URL=$($existing.url)"
    exit 0
}

try {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $out = New-PrGh -b $Base -h $Head -t $Title -bd $Body
        $url = ($out | Select-String -Pattern 'https://github.com/\S+/pull/\d+' | ForEach-Object { $_.Matches.Value }) | Select-Object -First 1
        if (-not $url) { $url = (gh pr view --repo $Repo --json url -q .url 2>$null) }
        Write-Host "[create_pr] Created via gh: $url"
        Write-Host "PR_URL=$url"
        exit 0
    }
    if ($env:GITHUB_TOKEN) {
        $url = New-PrApi -b $Base -h $Head -t $Title -bd $Body
        Write-Host "[create_pr] Created via API: $url"
        Write-Host "PR_URL=$url"
        exit 0
    }
}
catch {
    Write-Warning "[create_pr] Auto-create failed: $_"
}

Write-Host "[create_pr] gh CLI and GITHUB_TOKEN unavailable. Open compare URL manually:"
Write-Host "COMPARE_URL=$compareUrl"
Write-Host ""
Write-Host "Install: winget install GitHub.cli"
Write-Host "Then: gh auth login"
exit 2
