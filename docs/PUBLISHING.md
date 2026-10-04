# GitHub 发布检查清单

## 上传源码

1. 创建空仓库，建议名称 `wetype-companion`，描述可用「Windows 微信输入法本地英文释义伴侣，C# 托盘程序 + 本地 OCR」。创建时不要另外生成 README 或 LICENSE。
2. 检查 `git status --short` 与 `git diff --cached`，确认只发布源码、公开词表和固定候选测试图。
3. 提交本轮源码和发布文件后，配置远程并推送主分支：

```powershell
git remote add origin https://github.com/<你的用户名>/wetype-companion.git
git push -u origin main
```

`.venv/`、`models/`、`dist/`、个人词库、输入日志、备份和机器测试输出不应纳入 Git。历史版本曾包含 personal.tsv / personal-words.txt 的示例数据；忽略规则不会删除 Git 历史。本地这两个文件已从索引移除并保留在磁盘。上传前确认历史内容可公开。

## 构建与验证

完整命令见根目录 README.md。在干净检出上运行 Setup-Ocr.ps1，然后 Build-App.ps1 -Zip、Test-Lexicon.ps1 和 Test-Native.ps1。

Setup-Ocr.ps1 要求 Python 3.12 x64，使用 requirements-lock.txt 约束依赖，并核对下载模型的 SHA-256。Test-Native.ps1 会短暂设置当前用户的自启动注册表项，并在结束时恢复；测试输出保存在本地 test-results/。

GitHub Actions 在 push、pull request 及手动触发时执行 Windows 构建和回归测试。成功后下载名为 WeTypeCompanion-win-x64 的 artifact，解开外层 artifact ZIP，得到实际便携 ZIP 和 SHA-256 文件。CI 的产物构建于本次检出的源码；创建 Release 时应选择相同提交。

## 创建 Release

选定版本号并在对应提交创建 tag，附上功能、环境要求和已知限制，然后上传：

- `dist/WeTypeCompanion-win-x64.zip`
- `dist/WeTypeCompanion-win-x64.zip.sha256`

程序 ZIP 大于 100 MB，作为 Release 附件分发；不要提交到源码仓库。Release 需链接相应源码 tag，保留 LICENSE、词表来源、THIRD-PARTY-NOTICES.md、licenses/ 和运行时第三方许可。检查 ZIP 不含个人词库、日志、配置或开发机器绝对路径。

下载后校验：

```powershell
Get-FileHash .\WeTypeCompanion-win-x64.zip -Algorithm SHA256
Get-Content .\WeTypeCompanion-win-x64.zip.sha256
```

最后在新目录解压，启动并检查托盘、设置、候选释义、Esc 隐藏与退出。固定截图回归不替代实际输入法兼容性测试。
