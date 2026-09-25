<#
.SYNOPSIS
Automates GitHub cross-repo maintenance: topics, README status check, release creation.
#>

$ErrorActionPreference = 'Stop'

$tokenPath = Join-Path $HOME '.hermes\github_token'
if (-not (Test-Path $tokenPath)) {
    Write-Error "GitHub token not found at $tokenPath"
    exit 1
}
$token = (Get-Content $tokenPath -Raw).Trim()
$headers = @{
    Authorization = "token $token"
    Accept = 'application/vnd.github.v3+json'
    'User-Agent' = 'HermesAgent'
}

$repos = @(
    @{ owner = 'MdSadman20040812'; repo = 'bp-local-monitor'; topics = @('health','privacy','deterministic','agent-native','blood-pressure','local-first','python','no-cloud') }
    @{ owner = 'MdSadman20040812'; repo = 'HermesMobile'; topics = @('android','kotlin','compose','hermes','agent-native','mobile') }
    @{ owner = 'MdSadman20040812'; repo = 'SpellScroll'; topics = @('django','fastapi','langgraph','chromadb','webtoon','ai','pwa') }
    @{ owner = 'MdSadman20040812'; repo = 'Laura_AI'; topics = @('tauri','react','typescript','video-editing','ai','desktop') }
)

function Invoke-GitHub($method, $url, $body) {
    $params = @{
        Method = $method
        Uri = $url
        Headers = $headers
        ContentType = 'application/json'
    }
    if ($body) { $params.Body = ($body | ConvertTo-Json -Depth 10) }
    Invoke-RestMethod @params
}

foreach ($r in $repos) {
    $full = "$($r.owner)/$($r.repo)"
    Write-Host "[maint] $full"
    try {
        $current = Invoke-GitHub GET "https://api.github.com/repos/$full/topics"
        $existing = @($current.names)
        $desired = @($r.topics)
        $needsUpdate = $false
        if ($existing.Count -ne $desired.Count) {
            $needsUpdate = $true
        } else {
            foreach ($t in $desired) {
                if ($existing -notcontains $t) { $needsUpdate = $true; break }
            }
        }
        if ($needsUpdate) {
            Invoke-GitHub PUT "https://api.github.com/repos/$full/topics" @{ names = $desired }
            Write-Host "  topics updated -> $($desired -join ', ')"
        } else {
            Write-Host "  topics unchanged"
        }

        $readme = Invoke-GitHub GET "https://api.github.com/repos/$full/readme"
        if ($readme) {
            Write-Host "  readme size: $($readme.size) bytes"
        } else {
            Write-Host "  readme: missing"
        }
    } catch {
        Write-Warning "  failed: $_"
    }
}

Write-Host "[maint] done."
