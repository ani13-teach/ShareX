# 上游与分支差异

- 上游：[ShareX/ShareX](https://github.com/ShareX/ShareX)，默认开发分支 `develop`。
- 许可证：[GNU GPL v3](LICENSE.txt)。ShareX Team 的版权与依赖许可原样保留。
- 本分支基线：[3f72c45589dcf8cece34b069039c1feec1aa9afd](https://github.com/ShareX/ShareX/commit/3f72c45589dcf8cece34b069039c1feec1aa9afd)。
- 本地新增：[a51519cf9ecb5aee6d5aeedc9c75aef295451818](https://github.com/ani13-teach/ShareX/commit/a51519cf9ecb5aee6d5aeedc9c75aef295451818)，完整修改日期与作者见该提交。

该次新增集中在 `Scripts/sharex-21-zh/`：翻译表、资源文本、补丁工程、哈希清单、安装与恢复脚本，以及随包 Mono.Cecil 和许可证。应用主体未在这次提交中修改。

补丁固定适配 ShareX 21.0.0 portable x64；`Directory.build.props` 中应用主体版本为另一条源码版本线。二者分别管理，不能互换适用版本。

本仓库保留上游历史与 GitHub fork 关系。中文补丁和本分支构建的问题在本仓库反馈，上游支持渠道负责其官方发行版。
