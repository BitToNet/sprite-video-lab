# Windows 安装 Sprite Video Lab

这份说明面向 Windows 10/11 用户，目标是在本机安装并启动 `sprite-video-lab`。默认访问地址是：

```text
http://127.0.0.1:8894
```

建议先完成基础安装。基础安装支持本地视频/图片导入、抽帧、绿幕/纯色背景处理、导出 PNG/WebM。AI 抠图、CorridorKey、Real-ESRGAN 属于可选增强功能，基础功能跑通后再装。

## 1. 安装基础工具

打开 PowerShell，检查是否已有这些工具：

```powershell
python --version
git --version
ffmpeg -version
ffprobe -version
```

这些工具的用途：

- `python`：运行本地网页服务和图片处理逻辑。
- `git`：从 GitHub 下载项目。
- `ffmpeg` / `ffprobe`：读取视频、抽帧、导出 WebM。

如果缺少，可以用 `winget` 安装：

```powershell
winget install --id Python.Python.3.12 -e
winget install --id Git.Git -e
winget install --id Gyan.FFmpeg -e
```

装完后关闭 PowerShell，重新打开，再重新运行检查命令。这样可以让新的 PATH 环境变量生效。

## 2. 下载项目

选择一个安装目录，例如 D 盘：

```powershell
cd D:\
git clone https://github.com/sparklecatta-lang/sprite-video-lab.git
cd .\sprite-video-lab
```

如果没有 D 盘，可以放到用户目录：

```powershell
cd $HOME
git clone https://github.com/sparklecatta-lang/sprite-video-lab.git
cd .\sprite-video-lab
```

这一步会把项目完整下载到本机。后续所有命令都在 `sprite-video-lab` 目录里执行。

## 3. 检查项目状态

```powershell
git status --short
Get-Content VERSION -Encoding utf8
python --version
```

这些命令分别用于确认项目目录正确、查看当前版本、确认 Python 能被当前终端识别。刚克隆完时，`git status --short` 正常情况下没有输出。

## 4. 创建 Python 虚拟环境并安装依赖

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

`.venv` 是这个项目专用的 Python 环境，用来避免污染系统 Python。`requirements.txt` 目前主要安装 `Pillow`，用于图片处理。

验证服务代码是否能正常导入：

```powershell
.\.venv\Scripts\python.exe -m py_compile server.py
```

没有输出就表示通过。

## 5. 确认 ffmpeg 可用

运行：

```powershell
ffmpeg -version
ffprobe -version
```

如果都能输出版本号，说明没问题。

如果你是手动下载 ffmpeg，并且它不在系统 PATH 中，需要告诉程序 ffmpeg 所在目录。例如：

```powershell
$env:SPRITE_VIDEO_LAB_FFMPEG_DIR = "D:\ffmpeg\bin"
```

这个目录里必须同时有 `ffmpeg.exe` 和 `ffprobe.exe`。如果要永久保存这个配置：

```powershell
setx SPRITE_VIDEO_LAB_FFMPEG_DIR "D:\ffmpeg\bin"
```

然后重新打开 PowerShell。

## 6. 启动服务

推荐使用项目自带启动器：

```powershell
.\start_sprite_video_lab.bat
```

启动器会自动进入项目目录，设置默认地址 `127.0.0.1:8894`，尝试停止旧的同项目服务进程，启动本地 Python 服务，并自动打开浏览器页面。

也可以手动启动：

```powershell
.\.venv\Scripts\python.exe server.py --serve --host 127.0.0.1 --port 8894
```

手动启动时，PowerShell 窗口需要保持打开；关闭窗口服务也会停止。

## 7. 打开页面验证

浏览器打开：

```text
http://127.0.0.1:8894/
```

实验性线稿清理页：

```text
http://127.0.0.1:8894/app/line-cleaner-experiment.html
```

也可以用 PowerShell 验证：

```powershell
Invoke-WebRequest http://127.0.0.1:8894/ -UseBasicParsing -TimeoutSec 10
Get-NetTCPConnection -LocalPort 8894 -ErrorAction SilentlyContinue |
  Where-Object { $_.State -eq "Listen" }
```

第一条命令确认网页能返回，第二条命令确认 `8894` 端口正在监听。

## 8. 关闭服务

推荐使用项目自带关闭器：

```powershell
.\stop_sprite_video_lab.bat
```

它会查找当前项目的 `server.py` 进程，并停止正在监听 `8894` 的 Sprite Video Lab 服务，避免下次启动时端口被占用。

如果只是用手动命令启动，也可以直接在启动服务的窗口里按 `Ctrl + C`。

## 可选增强功能

### AI 抠图运行时

只有需要 BiRefNet、Luma 组合、CorridorKey 时才安装：

```powershell
.\setup_ai_runtime.bat
```

它会安装 PyTorch、transformers、timm 等 AI 依赖，配置 Hugging Face 模型缓存。有 Git 时会尝试下载 CorridorKey。第一次使用 AI 抠图模式时，模型会自动下载，耗时会比较久。

### Real-ESRGAN 线稿清理

如果要用 MAGIC 或实验性线稿清理里的 Real-ESRGAN，需要准备 `realesrgan-ncnn-vulkan`，并确保模型目录里有：

```text
realesrgan-x4plus-anime.param
realesrgan-x4plus-anime.bin
```

可以放在：

```text
tools\realesrgan-ncnn-vulkan\realesrgan-ncnn-vulkan.exe
```

或设置环境变量：

```powershell
$env:SPRITE_VIDEO_LAB_REALESRGAN_BIN = "D:\tools\realesrgan-ncnn-vulkan\realesrgan-ncnn-vulkan.exe"
$env:SPRITE_VIDEO_LAB_REALESRGAN_MODEL_DIR = "D:\tools\realesrgan-ncnn-vulkan\models"
```

## 测试清单

安装完成后，至少验证这些场景：

- `http://127.0.0.1:8894/` 能打开。
- 上传一张 PNG/JPG 图片能预览。
- 上传一个短视频时能读取视频信息。
- 绿幕/纯色抠图预览能生成结果。
- 能导出 frames 文件夹。
- 关闭服务后，`Get-NetTCPConnection -LocalPort 8894` 不再显示监听。
- 重新运行 `.\start_sprite_video_lab.bat` 后页面还能打开。

## 默认假设

- Windows 10/11。
- 使用 PowerShell 执行命令。
- Python 使用 3.10 或更高版本，支持 Python 3.13。
- 基础安装不默认安装 AI 运行时，避免下载大模型和 CUDA 依赖。
- 默认端口使用 `8894`，默认只监听本机 `127.0.0.1`。
