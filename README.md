# ReelPrompt

A local Apple Silicon app that analyzes video in shots and drafts recreation prompts with MLX and Huihui Qwen3-VL 32B. It exports prompt text, timestamped observations and reference frames. Audio is not analyzed. Model outputs and shot boundaries need review.

## Build from source

Requires an Apple Silicon Mac, macOS 14+, Xcode command-line tools, Python 3.12, substantial free disk space, and enough unified memory for the 32B model. On the development Mac the model used around 22 GB MLX memory; requirements vary with the video.

Run `python3.12 install.py` from this folder. This installs Python packages, builds a local app in your user Applications folder, and stores support files under `~/Library/Application Support/ReelPrompt`. Open ReelPrompt, open Settings, and click **Download Model**. The model download is approximately 19.6 GB. This source build is locally signed and is not notarized.

Processing is local and sets Hugging Face offline mode. The Settings download button connects to Hugging Face to retrieve the model. Reference frames and reports can contain sensitive source content and remain in the results folder.

The app uses [Huihui Qwen3-VL 32B MLX](https://huggingface.co/divinetribe/Huihui-Qwen3-VL-32B-Instruct-abliterated-4bit-mlx), [MLX-VLM](https://github.com/Neywa-Labs/mlx-vlm), and [PySceneDetect](https://github.com/Breakthrough/PySceneDetect). Each dependency and the model has its own license.

The installer and settings have not been tested on a second Mac. The `Release/` folder contains source for the self-contained release candidate and FFmpeg build details; the source installer described above builds the earlier source version, not that release candidate.
