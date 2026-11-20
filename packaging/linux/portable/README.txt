Human OS - Linux x86_64 portable folder

Run:   ./human_health_os
Needs: glibc 2.34 or newer, GTK 3 and the EGL, OpenGL ES 2 and GL libraries
       (libEGL.so.1, libGLESv2.so.2, libGL.so.1) that the engine loads at
       start. Debian/Ubuntu: sudo apt install libgtk-3-0 libegl1 libgles2 libgl1
       Fedora: sudo dnf install gtk3 libglvnd-egl libglvnd-gles libglvnd-glx
       Ubuntu 22.04+, Debian 12+, Fedora 35+.

portable_mode.json makes this a portable install: health data is kept only in
an encrypted vault in UserData/ beside the app, created and opened with your
passphrase; nothing is written before you create or unlock it, and nothing is
ever written in plain text. Not for clinical decisions. No network access.

Third-party notices: data/flutter_assets/NOTICES.Z
