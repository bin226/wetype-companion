# 微信输入法本地译词伴侣 · WeType Companion

Windows 桌面小工具：识别微信输入法当前高亮的中文候选，在旁边显示英文释义。适合输入中文时顺手查看英文表达。

这是独立的社区项目，与微信输入法及腾讯无隶属关系。

## 功能

- 释义浮窗不抢键盘焦点，支持鼠标穿透；候选关闭后自动隐藏。
- C# 托盘程序，支持设置、自启动、暂停识别和重复启动打开设置。
- 默认青简英文词表；可选择 CC-CEDICT、导入自定义 TSV，优先级为自定义 > 青简 > CC-CEDICT。
- 支持向青简词表补充词条，写入前校验并保留备份。
- RapidOCR / PP-OCRv5 mobile 在本机 CPU 上运行；按需启动，空闲 120 秒后释放 OCR 子进程。

## 使用便携包

运行环境：**Windows x64、.NET Framework 4.x**。当前验证环境为微信输入法 2.1.4.6 的默认绿色候选样式；其他版本、主题和缩放的兼容性还需要更多测试。

1. 在本仓库的 Releases 页面下载 `WeTypeCompanion-win-x64.zip`（发布后可用）。
2. 将整个文件夹解压到当前用户可写的目录，运行 `WeTypeCompanion.exe`。不要单独移动 EXE。
3. 打开微信输入法输入中文；高亮候选有匹配释义时，旁边会显示英文。
4. 右键托盘图标打开设置、暂停识别或退出。关闭设置窗口会继续后台运行。

便携包包含 Python 3.12、OCR 依赖和模型，无需另装 Python。配置、导入词库与下载的 CC-CEDICT 保存在 `%LOCALAPPDATA%\WeTypeCompanion`。开机自启动默认关闭；移动程序目录后需重新保存自启动设置。

添加词条会修改程序目录中的 `glossary-en.tsv` 并生成 `.bak` 备份。升级或替换整张词表前，请备份自己的修改。自定义 TSV 使用 UTF-8，每行 `中文词语<Tab>英文释义`。

## 隐私与限制

正常运行只在本机处理候选截图，不上传图片，不保存输入日志。桌面程序只有主动点击更新 CC-CEDICT 时联网；开发安装会下载依赖及模型。调试脚本的 `-Diagnostics` 会记录识别文本，相关日志已排除在 Git 之外。

只针对高亮候选的文字行进行 OCR，当前过滤器接受纯汉字词。置信度低于 0.80 或词库未命中时不显示释义。OCR 可能把一个词读成另一个词；释义也可能有误。10 张固定真实截图的回归测试通过，不代表总体识别准确率；[识别对照记录](test-results/recognition-comparison.md)说明了样本和局限。

## 从源码构建

需要 Windows x64、Windows PowerShell 5.1、.NET Framework 4.x 编译器及 **Python 3.12 x64**。

```powershell
# 在仓库根目录执行，将 Python 路径替换为自己的安装路径
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-Ocr.ps1 -Python 'C:\path\to\python.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-App.ps1 -Zip
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Lexicon.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Native.ps1
```

输出位于 `dist/WeTypeCompanion/`，ZIP 和 SHA-256 校验文件位于 `dist/`。首次构建会复制 Python 标准库、项目依赖及本地模型；`-SkipRuntime` 仅用于复用已有的完整运行时。运行 `Start.vbs` 可启动本地构建；没有构建产物时会使用旧 PowerShell 调试入口。

[开发与实现说明](docs/DEVELOPMENT.md)包含命令行查词、旧 Windows OCR 对照及配置行为。[发布检查清单](docs/PUBLISHING.md)说明源码、便携包和校验文件的发布步骤。GitHub Actions 会在 Windows 上构建、运行回归测试并保存便携包；它不会自动创建公开 Release。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `Launcher.cs`、`CompanionApplication.cs`、`AppUI.cs` | 程序入口、配置、托盘和设置界面 |
| `Native.cs`、`Lexicon.cs` | 候选捕获、浮窗、词库索引 |
| `ocr_worker.py`、`requirements*.txt` | 本地 OCR 子进程与依赖版本 |
| `Build-App.ps1`、`Setup-Ocr.ps1` | 构建便携包与安装开发依赖 |
| `Test-*.ps1`、`NativeTests.cs`、`test-fixtures/` | 回归测试与候选截图样本 |
| `glossary-en.tsv`、`data/` | 青简词表与 CC-CEDICT 数据及来源 |
| `docs/`、`test-results/*.md` | 开发文档与测试记录 |

## 许可与来源

项目源码和青简词表使用 **GPL-3.0-or-later**，见 [LICENSE](LICENSE)、[青简上游说明](glossary-source.md)和 `qingjian-revision.txt`。青简释义由模型生成，未经全部人工校对。

CC-CEDICT 保持自己的 CC-BY-SA-4.0 许可和贡献者署名，见 [data/README.md](data/README.md)。OCR 模型来源、版本和哈希见 [ocr-model-source.json](ocr-model-source.json)。随包的 Python 和第三方组件保留各自许可，见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
