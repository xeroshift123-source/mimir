param(
  [int]$Limit = 0,
  [int]$DelayMs = 250,
  [switch]$Overwrite,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$nikkeJsonPath = Join-Path $workspace 'assets\nikkes.json'
$outputDir = Join-Path $workspace 'assets\nikke_full'
$reportPath = Join-Path $outputDir 'sources.json'
$indexUrl = 'https://namu.wiki/w/%ED%8B%80:%EC%8A%B9%EB%A6%AC%EC%9D%98%20%EC%97%AC%EC%8B%A0:%20%EB%8B%88%EC%BC%80/%EB%8B%88%EC%BC%80%20%EC%9D%BC%EB%9E%8C'
$headers = @{
  'User-Agent' = 'Mozilla/5.0 (compatible; MimirAssetCollector/1.0)'
}
$imageHeaders = $headers.Clone()
$imageHeaders['Referer'] = 'https://namu.wiki/'

function Get-RemoteHtml([string]$Uri) {
  $lastError = $null
  foreach ($attempt in 1..3) {
    try {
      return (Invoke-WebRequest -Uri $Uri -Headers $headers -UseBasicParsing -TimeoutSec 30).Content
    }
    catch {
      $lastError = $_
      if ($attempt -lt 3) {
        Start-Sleep -Milliseconds (500 * $attempt)
      }
    }
  }
  throw $lastError
}

function Normalize-Name([string]$Value) {
  $decoded = [Net.WebUtility]::HtmlDecode($Value)
  $withoutTags = [regex]::Replace($decoded, '<[^>]+>', '')
  return (($withoutTags -replace '^\s*✦', '') -replace '\s', '').Trim()
}

function Get-Attribute([string]$Tag, [string]$Name) {
  $match = [regex]::Match(
    $Tag,
    ('\b{0}=["''](?<value>[^"'']*)["'']' -f [regex]::Escape($Name)),
    'IgnoreCase'
  )
  if ($match.Success) {
    return [Net.WebUtility]::HtmlDecode($match.Groups['value'].Value)
  }
  return $null
}

function Get-PlaceholderSize([string]$Tag) {
  $src = Get-Attribute $Tag 'src'
  if (-not $src -or -not $src.StartsWith('data:image/svg+xml;base64,')) {
    return $null
  }

  try {
    $base64 = $src.Substring('data:image/svg+xml;base64,'.Length)
    $svg = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
    $dimensions = [regex]::Match(
      $svg,
      'width="(?<width>\d+)" height="(?<height>\d+)"'
    )
    if ($dimensions.Success) {
      return [pscustomobject]@{
        width = [int]$dimensions.Groups['width'].Value
        height = [int]$dimensions.Groups['height'].Value
      }
    }
  }
  catch {
    return $null
  }
  return $null
}

function Get-FullImageCandidate(
  [string]$Html,
  [string]$ExpectedName,
  [string]$PreferredAlt
) {
  $seenUrls = @{}
  $tags = [regex]::Matches($Html, '<img\b[^>]*>', 'IgnoreCase').Value
  $candidates = [Collections.Generic.List[object]]::new()

  foreach ($tag in $tags) {
    $imageUrl = Get-Attribute $tag 'data-src'
    if (-not $imageUrl) {
      $imageUrl = Get-Attribute $tag 'src'
    }
    if (-not $imageUrl -or $imageUrl -notmatch '^//i\.namu\.wiki/i/.+\.webp$') {
      continue
    }

    $absoluteImageUrl = "https:$imageUrl"
    if ($seenUrls.ContainsKey($absoluteImageUrl)) {
      continue
    }
    $seenUrls[$absoluteImageUrl] = $true

    $size = Get-PlaceholderSize $tag
    if ($null -eq $size) {
      continue
    }

    $fileSize = Get-Attribute $tag 'data-filesize'
    $candidates.Add([pscustomobject]@{
      url = $absoluteImageUrl
      width = $size.width
      height = $size.height
      bytes = if ($fileSize -match '^\d+$') { [int]$fileSize } else { 0 }
      alt = Get-Attribute $tag 'alt'
    })
  }

  if ($PreferredAlt) {
    $normalizedPreferredAlt = Normalize-Name $PreferredAlt
    foreach ($candidate in $candidates) {
      if ((Normalize-Name $candidate.alt) -eq $normalizedPreferredAlt) {
        return $candidate
      }
    }
  }

  $normalizedExpectedName = Normalize-Name $ExpectedName
  if ($normalizedExpectedName.Length -ge 2) {
    foreach ($candidate in $candidates) {
      $aspectRatio = $candidate.height / [double]$candidate.width
      $normalizedAlt = Normalize-Name $candidate.alt
      $isRelated = $normalizedAlt.Length -ge 2 -and (
        $normalizedAlt.Contains($normalizedExpectedName) -or
        $normalizedExpectedName.Contains($normalizedAlt)
      )
      if (
        $isRelated -and
        $normalizedAlt -notmatch '니케-UI-' -and
        $candidate.width -ge 180 -and
        $candidate.height -ge 430 -and
        $aspectRatio -ge 0.8
      ) {
        return $candidate
      }
    }
  }

  foreach ($candidate in $candidates) {
    $aspectRatio = $candidate.height / [double]$candidate.width
    if ($candidate.width -ge 300 -and $candidate.height -ge 650 -and $aspectRatio -ge 1.15) {
      return $candidate
    }
  }

  return $null
}

function Test-WebP([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return $false
  }
  $stream = [IO.File]::OpenRead($Path)
  try {
    if ($stream.Length -lt 12) {
      return $false
    }
    $header = New-Object byte[] 12
    [void]$stream.Read($header, 0, 12)
    $riff = [Text.Encoding]::ASCII.GetString($header, 0, 4)
    $webp = [Text.Encoding]::ASCII.GetString($header, 8, 4)
    return $riff -eq 'RIFF' -and $webp -eq 'WEBP'
  }
  finally {
    $stream.Dispose()
  }
}

$resolvedOutput = [IO.Path]::GetFullPath($outputDir)
if (-not $resolvedOutput.StartsWith($workspace, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Output directory resolved outside the workspace.'
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

Write-Output 'Loading Nikke index...'
$indexHtml = Get-RemoteHtml $indexUrl
$anchors = [regex]::Matches(
  $indexHtml,
  '<a\b[^>]*href=["''](?<href>[^"'']+)["''][^>]*>(?<body>.*?)</a>',
  'IgnoreCase,Singleline'
)
Write-Output ("Index HTML: {0} chars, anchors: {1}" -f $indexHtml.Length, $anchors.Count)

$rawPageLinks = @(
  foreach ($anchor in $anchors) {
    $href = [Net.WebUtility]::HtmlDecode($anchor.Groups['href'].Value)
    if ($href -notlike '/w/*') {
      continue
    }
    $text = Normalize-Name ($anchor.Groups['body'].Value)
    if ($text) {
      [pscustomobject]@{ href = [Uri]::UnescapeDataString($href); text = $text }
    }
  }
)
$pageLinks = @($rawPageLinks | Sort-Object href -Unique)
Write-Output ("Resolved page links: {0}" -f $pageLinks.Count)

$overrides = @{
  'sakura' = '/w/사쿠라(승리의 여신: 니케)'
  'sakura(eva)' = '/w/스즈하라 사쿠라(승리의 여신: 니케)'
  'makoto' = '/w/니지마 마코토(승리의 여신: 니케)'
  'yukiko' = '/w/아마기 유키코(승리의 여신: 니케)'
}
$preferredImageAlts = @{
  'dorothy' = '니케도로시평상시'
  'scarlet' = 'NIKKE-DB c472 fb...'
  'a2' = 'A2 (YoRHa Unoffi...'
}
$excludedIds = @{
  # These pages currently expose only opaque cutscenes, not transparent full art.
  'biscuit' = $true
  'isabel' = $true
  'kilo' = $true
  'snow_crane' = $true
}

$nikkes = Get-Content -Raw -LiteralPath $nikkeJsonPath | ConvertFrom-Json
$reports = [Collections.Generic.List[object]]::new()
$previousReports = @{}
if (Test-Path -LiteralPath $reportPath) {
  foreach ($item in (Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json)) {
    $previousReports[$item.id] = $item
  }
}
$processed = 0
$total = $nikkes.Count

foreach ($nikke in $nikkes) {
  if ($Limit -gt 0 -and $processed -ge $Limit) {
    break
  }
  $processed++
  $prefix = ('[{0}/{1}] {2}' -f $processed, $(if ($Limit -gt 0) { [Math]::Min($Limit, $total) } else { $total }), $nikke.id)
  $destination = Join-Path $resolvedOutput ("{0}.webp" -f $nikke.id)

  if ($excludedIds.ContainsKey($nikke.id)) {
    Write-Output "$prefix - no transparent full image"
    $reports.Add([pscustomobject]@{
      id = $nikke.id; name = $nikke.name; status = 'no_candidate'; pageUrl = $null
      imageUrl = $null; width = 0; height = 0; bytes = 0; alt = $null
    })
    continue
  }

  $href = $overrides[$nikke.id]
  if (-not $href) {
    $normalizedName = Normalize-Name ($nikke.name)
    $matches = @($pageLinks | Where-Object { $_.text -eq $normalizedName })
    if ($matches.Count -eq 1) {
      $href = $matches[0].href
    }
  }

  if (-not $href) {
    Write-Output "$prefix - no page mapping"
    $reports.Add([pscustomobject]@{
      id = $nikke.id; name = $nikke.name; status = 'unmapped'; pageUrl = $null
      imageUrl = $null; width = 0; height = 0; bytes = 0; alt = $null
    })
    continue
  }

  $pageUrl = [Uri]::new([Uri]'https://namu.wiki', $href).AbsoluteUri
  if ((Test-Path -LiteralPath $destination) -and -not $Overwrite -and -not $DryRun) {
    Write-Output "$prefix - existing"
    if ($previousReports.ContainsKey($nikke.id)) {
      $reports.Add($previousReports[$nikke.id])
    }
    else {
      $reports.Add([pscustomobject]@{
        id = $nikke.id; name = $nikke.name; status = 'existing'; pageUrl = $pageUrl
        imageUrl = $null; width = 0; height = 0
        bytes = (Get-Item -LiteralPath $destination).Length; alt = $null
      })
    }
    continue
  }

  try {
    $pageHtml = Get-RemoteHtml $pageUrl
    $candidate = Get-FullImageCandidate $pageHtml $nikke.name $preferredImageAlts[$nikke.id]
    if ($null -eq $candidate) {
      Write-Output "$prefix - no full image candidate"
      $reports.Add([pscustomobject]@{
        id = $nikke.id; name = $nikke.name; status = 'no_candidate'; pageUrl = $pageUrl
        imageUrl = $null; width = 0; height = 0; bytes = 0; alt = $null
      })
      continue
    }

    if ($DryRun) {
      Write-Output ("$prefix - candidate {0}x{1}" -f $candidate.width, $candidate.height)
      $status = 'candidate'
      $actualBytes = $candidate.bytes
    }
    else {
      $partialPath = "$destination.part"
      try {
        Invoke-WebRequest -Uri $candidate.url -Headers $imageHeaders -UseBasicParsing -TimeoutSec 30 -OutFile $partialPath
        if (-not (Test-WebP $partialPath)) {
          throw 'Downloaded file is not a valid WebP container.'
        }
        Move-Item -LiteralPath $partialPath -Destination $destination -Force
      }
      finally {
        if (Test-Path -LiteralPath $partialPath) {
          Remove-Item -LiteralPath $partialPath -Force
        }
      }
      $actualBytes = (Get-Item -LiteralPath $destination).Length
      $status = 'downloaded'
      Write-Output ("$prefix - downloaded {0}x{1}, {2} bytes" -f $candidate.width, $candidate.height, $actualBytes)
    }

    $reports.Add([pscustomobject]@{
      id = $nikke.id; name = $nikke.name; status = $status; pageUrl = $pageUrl
      imageUrl = $candidate.url; width = $candidate.width; height = $candidate.height
      bytes = $actualBytes; alt = $candidate.alt
    })
  }
  catch {
    Write-Output "$prefix - error: $($_.Exception.Message)"
    $reports.Add([pscustomobject]@{
      id = $nikke.id; name = $nikke.name; status = 'error'; pageUrl = $pageUrl
      imageUrl = $null; width = 0; height = 0; bytes = 0; alt = $null
      error = $_.Exception.Message
    })
  }

  if ($DelayMs -gt 0) {
    Start-Sleep -Milliseconds $DelayMs
  }
}

if (-not $DryRun) {
  $reports | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding utf8
}

$summary = $reports | Group-Object status | Sort-Object Name
Write-Output ''
Write-Output 'Summary'
$summary | ForEach-Object { Write-Output ("  {0}: {1}" -f $_.Name, $_.Count) }
