# 开发与实现说明

本文记录实现细节与已有测试观察。入门与发布说明见仓库根目录 README.md。

## 当前版本

默认使用青简英文词表，共 232,213 个词条。桌面设置可选择青简、CC-CEDICT 及导入的自定义 TSV。覆盖优先级为：自定义 > 青简 > CC-CEDICT。`Lookup.ps1` 与 `Build-Wordlist.ps1` 默认仍只使用青简词表。

默认识别已切换为 **RapidOCR 3.9.2 / PP-OCRv5 mobile / ONNX Runtime CPU**。首次遇到需要识别的稳定候选时异步启动 Python OCR；120 秒没有候选输入后释放，下一次需要识别时自动重启。常用结果仍保留在最多 256 项的缓存中。只识别高亮候选的文字行，省略文本检测及方向分类；先裁剪文字、转换成白底黑字，再识别。当前置信度低于 0.80 时隐藏提示；这个阈值不是正确率保证。

双击 `dist\WeTypeCompanion\WeTypeCompanion.exe` 或 `Start.vbs` 启动。青绿渐变 WT 托盘图标支持右键「打开设置」「暂停识别」「退出」，双击也可打开设置。关闭设置窗口继续后台运行；重复启动会打开已运行实例的设置。浮窗仅显示英文释义，不接收键盘焦点，鼠标可穿透。

设置窗口使用随内容伸展的布局，窗口较小或字号较大时可滚动，避免词库选项与按钮重叠。在设置窗口及其对话框获得焦点期间，自动隐藏释义浮窗并暂停候选识别，避免干扰中文词语输入框的输入法组词；切换到其他应用后自动恢复识别（手动暂停时保持暂停）。

## 桌面程序与配置

便携包为 `dist\WeTypeCompanion-win-x64.zip`。解压**整个文件夹**后运行 `WeTypeCompanion.exe`，不要单独移动 EXE。包内附带 Python 3.12、OCR 依赖和模型，无需另装 Python；需要 Windows 自带的 .NET Framework 4.x，无需管理员权限。界面、词库、轮询、设置及在线更新均由 C# 主程序直接执行，不依赖 PowerShell 引擎；Python OCR 在独立子进程运行。PowerShell 仅用于开发构建和旧版调试脚本。

- **开机自启动**：勾选后「保存并应用」，写入当前用户的 Windows 登录启动项，以 `--background` 运行，仅显示托盘。取消勾选并保存会删除启动项。移动文件夹后需重新保存设置。
- **词库选择**：勾选后「保存并应用」，立即替换运行词库并清除缓存，无需重启。
- **重载本地词库**：重新读取所选文件，同时保存当前选择与自启动设置。
- **导入 TSV**：UTF-8，每行 `中文词语<Tab>英文释义`。验证通过后存入用户目录；再次导入替换上次导入的词库，并保留 `.bak` 备份。导入后需保存应用。
- **更新 CC-CEDICT**：主动联网从 MDBG 下载，在后台执行，验证至少 10 万条后原子替换；失败保留原文件。已启用时自动重载，否则需勾选启用。不会改变青简词表。
- **保存词条**：在设置中分别填写中文词语和英文释义，点击「保存词条」，直接写入正在运行程序目录中的 `glossary-en.tsv`，按 Unicode 码点排序，保留原词条及其他释义列，使用 UTF-8 无 BOM / LF 格式。已有词语拒绝覆盖；空白、Tab 和换行会被拒绝。写入前验证，原子替换并保留 `glossary-en.tsv.bak`；失败保留原文件。青简已启用时立即重载并清除缓存，否则提示启用青简。运行目录需要可写。
- **个人词库**：已移除选择和加载分支，旧配置中的 `Personal` 字段会被忽略，下次保存不再写入。仓库内旧 `personal.tsv` 仅保留作历史数据，不再加载或打包；如需其中词条，可通过新界面补入青简词表。
- **青简更新**：可将新版 TSV 作为自定义词库导入，或替换程序目录中的 `glossary-en.tsv` 后重载。替换或升级前应备份自己补充的词条，整表替换会覆盖这些改动。

配置、导入词库与在线下载词库保存在 `%LOCALAPPDATA%\WeTypeCompanion`。首次启动不启用自启动；配置损坏或所选文件丢失时会提示并暂用默认青简词库。未选词库或格式错误时拒绝应用，原运行词库继续有效。只有主动点击在线更新时联网。

