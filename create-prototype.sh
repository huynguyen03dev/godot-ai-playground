#!/bin/bash
# Create a new Godot prototype project with MCP addon symlinked

if [ -z "$1" ]; then
    echo "Usage: ./create-prototype.sh <project-name>"
    echo "Example: ./create-prototype.sh my-game-idea"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="/home/hazeruno/IT/workspace/godot/$PROJECT_NAME"
ADDON_SRC="/home/hazeruno/IT/workspace/godot/addons/godot_mcp"

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Directory $PROJECT_DIR already exists"
    exit 1
fi

echo "Creating prototype project: $PROJECT_NAME"
mkdir -p "$PROJECT_DIR/addons"
ln -s "$ADDON_SRC" "$PROJECT_DIR/addons/godot_mcp"

# Create project.godot
cat > "$PROJECT_DIR/project.godot" << 'PROJEOF'
; Engine Configuration File.

[application]

config/name="PROJECT_NAME_PLACEHOLDER"
config/features=PackedStringArray("4.3", "Mobile")

[rendering]

renderer/rendering_method="mobile"

[editor_plugins]

enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")
PROJEOF

sed -i "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/" "$PROJECT_DIR/project.godot"

echo ""
echo "Created: $PROJECT_DIR"
echo ""
echo "To start working on this prototype:"
echo "  cd $PROJECT_DIR"
echo "  xvfb-run -a --server-args='-screen 0 1280x720x24' \\"
echo "    /home/hazeruno/.local/bin/godot --editor --path ."
echo ""
echo "Or use the helper from the workspace root:"
echo "  ./start-godot-mcp.sh"
echo "  (then open $PROJECT_NAME in Godot's Project Manager)"
