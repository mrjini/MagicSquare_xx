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

function Resolve-Gh {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "C:\Program Files\GitHub CLI\gh.exe",
        "$env:ProgramFiles\GitHub CLI\gh.exe",
        "$env:LocalAppData\Programs\GitHub CLI\gh.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Get-RepoOwner([string]$repo) {
    return ($repo -split "/", 2)[0]
}

function Get-ApiHeadRef([string]$repo, [string]$branch) {
    return "$(Get-RepoOwner $repo):$branch"
}

function Invoke-Gh {
    param(
        [string]$GhExe,
        [string[]]$GhArgs,
        [switch]$AllowFailure
    )
    $output = & $GhExe @GhArgs 2>&1
    if (-not $AllowFailure -and $LASTEXITCODE -ne 0) {
        $detail = ($output | Out-String).Trim()
        if ($detail) {
            throw $detail
        }
        throw "gh exited with code $LASTEXITCODE"
    }
    return $output
}

function Test-NoDiffMessage([string]$message) {
    return ($message -match "No commits between|nothing to compare|no commits")
}

function Test-AlreadyExistsMessage([string]$message) {
    return ($message -match "already exists|A pull request already exists")
}

function Get-ParentBranch([string]$branch) {
    switch ($branch) {
        "spec" { return "staging" }
        "staging" { return "main" }
        "main" { return $null }
        default { return "spec" }  # feature/*, chore/*, etc.
    }
}

function Find-ExistingPrGh {
    param([string]$GhExe, [string]$repo, [string]$base, [string]$branch)
    $json = Invoke-Gh -GhExe $GhExe -GhArgs @(
        "pr", "list",
        "--repo", $repo,
        "--base", $base,
        "--head", $branch,
        "--state", "open",
        "--json", "url,number"
    )
    if (-not $json) { return $null }
    $items = @($json | ConvertFrom-Json)
    if ($items.Count -gt 0) { return $items[0] }
    return $null
}

function Find-ExistingPrApi {
    param([string]$repo, [string]$base, [string]$branch)
    $token = $env:GITHUB_TOKEN
    if (-not $token) { return $null }

    $headRef = Get-ApiHeadRef -repo $repo -branch $branch
    $uri = "https://api.github.com/repos/$repo/pulls?state=open&base=$base&head=$([uri]::EscapeDataString($headRef))"
    $headers = @{
        Authorization          = "Bearer $token"
        Accept                 = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    try {
        $items = @(Invoke-RestMethod -Method Get -Uri $uri -Headers $headers)
        if ($items.Count -gt 0) {
            return @{ url = $items[0].html_url; number = $items[0].number }
        }
    }
    catch {
        Write-Verbose "[create_pr] Existing PR API lookup failed: $_"
    }
    return $null
}

function Find-ExistingPr {
    param([string]$GhExe, [string]$repo, [string]$base, [string]$branch)
    if ($GhExe) {
        try {
            $found = Find-ExistingPrGh -GhExe $GhExe -repo $repo -base $base -branch $branch
            if ($found) { return $found }
        }
        catch {
            Write-Verbose "[create_pr] Existing PR gh lookup failed: $_"
        }
    }
    return Find-ExistingPrApi -repo $repo -base $base -branch $branch
}

function New-PrGh {
    param([string]$GhExe, [string]$repo, [string]$base, [string]$branch, [string]$title, [string]$bodyText)
    try {
        Invoke-Gh -GhExe $GhExe -GhArgs @(
            "pr", "create",
            "--repo", $repo,
            "--base", $base,
            "--head", $branch,
            "--title", $title,
            "--body", $bodyText
        ) | Out-Null
    }
    catch {
        if (Test-AlreadyExistsMessage "$_") {
            $existing = Find-ExistingPrGh -GhExe $GhExe -repo $repo -base $base -branch $branch
            if ($existing) { return "$($existing.url)".Trim() }
        }
        if (Test-NoDiffMessage "$_") {
            throw "NO_DIFF: $_"
        }
        throw
    }

    $existing = Find-ExistingPrGh -GhExe $GhExe -repo $repo -base $base -branch $branch
    if (-not $existing) { throw "PR create finished but open PR was not found" }
    return "$($existing.url)".Trim()
}

function New-PrApi {
    param([string]$repo, [string]$base, [string]$branch, [string]$title, [string]$bodyText)
    $token = $env:GITHUB_TOKEN
    if (-not $token) { throw "GITHUB_TOKEN not set" }

    $uri = "https://api.github.com/repos/$repo/pulls"
    $payload = @{
        title = $title
        head  = $branch
        base  = $base
        body  = $bodyText
    } | ConvertTo-Json -Compress
    $headers = @{
        Authorization          = "Bearer $token"
        Accept                 = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $payload -ContentType "application/json; charset=utf-8"
        return $resp.html_url
    }
    catch {
        if (Test-AlreadyExistsMessage "$_") {
            $existing = Find-ExistingPrApi -repo $repo -base $base -branch $branch
            if ($existing) { return $existing.url }
        }
        if (Test-NoDiffMessage "$_") {
            throw "NO_DIFF: $_"
        }
        throw
    }
}

$GhExe = Resolve-Gh
if ($GhExe) {
    $ghDir = Split-Path $GhExe -Parent
    if ($env:Path -notlike "*$ghDir*") {
        $env:Path = "$ghDir;$env:Path"
    }
}

if (-not $Head) {
    $Head = git branch --show-current 2>$null
}
if (-not $Head) {
    Write-Error "Cannot detect current branch. Pass -Head."
}

$Base = Get-ParentBranch $Head
if (-not $Base) {
    Write-Host "[create_pr] Branch '$Head' is root (main). No PR created."
    exit 0
}

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

Write-Host "[create_pr] Head=$Head Parent(base)=$Base"

$existing = Find-ExistingPr -GhExe $GhExe -repo $Repo -base $Base -branch $Head
if ($existing) {
    Write-Host "[create_pr] Open PR already exists: $($existing.url) (#$($existing.number))"
    Write-Host "PR_URL=$($existing.url)"
    exit 0
}

$failures = @()

if ($GhExe) {
    try {
        $url = New-PrGh -GhExe $GhExe -repo $Repo -base $Base -branch $Head -title $Title -bodyText $Body
        Write-Host "[create_pr] Created via gh: $url"
        Write-Host "PR_URL=$url"
        exit 0
    }
    catch {
        if ("$_" -match "^NO_DIFF:") {
            Write-Host "[create_pr] No commits between '$Base' and '$Head'. Nothing to PR."
            exit 0
        }
        $failures += "gh: $_"
    }
}

if ($env:GITHUB_TOKEN) {
    try {
        $url = New-PrApi -repo $Repo -base $Base -branch $Head -title $Title -bodyText $Body
        Write-Host "[create_pr] Created via API: $url"
        Write-Host "PR_URL=$url"
        exit 0
    }
    catch {
        if ("$_" -match "^NO_DIFF:") {
            Write-Host "[create_pr] No commits between '$Base' and '$Head'. Nothing to PR."
            exit 0
        }
        $failures += "API: $_"
    }
}

if ($failures.Count -gt 0) {
    Write-Warning "[create_pr] Auto-create failed: $($failures -join '; ')"
}
elseif (-not $GhExe -and -not $env:GITHUB_TOKEN) {
    Write-Warning "[create_pr] gh CLI not found and GITHUB_TOKEN is not set."
}

Write-Host "[create_pr] Open compare URL manually:"
Write-Host "COMPARE_URL=$compareUrl"
Write-Host ""
Write-Host "Install: winget install GitHub.cli"
Write-Host "Then: gh auth login"
exit 2
