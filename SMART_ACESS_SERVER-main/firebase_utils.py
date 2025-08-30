import firebase_admin
from firebase_admin import credentials, messaging


# Initialize Firebase Admin SDK
def initialize_firebase():
    cred = credentials.Certificate(
        "smartaccess-3df78-firebase-adminsdk-fbsvc-94740c8ae5.json"
    )
    firebase_admin.initialize_app(cred)


def send_notification(fcm_token, title, body):
    # Create the message
    message = messaging.Message(
        token=fcm_token, notification=messaging.Notification(title=title, body=body)
    )

    try:
        # Send the notification
        response = messaging.send(message)
        print("Notification sent successfully:", response)
        return {"message": "Notification sent successfully", "response": response}
    except Exception as e:
        print(f"Error sending notification: {e}")
        return {"error": str(e)}
