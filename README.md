# 微信输入法本地译词伴侣

项目目录：`D:\User\My Files\Projects\wetype-companion`。Git 主分支为 `main`，没有配置远程仓库。旧聊天目录保留作备份，后续开发以本目录为准。

## 使用

双击 `Start.vbs`，加载本地词典后在通知区显示信息图标。右键图标 → Exit 退出。未设置开机启动。

识别微信输入法当前绿色高亮候选，查询完整词语，在候选栏旁只显示英文释义。浮窗不抢键盘焦点，鼠标可穿透；候选栏消失或查不到释义时隐藏。适配前次验证的 Windows 微信输入法 2.1.4.6 默认绿色样式，其他主题与版本需实测。

约 140 毫秒轮询，画面连续两次稳定后识别。首次 OCR 未命中时反色重试，并归一化全角数字和空格。`ocr-corrections.tsv` 保留已验证的“穹折→弯折”规则，仅在原识别词没有释义时应用。释义区域最大宽度 680 像素，长释义可能截断。

正常运行离线，截图仅在内存处理，不保存输入或日志。词典加载会增加启动时间。OCR 错字也可能恰好命中词表，仍需继续优化识别。

## 词典和词表

查询优先级：**个人释义 → 青简 → CC-CEDICT**。保持精确匹配，不自动把未知词替换成相似词。

- `glossary-en.tsv`：青简英文释义，232,213 个词形。原修订见 `qingjian-revision.txt`，来源见 `glossary-source.md`，遵循 GPL-3.0-or-later。青简释义由模型生成，未保证全部准确。
- `data/cedict.u8`：CC-CEDICT 原始离线中英词典，保留文件头，索引简体和繁体，合并重复词条，浮窗最多显示两条释义。数据遵循独立的 CC-BY-SA-4.0，来源和许可见 `data/README.md`；下载时间、记录数和 SHA-256 见 `data/cedict-source.json`。
- `personal.tsv`：UTF-8，格式为 `中文词<Tab>英文释义`，Tab 为实际制表符。优先覆盖其他词典；已补充“微信输入法、候选词、开阀”。编辑后退出重启。
- `personal-words.txt`：每行一个没有释义的词，仅加入词表，不显示译文。
- `data/wordlist.txt`：可重新生成的合并、去重、排序词表，用于后续识别评估；没有词频。程序内也维护同一词汇集合。

当前快照有 125,173 条 CC-CEDICT 原始记录，合并后共 365,073 个可查词形。这是词形数量，不是 OCR 准确率或常用词覆盖率。增大词表本身不会提高 Windows OCR 的识别率。

合并词表也包含数字和中英混合词形，`Lookup.ps1` 可查询它们；目前候选 OCR 仍只接受纯汉字词语，混合词的浮窗识别需要后续适配。

本项目源代码使用 GPL-3.0-or-later，见 `LICENSE`。各数据源保留原有许可；分发合并词表需保留其来源与许可信息。

## 开发命令

在项目目录使用 Windows PowerShell 5.1（脚本保存为 UTF-8 BOM）：

```powershell
# 导出词表和统计（派生文件不纳入 Git）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Wordlist.ps1
# 查看释义、来源和是否在词表中
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '.\Lookup.ps1' -Word '微信','违心','弯折','开阀'"
# 多来源查词测试
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Lexicon.ps1
# 主动联网更新词典；下载或内容校验失败保留旧词典
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Update-Cedict.ps1
# 离线截图 OCR 验证
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\companion.ps1 -TestImage .\test-fixtures\弯折.png
# 限时运行并记录诊断；记录含识别文本，仅调试时启用
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\companion.ps1 -Diagnostics -RunSeconds 60
```

`-Diagnostics` 写入 `live-results.jsonl`，包含 OCR 原文、尝试次数、查词来源、词表命中状态、耗时及焦点状态。`Status` 为 `matched`、`no-translation` 或 `ocr-empty`。这些状态帮助分析问题，但不能判断 OCR 是否把一个词误读成另一个已有词。正常启动不启用诊断。

## 文件与后续开发

`Native.cs` 负责限定候选窗口、截图、绿色区域定位、图像预处理与浮窗；`companion.ps1` 负责 OCR 和生命周期；`Lexicon.cs` / `lexicon.ps1` 负责多来源词典与词表；`Start.vbs` 隐藏控制台启动。

前次聊天已用记事本真实候选验证“开发”译文显示与不抢焦点；同字体测试图复现“弯折→穹折”，纠错后查到 `v. bend`。这些属于前次验证记录，本次词典合并并不能证明日常 OCR 准确率提升。

下一步先收集可复现的实际候选截图和人工正确文本，建立 OCR 评估集，再比较中文语言选择、预处理和替代识别引擎。先测量识别准确率及延迟，再选择方案。
