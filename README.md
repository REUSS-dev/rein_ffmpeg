# Lunar-tear video optimizer

This is a Lua helper script to re-encode your movie assets under assets/revision/0/resources using ffmpeg to save on loading times, bandwidth and disk space.

Original videos are big and poorly-encoded, thus it plummets game load times if playing on a remote server.

Game loading time is generally an important factor only for remote hosters, as if you host your server on your own machine and play on emulator/real device inside the same network, loading times will not significantly decrease for you after re-encoding.

# Prerequisites

* Populated and functional `lunar-tear` server
* `assetbundles/patch_listbin.py` script from [lunar-scripts](https://gitlab.com/walter-sparrow-group/lunar-scripts/-/blob/main/assetbundles/patch_listbin.py) repo
  * also python3
  * and `pip install protobuf`
* Lua runtime (5.1+)
  * Windows: https://github.com/rjpcomputing/luaforwindows/releases
  * Debian/Ubuntu: `sudo apt-get install lua5.1`
* ffmpeg
  * Windows: https://github.com/GyanD/codexffmpeg/releases
  * Debian/Ubuntu: `sudo apt-get install ffmpeg`

# Instructions

1. Download `optimize_videos.lua` and put it somewhere near the server repo (e.g. besides the lunar-tear repository folder)
2. Run `lua optimize_videos.lua --input lunar-tear/server/assets/revisions/0/resources`
3. Navigate through the program and wait until ffmpeg re-encode finishes.
4. Folder "encoded" should appear in the same directory as the script. It contains now re-encoded films. Copy the contents of this folder into lunar-tear/server/assets/revisions/0/resources with replace.
5. Patch list.bin using `python3 patch_listbin.py lunar-tear/server/assets/revisions/0/list.bin`. This step may be slow, especially on Windows. Windows defender may inhibit the work of the script, so you're better off disabling it while the script is running.
6. Profit!

# Utility flags

| Flag             | Default | Description                              |
| ---------------- | ------- | ---------------------------------------- |
| `--input`        | `.`     | Path to directory with videos to re-encode. Should point to `/revisions/0/resources`|
| `--output`       | `encoded` | Output folder, under which re-encoded files will be placed |
| `--skip-checks`  | `false`  | Skip ffmpeg availability check                    |
| `--verbose`    | `false`  | Display re-encoded files and commands used to encode them after the process finishes |