# Haven Backend API Documentation

Base URL: `http://localhost:8080/api`

---

## 1. User Signup

Registers a new user and uploads their profile photo to Firebase Storage.

- **URL:** `/auth/signup`
- **Method:** `POST`
- **Content-Type:** `multipart/form-data`

### Request Fields (Form Data)
| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `aadhar_number` | text | Yes | 12-digit Aadhar number. |
| `full_name` | text | Yes | Full name of the user. |
| `email` | text | Yes | User's email address. |
| `phone_number` | text | Yes | User's contact number. |
| `profile_photo` | file | Yes | Image file (Max 7MB). |
| `address_line` | text | Yes | User's street address. |
| `pincode` | text | Yes | Postal PIN code. |
| `state` | text | Yes | User's state. |
| `district` | text | Yes | User's district. |
| `password` | text | Yes | Password for authentication. |

### Success Response
- **Code:** `201 Created`
- **Content:**
  ```json
  {
    "message": "User registered successfully",
    "user": {
      "id": 1,
      "full_name": "John Doe",
      "email": "johndoe@example.com"
    }
  }
  ```

---

## 2. User Login

Authenticates a user and returns a JSON Web Token (JWT).

- **URL:** `/auth/login`
- **Method:** `POST`
- **Content-Type:** `application/json`

### Request Body
```json
{
  "email": "johndoe@example.com",
  "password": "yourpassword"
}
```

### Success Response
- **Code:** `200 OK`
- **Content:**
  ```json
  {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "full_name": "John Doe",
      "email": "johndoe@example.com"
    }
  }
  ```

---

## 3. Get User Profile

Fetches the authenticated user's profile details.

- **URL:** `/auth/profile`
- **Method:** `GET`
- **Headers:** 
  - `Authorization: Bearer <JWT_TOKEN>`

### Success Response
- **Code:** `200 OK`
- **Content:**
  ```json
  {
    "profile": {
      "id": 1,
      "aadhar_number": "123456789012",
      "full_name": "John Doe",
      "email": "johndoe@example.com",
      "phone_number": "9876543210",
      "profile_photo_url": "https://firebasestorage.googleapis.com/v0/b/...",
      "address_line": "123 Main St",
      "pincode": "123456",
      "state": "Sample State",
      "district": "Sample District",
      "created_at": "2026-04-18T19:30:00.000Z"
    }
  }
  ```

---

## 4. SOS Trigger (Women App)

Triggers an SOS alert, broadcasting the user's details and current location to the authorities.

- **URL:** `/sos/trigger`
- **Method:** `POST`
- **Content-Type:** `application/json`
- **Headers:** 
  - `Authorization: Bearer <JWT_TOKEN>`

### Request Body
```json
{
  "latitude": 28.7041,
  "longitude": 77.1025,
  "accuracy": 15.2,
  "timestamp": "2026-04-21T03:20:00.000Z"
}
```

### Success Response
- **Code:** `201 Created`
- **Content:**
  ```json
  {
    "message": "SOS Alert created successfully",
    "sos_id": "sos_9823749823"
  }
  ```

---

## 5. Upload SOS Audio Chunks (Women App)

Uploads 20-second audio chunks sequentially during an active SOS alert. The backend stores the audio file in Firebase Storage and appends the file URL to the SOS record.

- **URL:** `/sos/{sos_id}/audio-chunk`
- **Method:** `POST`
- **Content-Type:** `multipart/form-data`
- **Headers:** 
  - `Authorization: Bearer <JWT_TOKEN>`

### Request Fields
| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `chunk_index` | integer | Yes | Sequence number of the audio chunk (0, 1, 2...). |
| `audio_file` | file | Yes | .m4a or .aac audio file chunk. |

### Success Response
- **Code:** `200 OK`
- **Content:**
  ```json
  {
    "message": "Audio chunk uploaded successfully",
    "chunk_url": "https://firebasestorage.googleapis.com/v0/b/..."
  }
  ```

---

## 6. Retrieve Active SOS Alerts (Authority App)

Allows the authority to fetch a list of all active SOS alerts in their jurisdiction. (Note: For real-time updates, it is recommended to subscribe to a Firebase Realtime Database node or WebSocket, but this REST endpoint provides the current snapshot).

- **URL:** `/authority/sos-alerts`
- **Method:** `GET`
- **Headers:** 
  - `Authorization: Bearer <AUTHORITY_JWT_TOKEN>`

### Success Response
- **Code:** `200 OK`
- **Content:**
  ```json
  {
    "alerts": [
      {
        "sos_id": "sos_9823749823",
        "user": {
          "full_name": "John Doe",
          "phone_number": "9876543210",
          "profile_photo_url": "https://firebasestorage.googleapis.com/v0/b/..."
        },
        "location": {
          "latitude": 28.7041,
          "longitude": 77.1025
        },
        "status": "ACTIVE",
        "triggered_at": "2026-04-21T03:20:00.000Z"
      }
    ]
  }
  ```

---

## 7. Get SOS Details & Audio Chunks (Authority App)

Retrieves full details of a specific SOS alert, including the continuously updating list of recorded audio chunks. The authority app can poll this or listen to Firebase to play chunks one-by-one as they arrive.

- **URL:** `/authority/sos-alerts/{sos_id}`
- **Method:** `GET`
- **Headers:** 
  - `Authorization: Bearer <AUTHORITY_JWT_TOKEN>`

### Success Response
- **Code:** `200 OK`
- **Content:**
  ```json
  {
    "sos_id": "sos_9823749823",
    "user": {
      "full_name": "John Doe",
      "phone_number": "9876543210",
      "profile_photo_url": "https://firebasestorage.googleapis.com/v0/b/...",
      "address_line": "123 Main St",
      "aadhar_number": "123456789012"
    },
    "location": {
      "latitude": 28.7041,
      "longitude": 77.1025,
      "accuracy": 15.2
    },
    "status": "ACTIVE",
    "triggered_at": "2026-04-21T03:20:00.000Z",
    "audio_chunks": [
      {
        "chunk_index": 0,
        "url": "https://firebasestorage.googleapis.com/v0/b/.../chunk_0.m4a",
        "uploaded_at": "2026-04-21T03:20:20.000Z"
      },
      {
        "chunk_index": 1,
        "url": "https://firebasestorage.googleapis.com/v0/b/.../chunk_1.m4a",
        "uploaded_at": "2026-04-21T03:20:40.000Z"
      }
    ]
  }
  ```
