"""Build JavaScript for heading-level edits via ``obsidian eval``."""

from __future__ import annotations

import json

# The JS template uses Obsidian's app.vault API to read/modify files.
# Parameters are passed as a JSON blob to avoid escaping issues.
_JS_TEMPLATE = r"""(async () => {
const p = JSON.parse(__PARAMS__);
const file = app.vault.getAbstractFileByPath(p.filepath);
if (!file) throw new Error("File not found: " + p.filepath);
const text = await app.vault.read(file);
const lines = text.split("\n");
const hRe = /^(#{1,6})\s+(.+)$/;
let hStart = -1, hLevel = 0, sEnd = lines.length;
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(hRe);
  if (m) {
    if (hStart === -1 && m[2].trim() === p.heading) {
      hStart = i; hLevel = m[1].length;
    } else if (hStart !== -1 && m[1].length <= hLevel) {
      sEnd = i; break;
    }
  }
}
if (hStart === -1) throw new Error("Heading not found: " + p.heading);
let nl;
if (p.operation === "replace") {
  nl = [...lines.slice(0, hStart + 1), p.content, ...lines.slice(sEnd)];
} else if (p.operation === "append") {
  nl = [...lines.slice(0, sEnd), p.content, ...lines.slice(sEnd)];
} else if (p.operation === "prepend") {
  nl = [...lines.slice(0, hStart + 1), p.content, ...lines.slice(hStart + 1)];
} else {
  throw new Error("Unknown operation: " + p.operation);
}
await app.vault.modify(file, nl.join("\n"));
return "OK";
})()"""


def build_heading_patch_js(
    filepath: str,
    heading: str,
    operation: str,
    content: str,
) -> str:
    """Return JavaScript code that patches a section under *heading*.

    Operations:
        replace – replace all content between the heading and the next
                  heading of equal or higher level.
        append  – insert *content* just before the next heading (end of section).
        prepend – insert *content* right after the heading line.
    """
    params_json = json.dumps(
        {
            "filepath": filepath,
            "heading": heading,
            "operation": operation,
            "content": content,
        },
        ensure_ascii=False,
    )
    # json.dumps the JSON string again to produce a safely-escaped JS string literal
    return _JS_TEMPLATE.replace("__PARAMS__", json.dumps(params_json))
