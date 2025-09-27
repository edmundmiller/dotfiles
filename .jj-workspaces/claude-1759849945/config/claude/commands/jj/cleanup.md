---
allowed-tools: Bash(jj workspace:*), Bash(jj log:*), Bash(jj abandon:*)
description: Remove empty or stale workspaces
model: claude-sonnet-4-20250514
---

!# Cleanup empty workspaces

# Find all workspaces
workspaces=$(jj workspace list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo "")

if [ -z "$workspaces" ]; then
  echo "ℹ️  No workspaces found"
  exit 0
fi

echo "🧹 **Checking workspaces for cleanup...**"
echo ""

cleaned=0
kept=0

while IFS= read -r ws_name; do
  # Skip default workspace
  if [ "$ws_name" = "default" ]; then
    continue
  fi

  # Get change for this workspace
  change=$(jj log -r "$ws_name@" -T '{change_id.short()}' --no-graph 2>/dev/null || echo "")

  if [ -z "$change" ]; then
    echo "⏭️  Skipping $ws_name (no change found)"
    continue
  fi

  # Check if workspace change is empty
  is_empty=$(jj log -r "$ws_name@" -T '{if(empty(), "yes", "no")}' --no-graph 2>/dev/null || echo "no")

  if [ "$is_empty" = "yes" ]; then
    echo "🗑️  Removing empty workspace: **$ws_name**"
    jj abandon -r "$ws_name@" 2>/dev/null || true
    jj workspace forget "$ws_name" 2>/dev/null || true
    cleaned=$((cleaned + 1))
  else
    echo "✅ Keeping workspace with changes: **$ws_name**"
    kept=$((kept + 1))
  fi
done <<< "$workspaces"

echo ""
echo "---"
echo ""
echo "**Cleanup complete**"
echo "- Removed: $cleaned empty workspaces"
echo "- Kept: $kept workspaces with changes"

if [ $kept -gt 0 ]; then
  echo ""
  echo "**Active workspaces:**"
  jj workspace list | tail -n +2
fi
