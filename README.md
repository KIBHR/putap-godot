# Put-Up by Yuichi Ago-san (吾郷裕一さん)

Originally published in MSX Magazine 1987-10
[MsxMagazine198710.pdf](https://archive.org/download/msx-magazine-1987/MSX%E3%83%9E%E3%82%AC%E3%82%B8%E3%83%B3%201987/MsxMagazine198710.pdf) (110MB)

https://archive.org/details/msx-magazine-1987

![image](https://github.com/svofski/potap/assets/6445874/70f6225f-d05b-457e-aad6-2e343b18e8b2)


Transcribed to Godot, hopefully close to the original.

Play it here: https://svofski.github.io/potap/

## Controls and game saves (Godot 4.7.2)

The Godot project in `godot/` includes a keyboard help screen (**H**),
manual **save (F5)** / **load (F9)**, and a title-screen choice to
**continue (C)** or **start a new game (Space/N)**. The save file
(`user://potap-save.json`) stores the complete current level state.
**Enter** toggles fullscreen, **Esc** exits, **P** pauses, and **M** toggles sound.
For gameplay, use **left/right or A/D**, **down or S**, and **Space** to jump.

**Web launch (macOS, Windows, Linux):** do not double-click
`docs/potap.html` or open it using `file://`; Godot needs an HTTP
server to load the game package and WebAssembly. Run
`bash play-web.sh` on macOS/Linux, or `play-web.bat` on Windows
(with Python 3 installed). Alternatively use
`python3 tools/serve_web.py` and visit
[http://127.0.0.1:8000/potap.html](http://127.0.0.1:8000/potap.html).
The `docs/` browser export is built automatically from the current
Godot source by GitHub Actions. See [Godot instructions](godot/README.md)
for export and local launch details.
