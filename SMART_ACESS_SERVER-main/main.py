import os
import uvicorn
from typing import List
import aiofiles
import socketio

from fastapi import FastAPI, HTTPException, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from fastapi.staticfiles import StaticFiles
from bson import ObjectId
import requests
from pymongo import MongoClient
from fastapi.responses import JSONResponse
import bcrypt
from dotenv import load_dotenv
from datetime import datetime
import google.auth
from google.auth.transport.requests import Request
from google.oauth2 import service_account
import json
import jwt
import shutil

# Create the FastAPI app
app = FastAPI()

# Socket.IO setup
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")
socket_app = socketio.ASGIApp(sio, app)

# Mount static files
upload_dir = "faces/"
if not os.path.exists(upload_dir):
    os.makedirs(upload_dir)
app.mount("/faces", StaticFiles(directory="faces"), name="faces")
app.mount("/history", StaticFiles(directory="history"), name="history")

# Add CORS middleware to allow cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")
client = MongoClient(MONGO_URI)

db = client["CameraDb"]
users_collection = db["users"]
pictures_collection = db["pictures"]
history_collection = db["history"]

# Store notification counts (in production, use a database)
notification_counts = {}


# Pydantic models
class SignUp(BaseModel):
    username: str
    email: EmailStr
    password: str


class Picture(BaseModel):
    userId: str
    picture: str
    name: str
    accessLevel: str


class SignIn(BaseModel):
    email: EmailStr
    password: str


class History(BaseModel):
    userId: str
    registered: bool
    timestamp: datetime


class NotificationData(BaseModel):
    fcm_token: str
    title: str
    body: str


class AccessHistoryItem(BaseModel):
    user: str
    time: str
    status: bool


# Firebase Cloud Messaging credentials
PROJECT_ID = "smartaccess-3df78"
SERVICE_ACCOUNT_FILE = "smartaccess-3df78-firebase-adminsdk-fbsvc-7f6ca951c9.json"


def get_access_token():
    with open(SERVICE_ACCOUNT_FILE, "r") as file:
        service_account_info = json.load(file)

    scopes = ["https://www.googleapis.com/auth/firebase.messaging"]
    credentials = service_account.Credentials.from_service_account_info(
        service_account_info, scopes=scopes
    )

    credentials.refresh(Request())
    return credentials.token


@app.post("/send_notification/")
async def send_notification(notification: NotificationData):
    # Get the access token
    access_token = get_access_token()

    # FCM HTTP v1 API URL
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"

    # Set up headers for the request
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    # Prepare the message payload
    message = {
        "message": {
            "token": notification.fcm_token,
            "notification": {
                "title": notification.title,
                "body": notification.body,
            },
        }
    }

    # Send the notification via HTTP POST request
    response = requests.post(url, json=message, headers=headers)

    # Update notification count and emit Socket.IO event
    user_id = "blabla"
    notification_counts[user_id] = notification_counts.get(user_id, 0) + 1
    await sio.emit(
        "notification_count",
        {"user_id": user_id, "count": notification_counts[user_id]},
    )

    # Check if the request was successful
    if response.status_code == 200:
        return {"message": "Notification sent successfully"}
    else:
        return {"error": response.text}


# Socket.IO events
@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")


@sio.event
async def reset_notification_counts(sid):
    # Reset all notification counts
    print("reset")
    global notification_counts
    notification_counts = {}

    # Emit a confirmation to all clients that the counts have been reset
    await sio.emit(
        "notification_counts_reset", {"message": "Notification counts have been reset."}
    )
    print("Notification counts reset for all users.")


@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")


@sio.event
async def join_room(sid, data):
    user_id = data["user_id"]
    sio.enter_room(sid, user_id)
    print(f"User {user_id} joined room")
    # Send current count when user joins
    await sio.emit(
        "notification_count",
        {"user_id": user_id, "count": notification_counts.get(user_id, 0)},
        room=user_id,
    )
    print("user connected ", data)


# SignUp route
@app.post("/register/")
async def signup_user(user: SignUp):
    if users_collection.find_one({"email": user.email}):
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt())

    user_data = {
        "username": user.username,
        "email": user.email,
        "password": hashed_password,
    }
    users_collection.insert_one(user_data)

    return {"message": "User registered successfully"}


# SignIn route
@app.post("/signin/")
async def signin_user(user: SignIn):
    existing_user = users_collection.find_one({"email": user.email})

    if not existing_user:
        raise HTTPException(status_code=400, detail="Email not found")

    if not bcrypt.checkpw(user.password.encode("utf-8"), existing_user["password"]):
        raise HTTPException(status_code=400, detail="Incorrect password")

    return {
        "message": "Login successful",
        "user_id": str(existing_user["_id"]),
        "username": existing_user.get("username", "Guest"),
    }


def copy_file(src_path, dest_dir):
    try:
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir, exist_ok=True)
        dest_file_path = os.path.join(dest_dir, os.path.basename(src_path))
        shutil.copy(src_path, dest_file_path)
        return dest_file_path
    except Exception as e:
        raise Exception(f"Error copying file: {e}")


