# GitHub 发布准备验证（2026-10-04）

本地验证通过：

- Windows PowerShell 5.1 完整构建便携运行时；重新打包后核对 ZIP 的 EXE、Python、模型和许可文件。
- Test-Lexicon.ps1：词库优先级、来源、简繁体、重复释义、非法输入与生产数据。
- Test-Native.ps1：实际 C# EXE，完整压缩词库查词等价性、词条写入/备份/失败回滚、配置和自启动恢复、异步 OCR 空闲释放与重启、过期结果丢弃，以及设置界面布局。
- 同一组 10 张真实候选截图在 OCR 重启前后均识别并查词成功。
- pip check 无依赖冲突；按锁定版本执行 pip install --dry-run --ignore-installed，可解析并下载所有所需依赖，不修改已安装环境。
- 全部 PowerShell 源文件语法通过；Git 差异无空白错误；工作流 YAML、触发事件和只读仓库权限检查通过。
- 模型哈希符合 ocr-model-source.json；ZIP 哈希符合随包 SHA-256 文件。
- ZIP 排除个人词库、配置、日志及旧备份；本地个人文件和词表备份仍保留。

本记录为首次上传前的本地验证快照。GitHub 云端构建结果见 https://github.com/bin226/wetype-companion/actions 。本轮未重新执行持续输入、长期内存或其他输入法主题/版本兼容性测试；本地测试通过不代表这些场景已验证。

源码已提交并上传至公开仓库 https://github.com/bin226/wetype-companion 。Git 远程为 origin，主分支为 main；tag 和 Release 单独管理。个人示例词库仅在本地保留，当前提交不再跟踪。
