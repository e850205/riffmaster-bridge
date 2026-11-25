#!/bin/sh
cd "$(dirname "$0")"
DYLD_LIBRARY_PATH=/opt/homebrew/lib exec .venv/bin/python -I riffmaster_bridge.py