@app.post("/upload")
async def upload_image(
    image: UploadFile = File(None),
    imageUrl: str = Form(None),
    userId: str = Form(...),
    name: str = Form(...),
    accessLevel: str = Form(...),
):
    print("image:", image)
    print("imageUrl:", imageUrl)
    print("userId:", userId)
    print("name:", name)
    print("accessLevel:", accessLevel)

    person_dir = os.path.join(upload_dir, name)
    os.makedirs(person_dir, exist_ok=True)

    try:
        file_path = None

        if image:
            filename = f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{image.filename}"
            file_path = os.path.join(person_dir, filename)

            async with aiofiles.open(file_path, "wb") as out_file:
                content = await image.read()
                await out_file.write(content)

        elif imageUrl:
            local_image_path = imageUrl[imageUrl.find("history/") :]
            file_path = copy_file(local_image_path, person_dir)

        else:
            return JSONResponse(
                content={"error": "No image or imageUrl provided"}, status_code=400
            )

        picture_data = {
            "userId": userId,
            "name": name,
            "picture": file_path,
            "accessLevel": accessLevel,
        }

        pictures_collection.insert_one(picture_data)

        return JSONResponse(
            content={
                "message": "Image uploaded and saved!",
                "file_path": file_path,
                "userId": userId,
                "name": name,
                "accessLevel": accessLevel,
            }
        )

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.get("/pictures/{user_id}")
async def get_user_pictures(user_id: str):
    try:
        pictures = list(pictures_collection.find({"userId": user_id}))

        for picture in pictures:
            picture["_id"] = str(picture["_id"])

        return JSONResponse(
            content={
                "message": "Pictures retrieved successfully",
                "pictures": pictures,
            }
        )
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.delete("/pictures/{picture_id}")
async def delete_picture(picture_id: str):
    try:
        picture = pictures_collection.find_one({"_id": ObjectId(picture_id)})

        if not picture:
            return JSONResponse(
                content={"error": "Picture not found"},
                status_code=404,
            )

        file_url = picture.get("picture")
        path_parts = file_url.split("/")
        directory = os.path.join(upload_dir, *path_parts[1:-1])
        filename = path_parts[-1]
        file_path = os.path.join(directory, filename)

        # If the file doesn't exist, just delete the record from MongoDB
        if not os.path.exists(file_path):
            result = pictures_collection.delete_one({"_id": ObjectId(picture_id)})

            if result.deleted_count == 0:
                return JSONResponse(
                    content={"error": "Failed to delete the picture from the database"},
                    status_code=500,
                )

            return JSONResponse(
                content={
                    "message": "Picture record deleted successfully from database (file not found)"
                },
            )

        # If file exists, delete the image file from the server
        os.remove(file_path)

        # Remove the directory if it's empty
        if not os.listdir(directory):
            shutil.rmtree(directory)

        # Finally, delete the record from MongoDB
        result = pictures_collection.delete_one({"_id": ObjectId(picture_id)})

        if result.deleted_count == 0:
            return JSONResponse(
                content={"error": "Failed to delete the picture from the database"},
                status_code=500,
            )

        return JSONResponse(
            content={
                "message": "Picture and directory deleted successfully, both from database and server"
            },
        )

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.get("/history/{user_id}")
async def get_user_history(user_id: str):
    try:
        history = list(history_collection.find({"userId": user_id}))

        for entry in history:
            entry["_id"] = str(entry["_id"])

        return JSONResponse(
            content={
                "message": "History retrieved successfully",
                "history": history,
            }
        )
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


@app.post("/history/")
async def add_history(
    userId: str = Form(...),
    registered: bool = Form(...),
):
    try:
        history_entry = History(
            userId=userId,
            registered=registered,
            timestamp=datetime.now(),
        )

        history_dict = history_entry.dict()
        history_collection = db["history"]
        result = history_collection.insert_one(history_dict)

        return JSONResponse(
            content={
                "message": "History entry added successfully!",
                "history": history_dict,
            },
            status_code=201,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/access-history")
async def get_access_history():
    try:
        records = list(history_collection.find())

        history_data = [
            {
                "user": record.get("name", "Unknown User"),
                "time": (
                    record["date"].strftime("%Y-%m-%d %H:%M:%S")
                    if isinstance(record["date"], datetime)
                    else record["date"]
                ),
                "status": record.get("status", False),
                "image_path": record.get("image_path", ""),
            }
            for record in records
        ]
        history_data.reverse()

        return history_data

    except Exception as e:
        return JSONResponse(
            content={"error": f"Failed to fetch access history: {str(e)}"},
            status_code=500,
        )


def delete_files_in_batches(directory, batch_size=50):
    try:
        files = os.listdir(directory)
        total_files = len(files)

        # Process files in batches
        for i in range(0, total_files, batch_size):
            batch_files = files[i : i + batch_size]
            for file in batch_files:
                file_path = os.path.join(directory, file)
                if os.path.isfile(file_path):
                    os.remove(file_path)

        return {
            "message": f"Deleted {total_files} files from {directory} successfully."
        }
    except Exception as e:
        return {"error": f"Failed to delete files: {str(e)}"}


@app.delete("/historyDelete")
async def clear_history():
    try:
        # Delete all documents from the MongoDB collection
        result = history_collection.delete_many({})

        # Delete all files in the 'history' directory
        history_dir = "history"
        if os.path.exists(history_dir):
            for file in os.listdir(history_dir):
                file_path = os.path.join(history_dir, file)
                if os.path.isfile(file_path):
                    os.remove(file_path)

        return {
            "status": "success",
            "deleted_count": result.deleted_count,
            "message": "History directory cleared",
        }
    except Exception as e:
        return {"error": f"An error occurred during history deletion: {str(e)}"}


# Mount the Socket.IO app
app.mount("/", socket_app)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
