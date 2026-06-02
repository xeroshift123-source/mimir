import os

user_dir = r"C:\Users\김유진"
appdata_roaming = os.path.join(user_dir, "AppData", "Roaming")
appdata_local = os.path.join(user_dir, "AppData", "Local")

# Search for any History or LocalHistory folders under editor app directories
editor_names = ["Code", "Cursor", "VSCodium", "Code - Insiders", "JetBrains", "Google"]

for base in [appdata_roaming, appdata_local]:
    if os.path.exists(base):
        for name in os.listdir(base):
            if any(ed in name for ed in editor_names):
                path = os.path.join(base, name)
                # search for folders named History or LocalHistory
                for root, dirs, files in os.walk(path):
                    if "History" in dirs:
                        print(f"Found History folder: {os.path.join(root, 'History')}")
                    if "LocalHistory" in dirs:
                        print(f"Found LocalHistory folder: {os.path.join(root, 'LocalHistory')}")
                    # don't walk too deep if we found one
                    if "History" in dirs or "LocalHistory" in dirs:
                        dirs.remove("History") if "History" in dirs else None
                        dirs.remove("LocalHistory") if "LocalHistory" in dirs else None
