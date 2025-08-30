import shutil
import os


def copy_file(src_file, dest_folder):
    try:
        # Ensure destination folder exists
        if not os.path.exists(dest_folder):
            os.makedirs(dest_folder)

        # Copy the file
        shutil.copy(src_file, dest_folder)
        print(f"File {src_file} copied to {dest_folder}")
    except Exception as e:
        print(f"Error: {e}")


# Example usage
source_file = "history/Visitor - Access Pending_20250424141822.jpg"  # source file path
destination_folder = "faces/sss"  # destination folder

copy_file(source_file, destination_folder)
