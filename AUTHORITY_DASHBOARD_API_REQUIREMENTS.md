# Authority Dashboard API Requirements

This document lists backend APIs needed to fully power the authority dashboard in the Haven app.

## 1) Live Alerts Feed

- Method: `GET`
- Endpoint: `/api/authority/sos-alerts`
- Auth: `Bearer <authority_jwt>`
- Purpose: Return all active/recent SOS alerts for listing and polling every 10s.

### Response (200)

```json
{
  "alerts": [
    {
      "sos_id": "sos_123",
      "status": "triggered",
      "priority": "HIGH",
      "created_at": "2026-04-21T10:35:22Z",
      "victim_name": "Aditi Verma",
      "user_email": "victim@example.com",
      "location": {
        "latitude": 28.6139,
        "longitude": 77.2090,
        "accuracy": 14.2
      },
      "address": "Connaught Place, New Delhi",
      "audio_chunks_count": 6
    }
  ]
}
```

## 2) Alert Details

- Method: `GET`
- Endpoint: `/api/authority/sos-alerts/:sosId`
- Auth: `Bearer <authority_jwt>`
- Purpose: Return full details for one alert.

### Response (200)

```json
{
  "sos_id": "sos_123",
  "status": "in_progress",
  "priority": "HIGH",
  "created_at": "2026-04-21T10:35:22Z",
  "updated_at": "2026-04-21T10:37:09Z",
  "victim": {
    "id": "user_42",
    "name": "Aditi Verma",
    "phone": "+919800000000",
    "email": "victim@example.com"
  },
  "location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "accuracy": 14.2,
    "address": "Connaught Place, New Delhi"
  },
  "audio_chunks": [
    {
      "chunk_index": 0,
      "uploaded_at": "2026-04-21T10:35:30Z",
      "audio_url": "https://cdn.example.com/sos_123/chunk_0.m4a"
    }
  ],
  "latest_note": "Victim whispered: being followed"
}
```

## 3) Update Alert Status (Required for Assign Unit / Resolution)

- Method: `PATCH`
- Endpoint: `/api/authority/sos-alerts/:sosId/status`
- Auth: `Bearer <authority_jwt>`
- Purpose: Let authority move an alert through the response lifecycle.

### Request Body

```json
{
  "status": "in_progress",
  "assigned_unit_id": "unit_12",
  "comment": "Nearest patrol dispatched"
}
```

### Allowed statuses

- `triggered`
- `in_progress`
- `resolved`
- `false_alarm`

### Response (200)

```json
{
  "sos_id": "sos_123",
  "status": "in_progress",
  "updated_at": "2026-04-21T10:37:09Z"
}
```

## 4) Optional Push Channel for Instant Alerts

Polling is already implemented in app, but push improves speed and battery.

Option A: WebSocket
- Endpoint: `/api/authority/sos-alerts/stream`
- Event: `sos_alert_created`
- Payload: same shape as one object in `alerts[]`.

Option B: FCM
- Topic: `authority_alerts`
- Payload fields: `sos_id`, `status`, `priority`, `latitude`, `longitude`, `created_at`.

## 5) Error Contract (Recommended)

For non-2xx responses:

```json
{
  "error": {
    "code": "AUTHORITY_FORBIDDEN",
    "message": "Only authority users can access this endpoint"
  }
}
```

## 6) Role and Auth Expectations

- JWT must include role claim: `authority`.
- `/api/authority/*` routes must reject non-authority users with `403`.
- Token expiry and invalid-token responses should return `401` with a clear message.

## 7) Pagination and Sorting (Optional but Useful)

For large city deployments:
- Query params: `page`, `limit`, `status`, `from`, `to`, `sort`.
- Default sort: newest first by `created_at`.

Example:
`GET /api/authority/sos-alerts?status=triggered&page=1&limit=50&sort=-created_at`
