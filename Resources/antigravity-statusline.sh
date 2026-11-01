#!/bin/sh

# Antigravity sends the active conversation as JSON on stdin. MultiCoding supplies
# a per-terminal tab ID so multiple sessions in one workspace do not collide.
payload=$(/bin/cat)
tab_id=${MULTICODING_TAB_ID:-${OMUX_TAB_ID:-}}
dir="$HOME/Library/Application Support/MultiCoding/antigravity-conversations"
/bin/mkdir -p "$dir"
usage_tmp=$(/usr/bin/mktemp "$dir/.usage.XXXXXX") || exit 1
/usr/bin/printf '%s' "$payload" > "$usage_tmp"
/bin/mv -f "$usage_tmp" "$dir/usage.json"
if [ -n "$tab_id" ]; then
  conversation_id=$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys
try:
    value=json.load(sys.stdin).get("conversation_id", "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")')
  if [ -n "$conversation_id" ]; then
    id_tmp=$(/usr/bin/mktemp "$dir/.conversation.XXXXXX") || exit 1
    /usr/bin/printf '%s\n' "$conversation_id" > "$id_tmp"
    /bin/mv -f "$id_tmp" "$dir/$tab_id"
  fi
fi

# Keep the built-in status line visible when this collector is stacked below it.
