#!ussr/bin/env python3
# -*- coding: utf-8 -*-

import sys

try:
    from googlesearch import search
except ImportError:
    print("\033[91m[ERROR] Missing dependency: googlesearch-python\033[0m")
    print("\033[93m[INFO] Install it using: pip install googlesearch-python\033[0m")
    sys.exit(1)

# Check for Python version
if sys.version_info[0] < 3:
    print("\n\033[91m[ERROR] This script requires Python 3.x\033[0m\n")
    sys.exit(1)

# ANSI color codes for styling output
class Colors:
    RED = "\033[91m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RESET = "\033[0m"

