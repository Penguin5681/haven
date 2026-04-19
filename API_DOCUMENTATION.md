# Haven Backend API Documentation

Base URL: `http://localhost:8080/api/auth`

---

## 1. User Signup

Registers a new user and uploads their profile photo to Firebase Storage.

- **URL:** `/signup`
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

### Example cURL Request
```bash
curl -X POST http://localhost:8080/api/auth/signup \
  -F "aadhar_number=123456789012" \
  -F "full_name=John Doe" \
  -F "email=johndoe@example.com" \
  -F "phone_number=9876543210" \
  -F "profile_photo=@/path/to/your/photo.jpg" \
  -F "address_line=123 Main St" \
  -F "pincode=123456" \
  -F "state=Sample State" \
  -F "district=Sample District" \
  -F "password=yourpassword"
```

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

### Error Responses
- **Code:** `400 Bad Request` (e.g., File too large, missing fields, or user already exists)
- **Code:** `500 Internal Server Error`

---

## 2. User Login

Authenticates a user and returns a JSON Web Token (JWT).

- **URL:** `/login`
- **Method:** `POST`
- **Content-Type:** `application/json`

### Request Body
```json
{
  "email": "johndoe@example.com",
  "password": "yourpassword"
}
```

### Example cURL Request
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "johndoe@example.com",
    "password": "yourpassword"
  }'
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

### Error Responses
- **Code:** `400 Bad Request` (Invalid email or password)
- **Code:** `500 Internal Server Error`

---

## 3. Get User Profile

Fetches the authenticated user's profile details.

- **URL:** `/profile`
- **Method:** `GET`
- **Headers:** 
  - `Authorization: Bearer <JWT_TOKEN>`

### Example cURL Request
```bash
curl -X GET http://localhost:8080/api/auth/profile \
  -H "Authorization: Bearer <YOUR_JWT_TOKEN>"
```

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

### Error Responses
- **Code:** `401 Unauthorized` (Access denied. No token provided.)
- **Code:** `403 Forbidden` (Invalid token.)
- **Code:** `404 Not Found` (User not found)
- **Code:** `500 Internal Server Error`