重新生成便携包与验证配置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-App.ps1 -Zip
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Native.ps1
```

构建需已安装项目 `.venv` 和模型，使用 Windows 自带 .NET Framework 编译器。`-SkipRuntime` 可复用已生成的运行时；完整构建复制 Python 标准库及项目依赖，通过 `python312._pth` 隔离宿主 Python 配置。配置测试结束后恢复原启动项。

约 70 毫秒轮询、连续两帧稳定后提交识别。限制一个未完成请求，按窗口、图像指纹及版本丢弃过期结果，保存最多 256 个图像结果缓存；候选关闭时隐藏。缓存随程序退出清除。默认绿色样式、纯汉字候选适配保持不变，其他主题与混合文本仍需后续测试。

内存优化：运行时将词库的三个哈希索引压缩为排序词语数组、释义数组和每词一个字节的来源编号；仅加载所选词库。高亮检测复用最多 262,144 像素的缓冲区，避免每 70 毫秒分配大数组，更大截图不永久保留缓冲。OCR 按需启动并在空闲后退出。词库重载后回收被替换的索引，不在识别热路径强制 GC。2026-10-04 同机、隔离配置、启动约 10 秒的单次工作集快照：青简后台约 217 → 79 MB，OCR 加载时约 187 MB；CC-CEDICT 后台约 231 → 80 MB，OCR 加载时约 187 MB。OCR 两次冷启动约 0.60 / 0.74 秒。并非长期内存上限或泄漏测试；详见 `test-results/lightweight-memory.md`。

正常运行只读取本地模型与词表，不联网、不保存截图或输入日志。模型缺失会在首次需要识别时提示错误，先执行安装脚本。OCR 仍可能把一个词读成另一个词，词表精确匹配不能发现所有误读。

## 本次实测

同一批 **10 张真实候选截图**，原 Windows 流程正确输出 5/10，新流程 10/10。“速度”在原流程中为空，新流程识别为“速度”，现场显示 `n. speed`；“微信、违心”现场显示释义。已验证切换候选、Esc 隐藏、不抢记事本焦点；连续输入时记录到过期结果被丢弃。

热态处理时间：原流程各图中位数平均约 9.1 毫秒，新流程约 16.6 毫秒。新方案在这批样本中更准确，但不是更快的模型；异步处理和更短稳定等待改善了响应流程。这些数字不包括完整截图、界面轮询、查词、显示和启动。

样本量有限，未覆盖所有应用、缩放、主题和长句。详见 `test-results/recognition-comparison.md`。测试截图及人工核对标签在 `test-fixtures/live-v1`，五次重复仅用于计时，不计为五个独立正确率样本。

## 安装与开发

`.venv` 和模型不纳入 Git。新机器需 Python 3.12：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-Ocr.ps1 -Python 'C:\path\to\python.exe'
# 下载缓慢时可指定镜像
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-Ocr.ps1 -Python 'C:\path\to\python.exe' -IndexUrl 'https://pypi.tuna.tsinghua.edu.cn/simple'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Lexicon.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Wordlist.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '.\Lookup.ps1' -Word '速度','微信','违心','弯折'"
# 单张图，默认新引擎
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\companion.ps1 -TestImage .\test-fixtures\live-v1\速度.png
# 保留原 Windows 流程用于回退或对照
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\companion.ps1 -Engine Windows -TestImage .\test-fixtures\live-v1\速度.png -NoCorrections
# 重跑同批评估；先运行 Windows 脚本导出归一化图片
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Evaluate-WindowsOcr.ps1
.\.venv\Scripts\python.exe .\evaluate_rapid.py
# 调试运行（含输入记录，只在主动调试时启用）
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\companion.ps1 -Diagnostics -RunSeconds 60
```

修改青简词表后可在设置界面重载，也可以退出重启。`ocr-corrections.tsv` 仅在 Windows 回退流程使用，新引擎不靠这张人工纠错表输出结果。`-Diagnostics` 写入 `live-results.jsonl`，包含原文、词语、置信度、识别时间、请求返回时间、焦点及过期结果丢弃；正常启动不启用。

## 数据与许可

青简词表来源见 `glossary-source.md`，修订见 `qingjian-revision.txt`，遵循 GPL-3.0-or-later。释义由模型生成，未保证全部准确。本项目源码也以 GPL-3.0-or-later 提供，见 `LICENSE`。

RapidOCR / PP-OCR 模型的来源、版本和 SHA-256 见 `ocr-model-source.json`。上游项目与模型保留其许可，项目不将它们的许可改写为 GPL。CC-CEDICT 存档的署名与 CC-BY-SA-4.0 许可见 `data/README.md`。
