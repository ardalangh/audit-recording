#!/usr/bin/env python3
"""Check SKILL.md frontmatter against the Agent Skills spec limits (agentskills.io/specification).

argument-hint is a Claude Code extension and is allowed here on purpose.
"""
import os
import re
import sys

ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools",
           "argument-hint"}

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    sys.exit("no frontmatter block")
fields, errors = {}, []
for line in m.group(1).splitlines():
    if not line.strip() or line.startswith(" "):
        continue
    key, _, value = line.partition(":")
    fields[key.strip()] = value.strip()

for key in fields:
    if key not in ALLOWED:
        errors.append(f"unexpected key: {key}")
name = fields.get("name", "")
if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name) or len(name) > 64:
    errors.append(f"bad name: {name!r}")
if name != os.path.basename(os.path.dirname(os.path.abspath(path))):
    errors.append("name does not match the skill folder")
desc = fields.get("description", "")
if not 1 <= len(desc) <= 1024:
    errors.append(f"description length {len(desc)} not in 1..1024")
comp = fields.get("compatibility")
if comp is not None and not 1 <= len(comp) <= 500:
    errors.append(f"compatibility length {len(comp)} not in 1..500")
if len(text.splitlines()) > 500:
    errors.append("SKILL.md is over 500 lines; move detail into references/")

if errors:
    sys.exit("frontmatter errors:\n  " + "\n  ".join(errors))
print(f"frontmatter ok: {name} ({len(desc)}-char description)")
