# Haven Admin API Documentation

All admin APIs require header:

- `x-admin-key: <ADMIN_API_KEY>`

## 1. Get All Users

- **URL:** `/api/admin/users`
- **Method:** `GET`

### Example cURL

```bash
curl -X GET http://localhost:8080/api/admin/users \
  -H "x-admin-key: <ADMIN_API_KEY>"
```

### Success Response

- **Code:** `200 OK`

```json
{
  "count": 1,
  "users": [
    {
      "id": 1,
      "aadhar_number": "123456789012",
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "phone_number": "9999999999",
      "profile_photo_url": "https://firebasestorage.googleapis.com/...",
      "address_line": "123 Park Street",
      "pincode": "700001",
      "state": "West Bengal",
      "district": "Kolkata",
      "created_at": "2026-04-19T11:22:33.000Z",
      "updated_at": "2026-04-19T11:22:33.000Z"
    }
  ]
}
```

---

## 2. Get User By ID

- **URL:** `/api/admin/users/:id`
- **Method:** `GET`

### Example cURL

```bash
curl -X GET http://localhost:8080/api/admin/users/1 \
  -H "x-admin-key: <ADMIN_API_KEY>"
```

### Success Response

- **Code:** `200 OK`

```json
{
  "user": {
    "id": 1,
    "aadhar_number": "123456789012",
    "full_name": "Jane Doe",
    "email": "jane@example.com",
    "phone_number": "9999999999",
    "profile_photo_url": "https://firebasestorage.googleapis.com/...",
    "address_line": "123 Park Street",
    "pincode": "700001",
    "state": "West Bengal",
    "district": "Kolkata",
    "created_at": "2026-04-19T11:22:33.000Z",
    "updated_at": "2026-04-19T11:22:33.000Z"
  }
}
```

### Error Responses

- **Code:** `400 Bad Request` (invalid id)
- **Code:** `404 Not Found` (user not found)

---

## 3. Approve Authority

Approves or unapproves an authority so they can log in.

- **URL:** `/api/admin/authorities/:id/approve`
- **Method:** `PATCH`
- **Headers:** `x-admin-key: <ADMIN_API_KEY>`
- **Content-Type:** `application/json`

### Request Body

```json
{
  "is_approved": true
}
```

### Success Response

- **Code:** `200 OK`

```json
{
  "message": "Authority approval status updated.",
  "authority": {
    "id": 1,
    "name": "Inspector Gadget",
    "email": "inspector@example.com",
    "is_approved": true
  }
}
```

### Error Responses

- **Code:** `403 Forbidden` (missing or invalid admin key)
- **Code:** `404 Not Found` (authority not found)
- **Code:** `400 Bad Request` (invalid id or missing is_approved)

---

## 4. Nuke Database

Drops **all tables** in `public` schema. Use only in controlled/dev scenarios.

- **URL:** `/api/admin/nuke-database`
- **Method:** `POST`
- **Headers:** `x-admin-key: <ADMIN_API_KEY>`
- **Content-Type:** `application/json`

### Request Body

```json
{
  "confirmationText": "NUKE_HAVEN_DB"
}
```

### Example cURL

```bash
curl -X POST http://localhost:8080/api/admin/nuke-database \
  -H "Content-Type: application/json" \
  -H "x-admin-key: <ADMIN_API_KEY>" \
  -d '{
    "confirmationText": "NUKE_HAVEN_DB"
  }'
```

### Success Response

- **Code:** `200 OK`

```json
{
  "message": "Database nuke complete. All tables in the public schema were dropped."
}
```

### Error Responses

- **Code:** `400 Bad Request` (wrong/missing confirmation text)
- **Code:** `403 Forbidden` (missing or invalid admin key)
- **Code:** `500 Internal Server Error`