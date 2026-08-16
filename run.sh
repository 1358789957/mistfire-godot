#!/bin/bash
# Mistfire Sanctum / 雾火神殿
# OpenGL Compatibility + software GL (llvmpipe). Window 1280x720.
export DISPLAY="${DISPLAY:-:3}"
export LIBGL_ALWAYS_SOFTWARE=1
exec /workspace/godot/Godot_v4.7.1-stable_linux.x86_64 \
  --rendering-driver opengl3 \
  --audio-driver Dummy \
  --path /workspace/mistfire-godot \
  "$@"
