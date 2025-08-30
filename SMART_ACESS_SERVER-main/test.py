import cv2
import numpy as np
import face_recognition
import os
import requests
from datetime import datetime
from pymongo import MongoClient
from PIL import Image
import time
import hashlib
from dotenv import load_dotenv
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
client = MongoClient(MONGO_URI)
db = client["CameraDb"]
collection = db["history"]

# Define history directory
history_dir = "history/"
os.makedirs(history_dir, exist_ok=True)
os.makedirs("faces", exist_ok=True)


class FaceDirectoryHandler(FileSystemEventHandler):
    def __init__(self, callback):
        self.callback = callback

    def on_created(self, event):
        if not event.is_directory and event.src_path.endswith(('.jpg', '.png')):
            self.callback()

    def on_deleted(self, event):
        if not event.is_directory and event.src_path.endswith(('.jpg', '.png')):
            self.callback()

    def on_modified(self, event):
        if not event.is_directory and event.src_path.endswith(('.jpg', '.png')):
            self.callback()


def save_image_to_history(image, name, status):
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"{name}_{timestamp}.jpg"
    file_path = os.path.join(history_dir, filename)

    image.save(file_path)

    picture_data = {
        "name": name,
        "image_path": file_path,
        "date": datetime.now(),
        "status": status,
    }
    collection.insert_one(picture_data)
    print(f"Image saved to {file_path} and added to MongoDB")


def load_face_encodings(database_path):
    encodings = []
    names = []
    print("Loading face database...")

    for person_name in os.listdir(database_path):
        person_folder = os.path.join(database_path, person_name)
        if os.path.isdir(person_folder):
            for file in os.listdir(person_folder):
                if file.endswith(".jpg") or file.endswith(".png"):
                    image_path = os.path.join(person_folder, file)
                    print(f"Loading image: {image_path}")
                    image = face_recognition.load_image_file(image_path)
                    face_encs = face_recognition.face_encodings(image)

                    if face_encs:
                        encodings.append(face_encs[0])
                        names.append(person_name)
                    else:
                        print(f"No faces found in {image_path}")

    print(f"Loaded {len(encodings)} encodings from the database.")
    return encodings, names


def main():
    database_path = "faces/"
    FCM_TOKEN = os.getenv("FCM_TOKEN")
    API_URL = os.getenv("API_URL")

    # Global variables to store face encodings
    global encodings, names
    encodings, names = load_face_encodings(database_path)

    if len(encodings) == 0:
        print("No encodings were loaded. Please check the 'faces/' folder.")
        exit()

    # Set up file system observer
    def reload_encodings():
        global encodings, names
        print("Detected changes in faces directory. Reloading encodings...")
        encodings, names = load_face_encodings(database_path)

    event_handler = FaceDirectoryHandler(reload_encodings)
    observer = Observer()
    observer.schedule(event_handler, database_path, recursive=True)
    observer.start()

    try:
        cap = cv2.VideoCapture(0)

        while True:
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame")
                break

            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            face_locations = face_recognition.face_locations(rgb_frame)
            face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)

            for (top, right, bottom, left), face_encoding in zip(
                face_locations, face_encodings
            ):
                matches = face_recognition.compare_faces(
                    encodings, face_encoding, tolerance=0.7
                )
                name = "Visitor - Access Pending"

                if True in matches:
                    matched_names = [names[i] for i, match in enumerate(matches) if match]
                    name = max(set(matched_names), key=matched_names.count)
                    face_image = frame[top:bottom, left:right]
                    pil_image = Image.fromarray(face_image)
                    print(f"Recognized {name}!")

                    save_image_to_history(pil_image, name, True)
                    try:
                        response = requests.post(
                            f"{API_URL}/send_notification/",
                            json={
                                "fcm_token": FCM_TOKEN,
                                "title": "Registered Person Detected",
                                "body": f"{name} was recognized",
                            },
                        )
                        print("Notification response:", response.text)
                        time.sleep(5)
                    except Exception as e:
                        print("Error sending notification:", e)
                else:
                    face_image = frame[top:bottom, left:right]
                    pil_image = Image.fromarray(face_image)
                    save_image_to_history(pil_image, name, False)
                    try:
                        response = requests.post(
                            f"{API_URL}/send_notification/",
                            json={
                                "fcm_token": FCM_TOKEN,
                                "title": "Unknown Person Detected",
                                "body": "Unregistered person detected",
                            },
                        )
                        print("Notification response:", response.text)
                        time.sleep(5)
                    except Exception as e:
                        print("Error sending notification:", e)

                cv2.rectangle(frame, (left, top), (right, bottom), (0, 255, 0), 2)
                cv2.putText(
                    frame, name, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2
                )

            cv2.imshow("Face Recognition", frame)

            if cv2.waitKey(1) & 0xFF == 27:
                break

    finally:
        observer.stop()
        observer.join()
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()