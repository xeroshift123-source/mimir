import json
import os

log_path = r"C:\Users\김유진\.gemini\antigravity-ide\brain\71e233ba-fd3a-4fc9-8198-9b7d6e4a1149\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        if data.get("step_index") == 15:
            content = data.get("content")
            print("Found step 15!")
            # Content contains the file lines with line numbers. Let's see the first 500 chars
            print(content[:500])
            
            # Let's clean the line numbers format
            # Format is:
            # "1: import 'dart:convert';\n2: import..."
            lines = content.split('\n')
            clean_lines = []
            for l in lines:
                if l.startswith("The following code has been modified") or l.startswith("The above content shows"):
                    continue
                # Line format: "1: import..."
                # we want to strip the line number prefix
                parts = l.split(':', 1)
                if len(parts) == 2 and parts[0].strip().isdigit():
                    clean_lines.append(parts[1])
                else:
                    # just keep it if it doesn't match, though it shouldn't happen for file content
                    clean_lines.append(l)
            
            restored = '\n'.join(clean_lines)
            
            # Remove any leading blank lines or formatting warnings
            # Write to a test file first
            with open("sync_screen_restored.dart", "w", encoding='utf-8') as out:
                out.write(restored)
            print("Restored file written to sync_screen_restored.dart")
            break
