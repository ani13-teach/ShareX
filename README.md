# ShareX · 中文工具分支

基于 [ShareX/ShareX](https://github.com/ShareX/ShareX) 的个人维护分支，新增 **ShareX 21.0.0 portable x64 简体中文补丁工具**。应用主体来自上游，沿用 [GPL-3.0](LICENSE.txt)，具体来源与差异见 [UPSTREAM.md](UPSTREAM.md)。

## 中文补丁

工具位于 [Scripts/sharex-21-zh/](Scripts/sharex-21-zh/)，现有分发目录为 [package/](Scripts/sharex-21-zh/package/)。

1. 准备 **ShareX 21.0.0 portable x64**，退出正在运行的程序。
2. 将整个 `package/` 目录复制到 ShareX 程序目录之外，保留全部文件。
3. 运行“安装汉化.cmd”，按提示选择 ShareX 文件夹。
4. 需要撤销时，在同一补丁目录运行“恢复原版.cmd”。

补丁校验目标程序、编辑器和补丁文件的哈希，并保留原文件备份。它仅适用于上述版本；仓库中上游应用源码的版本独立变化，不能把这个补丁用于其他版本。

## 下载与上游

本仓库尚无 Release。ShareX 官方安装包见[上游 Releases](https://github.com/ShareX/ShareX/releases)，产品说明见 [getsharex.com](https://getsharex.com/)。这些链接属于上游，下载最新版时需另行核对补丁的版本要求。

ShareX 提供截图、屏幕录制、图片编辑、文件上传和自动任务；本分支的新增内容集中在中文补丁，相关问题在本仓库反馈。

## 开发

- [中文补丁使用说明](Scripts/sharex-21-zh/package/README.txt)
- [补丁执行脚本](Scripts/sharex-21-zh/package/Patch.ps1)
- [翻译表](Scripts/sharex-21-zh/translations.tsv)
- [补丁工程](Scripts/sharex-21-zh/Patcher/Patcher.csproj)

完整应用的目标框架与依赖见 [ShareX/ShareX.csproj](ShareX/ShareX.csproj)、[Directory.build.props](Directory.build.props) 和[上游构建流程](.github/workflows/build.yml)。

补丁生成脚本 `build_package.py` 使用维护机上的便携版、NuGet 缓存和翻译输入路径，换机生成前需按脚本检查这些位置；使用现有补丁无需运行生成脚本。

## 许可证与第三方组件

保留 ShareX Team 和其他贡献者的原有版权，根许可证为 [GNU GPL v3](LICENSE.txt)。中文工具随仓库使用同一授权。

补丁附带的 Mono.Cecil 0.11.6 使用 MIT 许可证，许可与源码入口见 [NOTICE](NOTICE)。上游其他依赖的许可保留在 [Licenses/](Licenses/)。
