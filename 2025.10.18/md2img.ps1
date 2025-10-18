param(
  [string]$InputDir = "",
  [string]$OutputDir = "",
  [int]$Width = 1200,
  [int]$Height = 8000
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $InputDir -or $InputDir -eq "") { $InputDir = Join-Path $scriptRoot "2025.10.18\Review" }
if (-not $OutputDir -or $OutputDir -eq "") { $OutputDir = Join-Path $scriptRoot "2025.10.18\ReviewImg" }

if (!(Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Escape-JsString([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace "\\", "\\\\"
  $s = $s -replace "`r", "\\r"
  $s = $s -replace "`n", "\\n"
  $s = $s -replace '"', '\\"'
  return $s
}

function Build-Html([string]$markdown) {
  $escaped = Escape-JsString $markdown
  $html = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Markdown Render</title>
  <link rel="preconnect" href="https://cdn.jsdelivr.net" />
  <style>
    :root { color-scheme: light; }
    html, body { height: auto; }
    body { margin: 0; background: #ffffff; }
    .page {
      box-sizing: border-box;
      width: 100%;
      max-width: 900px;
      margin: 40px auto;
      padding: 0 24px 60px;
      color: #111;
      font: 16px/1.6 "Segoe UI", Arial, Helvetica, sans-serif;
      word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 { margin: 1.2em 0 .6em; line-height: 1.25; }
    pre { background: #f6f8fa; padding: 12px; border-radius: 6px; overflow: auto; }
    code { font-family: Consolas, "Courier New", monospace; }
    blockquote { border-left: 4px solid #ddd; margin: 1em 0; padding: .2em 1em; color: #555; }
    table { border-collapse: collapse; }
    td, th { border: 1px solid #ddd; padding: 6px 10px; }
    img { max-width: 100%; }
    ul, ol { padding-left: 1.2em; }
  </style>
  <script>
    // Avoid animations/transitions impacting screenshot
    (function(){
      const style = document.createElement('style');
      style.textContent = '*{animation: none !important; transition: none !important}';
      document.head.appendChild(style);
    })();
  </script>
</head>
<body>
  <div class="page" id="app">Rendering...</div>
  <script src="https://cdn.jsdelivr.net/npm/showdown@2.1.0/dist/showdown.min.js"></script>
  <script>
    const md = "$escaped";
    const conv = new showdown.Converter({
      tables: true,
      strikethrough: true,
      tasklists: true,
      simpleLineBreaks: false,
      emoji: true
    });
    document.getElementById('app').innerHTML = conv.makeHtml(md);
  </script>
</body>
</html>
"@
  return $html
}

function Get-EdgePath {
  $candidates = @(
    (Get-Command msedge -ErrorAction SilentlyContinue)?.Source,
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
  if ($candidates.Count -eq 0) { throw "Microsoft Edge not found. Please install Edge or adjust the path." }
  return $candidates[0]
}

$edge = Get-EdgePath

$mdFiles = Get-ChildItem -LiteralPath $InputDir -Filter *.md -File | Sort-Object Name
if ($mdFiles.Count -eq 0) { Write-Host "No .md files found in $InputDir"; exit 0 }

foreach ($file in $mdFiles) {
  Write-Host "Converting $($file.Name)..."
  $markdown = Get-Content -LiteralPath $file.FullName -Raw
  $html = Build-Html -markdown $markdown
  $tmpHtml = Join-Path $env:TEMP ("md2img_" + [IO.Path]::GetFileNameWithoutExtension($file.Name) + ".html")
  Set-Content -LiteralPath $tmpHtml -Value $html -Encoding UTF8

  $outPng = Join-Path $OutputDir ([IO.Path]::GetFileNameWithoutExtension($file.Name) + ".png")
  $url = "file:///" + ($tmpHtml -replace "\\", "/")
  $args = @(
    "--headless=new",
    "--disable-gpu",
    "--hide-scrollbars",
    "--window-size=$Width,$Height",
    "--screenshot=$outPng",
    $url
  )

  $proc = Start-Process -FilePath $edge -ArgumentList $args -PassThru -WindowStyle Hidden
  $proc.WaitForExit()

  if (!(Test-Path -LiteralPath $outPng)) {
    Write-Error "Failed to create $outPng"
  } else {
    Write-Host "Saved: $outPng"
  }
}


