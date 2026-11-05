param(
    [ValidateSet('Install','Restore')][string]$Action = 'Install',
    [string]$TargetPath,
    [switch]$NoPause
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backupName = '.sharex-zh-backup'

function FileHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $script:utf8) }
function LanguageMatch([string]$Text) {
    $top = [regex]::Match($Text, '(?m)^[ \t]{2}"Language"[ \t]*:[ \t]*("(?:\\.|[^"\\])*"|-?\d+|null)')
    if ($top.Success) { return $top }
    return [regex]::Match($Text, '"Language"[ \t]*:[ \t]*("(?:\\.|[^"\\])*"|-?\d+|null)')
}
function SetLanguage([string]$Text, [string]$Token) {
    $match = LanguageMatch $Text
    if ($match.Success) {
        $value = $match.Groups[1]
        return $Text.Substring(0, $value.Index) + $Token + $Text.Substring($value.Index + $value.Length)
    }
    if ($Text -notmatch '^\s*\{') { throw '应用配置不是有效的 JSON 对象。' }
    $open = $Text.IndexOf('{') + 1
    $comma = if ($Text.Substring($open) -match '^\s*\}') { '' } else { ',' }
    return $Text.Insert($open, '"Language":' + $Token + $comma)
}
function CheckClosed([string]$Root) {
    foreach ($process in @(Get-Process -Name 'ShareX','ShareX.ImageEditor.App' -ErrorAction SilentlyContinue)) {
        $path = $process.Path
        if ($path -and [string]::Equals([IO.Path]::GetDirectoryName($path), $Root, [StringComparison]::OrdinalIgnoreCase)) {
            throw '请先从系统托盘彻底退出该目录中的 ShareX，并关闭图片编辑器，然后重新运行。'
        }
    }
}
function ResolveTarget {
    if ($script:TargetPath) { return [IO.Path]::GetFullPath($script:TargetPath).TrimEnd('\') }
    $candidates = @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), (Join-Path (Split-Path $PSScriptRoot -Parent) 'ShareX-21.0.0-portable-x64'))
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'ShareX.exe')) { return [IO.Path]::GetFullPath($candidate).TrimEnd('\') }
    }
    $answer = (Read-Host '请输入 ShareX 程序文件夹路径').Trim('"')
    if (-not $answer) { throw '未指定 ShareX 程序文件夹。' }
    return [IO.Path]::GetFullPath($answer).TrimEnd('\')
}

$exitCode = 0
try {
    $root = ResolveTarget
    if (-not (Test-Path -LiteralPath (Join-Path $root 'ShareX.exe'))) { throw '所选目录中没有 ShareX.exe。' }
    CheckClosed $root
    $dll = Join-Path $root 'ShareX.ImageEditor.dll'
    $backup = Join-Path $root $backupName
    $statePath = Join-Path $backup 'state.json'
    if ($Action -eq 'Restore') {
        if (-not (Test-Path -LiteralPath $statePath)) { throw '该目录中没有本汉化包的备份。' }
        $state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
        $saved = Join-Path $backup 'ShareX.ImageEditor.dll'
        if ((FileHash $saved) -ne $state.OriginalHash) { throw '原文件备份校验失败，未执行恢复。' }
        $currentHash = FileHash $dll
        if ($currentHash -ne $state.PatchedHash -and $currentHash -ne $state.OriginalHash) { throw '编辑器文件在汉化后已发生变化，未覆盖该文件。' }
        $config = Join-Path $root 'ShareX\ApplicationConfig.json'
        $configBefore = if (Test-Path -LiteralPath $config) { [IO.File]::ReadAllBytes($config) } else { $null }
        $originalWasInstalled = $currentHash -eq $state.PatchedHash
        $restoreLanguage = $state.OldLanguage
        $savedConfig = Join-Path $backup 'ApplicationConfig.json'
        if (Test-Path -LiteralPath $savedConfig) {
            $savedLanguage = LanguageMatch ([IO.File]::ReadAllText($savedConfig))
            if ($savedLanguage.Success) { $restoreLanguage = $savedLanguage.Groups[1].Value }
        }
        try {
            if ($configBefore) {
                $text = [IO.File]::ReadAllText($config)
                $currentLanguage = LanguageMatch $text
                if ($currentLanguage.Success -and $currentLanguage.Groups[1].Value -eq '"SimplifiedChinese"') {
                    if (-not $state.ConfigExisted -and $text.Trim() -eq '{"Language":"SimplifiedChinese"}') { Remove-Item -LiteralPath $config }
                    else { WriteText $config (SetLanguage $text $restoreLanguage) }
                }
            }
            Copy-Item -LiteralPath $saved -Destination $dll -Force
            if ((FileHash $dll) -ne $state.OriginalHash) { throw '恢复后校验失败。' }
        } catch {
            if ($null -ne $configBefore) { [IO.File]::WriteAllBytes($config, $configBefore) }
            throw
        }
        Remove-Item -LiteralPath $backup -Recurse -Force
        Write-Host '已恢复原版图片编辑器及原语言设置。' -ForegroundColor Green
    } else {
        $data = Join-Path $PSScriptRoot 'data'
        $manifest = [IO.File]::ReadAllText((Join-Path $data 'manifest.json')) | ConvertFrom-Json
        if ((FileHash (Join-Path $root 'ShareX.dll')) -ne $manifest.MainHash) { throw '主程序版本不匹配。本汉化包仅适用于 ShareX 21.0.0 portable x64。' }
        if (Test-Path -LiteralPath $statePath) {
            $state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
            if ((FileHash $dll) -eq $state.PatchedHash) {
                $config = Join-Path $root 'ShareX\ApplicationConfig.json'
                $language = $null
                if (Test-Path -LiteralPath $config) {
                    $text = [IO.File]::ReadAllText($config)
                    $language = LanguageMatch $text
                    $backupConfig = Join-Path $backup 'ApplicationConfig.json'
                    if (Test-Path -LiteralPath $backupConfig) {
                        $originalLanguage = LanguageMatch ([IO.File]::ReadAllText($backupConfig))
                        if ($originalLanguage.Success) { $state.OldLanguage = $originalLanguage.Groups[1].Value }
                    }
                    if (-not $language.Success -or $language.Groups[1].Value -ne '"SimplifiedChinese"') {
                        WriteText $config (SetLanguage $text '"SimplifiedChinese"')
                        Write-Host '已修复主程序语言设置，请重新启动 ShareX。' -ForegroundColor Green
                    }
                    WriteText $statePath ($state | ConvertTo-Json)
                }
                if ($null -ne $language -and $language.Success -and $language.Groups[1].Value -eq '"SimplifiedChinese"') { Write-Host '该目录已安装本汉化包。' -ForegroundColor Green }
            }
            else { throw '该目录已有汉化备份，请先恢复原版，再重新安装。' }
        } else {
            if (Test-Path -LiteralPath $backup) { throw '发现不完整的汉化备份，请先处理该目录后重试。' }
            if ((FileHash $dll) -ne $manifest.EditorHash) { throw '图片编辑器文件不匹配，未执行修改。' }
            if (-not (Test-Path -LiteralPath (Join-Path $root 'Portable'))) { throw '所选目录不是本汉化包支持的便携版目录。' }
            foreach ($resource in $manifest.Resources) {
                $resourcePath = Join-Path $root ('Languages\zh-CN\' + $resource.Name)
                if (-not (Test-Path -LiteralPath $resourcePath) -or (FileHash $resourcePath) -ne $resource.Hash) { throw ('简体中文资源缺失或版本不匹配：' + $resource.Name) }
            }
            if ((FileHash (Join-Path $data 'patch-entries.json')) -ne $manifest.EntriesHash) { throw '翻译文件校验失败。' }
            if ((FileHash (Join-Path $data 'PatchEngine.cs')) -ne $manifest.EngineHash) { throw '补丁程序校验失败。' }
            if ((FileHash (Join-Path $data 'Mono.Cecil.dll')) -ne $manifest.CecilHash) { throw '补丁组件校验失败。' }
            [void][Reflection.Assembly]::LoadFrom((Join-Path $data 'Mono.Cecil.dll'))
            Add-Type -Path (Join-Path $data 'PatchEngine.cs') -ReferencedAssemblies @((Join-Path $data 'Mono.Cecil.dll'), 'System.Core.dll')
            $entries = @([IO.File]::ReadAllText((Join-Path $data 'patch-entries.json')) | ConvertFrom-Json)
            $keys = [string[]]@($entries | ForEach-Object { $_.key })
            $sources = [string[]]@($entries | ForEach-Object { $_.source })
            $translations = [string[]]@($entries | ForEach-Object { $_.translation })
            $config = Join-Path $root 'ShareX\ApplicationConfig.json'
            $configExisted = Test-Path -LiteralPath $config
            $oldBytes = if ($configExisted) { [IO.File]::ReadAllBytes($config) } else { $null }
            $oldText = if ($configExisted) { [IO.File]::ReadAllText($config) } else { '{}' }
            [void]($oldText | ConvertFrom-Json)
            $language = LanguageMatch $oldText
            $oldLanguage = if ($language.Success) { $language.Groups[1].Value } else { '"Automatic"' }
            $newText = SetLanguage $oldText '"SimplifiedChinese"'
            [void]($newText | ConvertFrom-Json)
            $temporary = Join-Path $root ('.sharex-zh-' + [Guid]::NewGuid().ToString('N') + '.tmp')
            $changed = $false
            $madeBackup = $false
            try {
                $count = [ShareXChinesePatch]::Apply($dll, $temporary, $keys, $sources, $translations)
                if ($count -ne $manifest.EntryCount) { throw '翻译条目数量校验失败。' }
                CheckClosed $root
                [void][IO.Directory]::CreateDirectory($backup)
                $madeBackup = $true
                Copy-Item -LiteralPath $dll -Destination (Join-Path $backup 'ShareX.ImageEditor.dll')
                if ($configExisted) { [IO.File]::WriteAllBytes((Join-Path $backup 'ApplicationConfig.json'), $oldBytes) }
                $state = [ordered]@{ OriginalHash = $manifest.EditorHash; PatchedHash = FileHash $temporary; ConfigExisted = [bool]$configExisted; OldLanguage = $oldLanguage }
                WriteText $statePath ($state | ConvertTo-Json)
                $changed = $true
                Copy-Item -LiteralPath $temporary -Destination $dll -Force
                [void][IO.Directory]::CreateDirectory((Split-Path $config -Parent))
                WriteText $config $newText
                if ((FileHash $dll) -ne $state.PatchedHash) { throw '安装后文件校验失败。' }
                Write-Host ('汉化安装完成，已替换 ' + $count + ' 处界面文字。') -ForegroundColor Green
                Write-Host '请启动 ShareX。需要撤销时，运行“恢复原版.cmd”。'
            } catch {
                if ($changed) {
                    Copy-Item -LiteralPath (Join-Path $backup 'ShareX.ImageEditor.dll') -Destination $dll -Force
                    if ($configExisted) { [IO.File]::WriteAllBytes($config, $oldBytes) }
                    elseif (Test-Path -LiteralPath $config) { Remove-Item -LiteralPath $config }
                }
                if ($madeBackup -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Recurse -Force }
                throw
            } finally {
                if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
            }
        }
    }
} catch {
    Write-Host ('操作失败：' + $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
if (-not $NoPause) { [void](Read-Host '按回车键关闭') }
exit $exitCode
