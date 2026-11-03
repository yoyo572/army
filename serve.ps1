# Local static server for previewing the site: http://localhost:8765
param([string]$Root = $PSScriptRoot, [int]$Port = $(if ($env:PORT) { [int]$env:PORT } else { 8765 }))
$Root = [IO.Path]::GetFullPath($Root)
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css'; '.js' = 'text/javascript'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.svg' = 'image/svg+xml'
  '.m4a' = 'audio/mp4'; '.mp3' = 'audio/mpeg'; '.txt' = 'text/plain; charset=utf-8'
}
$l = New-Object Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "Serving $Root at http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext()
  try {
    $rel = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
    if (-not $rel) { $rel = 'index.html' }
    $p = [IO.Path]::GetFullPath((Join-Path $Root $rel))
    if ($p.StartsWith($Root) -and (Test-Path $p -PathType Leaf)) {
      $b = [IO.File]::ReadAllBytes($p)
      $ct = $types[[IO.Path]::GetExtension($p).ToLower()]
      if ($ct) { $c.Response.ContentType = $ct }
      $c.Response.Headers.Add('Cache-Control', 'no-cache')
      $c.Response.ContentLength64 = $b.Length
      $c.Response.OutputStream.Write($b, 0, $b.Length)
    } else { $c.Response.StatusCode = 404 }
  } catch { $c.Response.StatusCode = 500 }
  finally { $c.Response.Close() }
}
