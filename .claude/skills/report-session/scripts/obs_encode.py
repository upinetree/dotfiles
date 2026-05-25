#!/usr/bin/env python3
"""Encode a markdown file for the obsidian create content= parameter.

Obsidian CLI represents newlines as literal \n and requires " to be escaped.
Usage: obs_encode.py <file_path>
"""
import sys

if len(sys.argv) != 2:
    print("Usage: obs_encode.py <file_path>", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1]) as f:
    content = f.read()

encoded = (
    content
    .replace("\\", "\\\\")
    .replace('"', '\\"')
    .replace("\n", "\\n")
    .replace("\t", "\\t")
)
print(encoded, end="")
