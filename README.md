# 微信输入法本地译词伴侣

项目：`D:\User\My Files\Projects\wetype-companion`；Git 主分支 `main`，未配置远程仓库。

## 当前版本

按用户要求，运行时**只使用青简英文词表**，共 232,213 个词条。CC-CEDICT、个人释义及个人词汇文件保留供后续实验，但默认不加载。`Lookup.ps1` 与 `Build-Wordlist.ps1` 也使用青简词表。

默认识别已切换为 **RapidOCR 3.9.2 / PP-OCRv5 mobile / ONNX Runtime CPU**。模型在独立 Python 环境中常驻，识别任务在子进程执行。只识别高亮候选的文字行，省略文本检测及方向分类；先裁剪文字、转换成白底黑字，再识别。当前置信度低于 0.80 时隐藏提示；这个阈值不是正确率保证。

双击 `Start.vbs` 启动，右键托盘信息图标 → Exit 退出。浮窗仅显示英文释义，不接收键盘焦点，鼠标可穿透。没有开机启动。

约 70 毫秒轮询、连续两帧稳定后提交识别。限制一个未完成请求，按窗口、图像指纹及版本丢弃过期结果，保存最多 256 个图像结果缓存；候选关闭时隐藏。缓存随程序退出清除。默认绿色样式、纯汉字候选适配保持不变，其他主题与混合文本仍需后续测试。

正常运行只读取本地模型与词表，不联网、不保存截图或输入日志。模型缺失时报错，先执行安装脚本。OCR 仍可能把一个词读成另一个词，词表精确匹配不能发现所有误读。

## 本次实测

同一批 **10 张真实候选截图**，原 Windows 流程正确输出 5/10，新流程 10/10。“速度”在原流程中为空，新流程识别为“速度”，现场显示 `n. speed`；“微信、违心”现场显示释义。已验证切换候选、Esc 隐藏、不抢记事本焦点；连续输入时记录到过期结果被丢弃。

热态处理时间：原流程各图中位数平均约 9.1 毫秒，新流程约 16.6 毫秒。新方案在这批样本中更准确，但不是更快的模型；异步处理和更短稳定等待改善了响应流程。这些数字不包括完整截图、界面轮询、查词、显示和启动。

样本量有限，未覆盖所有应用、缩放、主题和长句。详见 `test-results/recognition-comparison.md`。测试截图及人工核对标签在 `test-fixtures/live-v1`，五次重复仅用于计时，不计为五个独立正确率样本。

## 安装与开发

当前机器的 `.venv` 和模型已安装；它们不纳入 Git。新机器需 Python 3.12：

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

修改青简词表后退出重启。`ocr-corrections.tsv` 仅在 Windows 回退流程使用，新引擎不靠这张人工纠错表输出结果。`-Diagnostics` 写入 `live-results.jsonl`，包含原文、词语、置信度、识别时间、请求返回时间、焦点及过期结果丢弃；正常启动不启用。

## 数据与许可

青简词表来源见 `glossary-source.md`，修订见 `qingjian-revision.txt`，遵循 GPL-3.0-or-later。释义由模型生成，未保证全部准确。本项目源码也以 GPL-3.0-or-later 提供，见 `LICENSE`。

RapidOCR / PP-OCR 模型的来源、版本和 SHA-256 见 `ocr-model-source.json`。上游项目与模型保留其许可，项目不将它们的许可改写为 GPL。CC-CEDICT 存档的署名与 CC-BY-SA-4.0 许可见 `data/README.md`。