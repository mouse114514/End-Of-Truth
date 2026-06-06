#!/usr/bin/env python3
"""Convert old attack patterns to new emitter format in timelines.json"""

import json
import os

file_path = r"D:\GODOT\Project\au\timelines.json"

# Read the JSON file
print(f"Reading {file_path}...")
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Parse JSON
timelines = json.loads(content)

conversion_count = 0

# Process each timeline
for timeline_name in timelines:
    timeline = timelines[timeline_name]

    for tick_entry in timeline:
        new_actions = []

        for action in tick_entry['actions']:
            action_type = action.get('type', '')

            if action_type in ['att_circle', 'att_spiral', 'att_aimed', 'att_random']:
                conversion_count += 1

                # Get the positions
                positions = action.get('pos', [])

                # Determine target_pos and tags based on type
                if action_type == 'att_circle':
                    target_pos = [0, -200]
                    tags = ["圆"]
                elif action_type == 'att_spiral':
                    target_pos = [0, -200]
                    tags = ["圆", "螺旋"]
                elif action_type == 'att_aimed':
                    target_pos = [0, 300]
                    tags = []
                elif action_type == 'att_random':
                    target_pos = [0, 200]
                    tags = []

                # Create emit action for each position
                for pos in positions:
                    emit_action = {
                        'type': 'emit',
                        'emitter_pos': [pos[0], pos[1]],
                        'target_pos': target_pos,
                        'tags': tags
                    }
                    new_actions.append(emit_action)
            else:
                # Keep non-attack actions as is
                new_actions.append(action)

        # Replace actions
        tick_entry['actions'] = new_actions

# Write the updated JSON back with same formatting (tabs)
print("Writing updated JSON...")

# Custom JSON encoder to use tabs
def to_json_with_tabs(obj, indent=1, tab_char='\t'):
    """Convert object to JSON with tab indentation"""
    json_str = json.dumps(obj, ensure_ascii=False, indent=indent)
    # Replace spaces with tabs
    lines = json_str.split('\n')
    result = []
    for line in lines:
        # Count leading spaces
        spaces = 0
        while spaces < len(line) and line[spaces] == ' ':
            spaces += 1
        if spaces > 0:
            tabs = tab_char * (spaces // indent)
            result.append(tabs + line[spaces:])
        else:
            result.append(line)
    return '\n'.join(result)

output = to_json_with_tabs(timelines)

# Write to file
with open(file_path, 'w', encoding='utf-8', newline='') as f:
    f.write(output)

print(f"Conversion complete. Converted {conversion_count} attack patterns.")
