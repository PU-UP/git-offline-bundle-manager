# 设置目录路径
$localBundlesDir = "D:\Projects\tmp\local-bundles"
$normalBundlesDir = "D:\Projects\tmp\bundles"

# 确保目标目录存在
if (!(Test-Path $normalBundlesDir)) {
    New-Item -ItemType Directory -Path $normalBundlesDir | Out-Null
}

# 获取所有 local_ 前缀的 bundle 文件
Get-ChildItem -Path $localBundlesDir -Filter "local_*.bundle" | ForEach-Object {
    $src = $_.FullName
    # 去掉 local_时间戳_ 前缀
    if ($_.Name -match "^local_\d{8}_\d{6}_(.+)$") {
        $newName = $Matches[1]
        $dst = Join-Path $normalBundlesDir $newName
        Copy-Item $src $dst -Force
        Write-Host "已转换: $($_.Name) -> $newName"
    }
}