# Origin Hub API

Backend REST API for the Origin Hub personal application.

**Frontend repo**: `D:\personal\Origin-Hub` (React + TypeScript + Vite) — not modified by this project.

---

## Architecture — Where Does Each File Go?

| Folder            | Role                   | What Goes Here                                   | What NEVER Goes Here           |
| :---------------- | :--------------------- | :----------------------------------------------- | :----------------------------- |
| `app/main.py`     | **Front Door**         | App startup, CORS config, router registration    | Business logic, DB queries     |
| `app/core/`       | **Control Room**       | Settings (config.py), security utils, constants  | Endpoints, DB models           |
| `app/api/routes/` | **Reception Desk**     | HTTP endpoints, status codes, request handling   | Heavy logic, raw SQL           |
| `app/schemas/`    | **Forms & Contracts**  | Pydantic models: validate request/response JSON  | DB table definitions           |
| `app/services/`   | **Kitchen / Workroom** | Business logic, calculations, workflows          | HTTP objects, route decorators |
| `app/models/`     | **Storage Shelves**    | SQLAlchemy ORM classes mapping to DB tables      | Pydantic schemas, routes       |
| `app/db/`         | **Plumbing**           | DB engine, session factory, connection lifecycle | Table definitions, endpoints   |
| `tests/`          | **QA Lab**             | Automated tests with pytest                      | Production application code    |

### How Data Flows

```
Browser Request
    |
    v
app/main.py (routes the request)
    |
    v
app/api/routes/ (receives HTTP request, validates with schemas/)
    |
    v
app/services/ (does the actual work, business logic)
    |
    v
app/models/ + app/db/ (reads/writes to PostgreSQL)
    |
    v
app/schemas/ (shapes the response JSON)
    |
    v
HTTP Response back to browser
```

---

## Authentication Architecture

All authentication methods (password, Google, passkey) converge on **one unified session system**:

```
Password Login  ─┐
Google Sign-In  ─┼──> Verify Identity ──> Create Server-Side Session ──> Set HttpOnly Cookie
Passkey Login   ─┘
```

### Session Cookie Security

| Control            | Purpose                                                |
| :----------------- | :----------------------------------------------------- |
| `HttpOnly`         | JavaScript cannot read the cookie (reduces XSS risk)   |
| `Secure`           | Cookie sent only over HTTPS (off during localhost dev) |
| `SameSite=Lax`     | Reduces cross-site request risks                       |
| Server-side expiry | Server decides when session ends                       |
| Session rotation   | New token generated at login                           |

### API Endpoints (Target)

| Action          | Method & Route                         | Description                               |
| :-------------- | :------------------------------------- | :---------------------------------------- |
| Register        | `POST /api/auth/register`              | Create account with email + password      |
| Login           | `POST /api/auth/login`                 | Verify credentials, create session cookie |
| Current user    | `GET /api/auth/me`                     | Return logged-in user's profile           |
| Logout          | `POST /api/auth/logout`                | Delete session from DB, clear cookie      |
| Google login    | `POST /api/auth/google`                | Verify Google ID token, create session    |
| Passkey options | `POST /api/auth/passkey/login/options` | Generate WebAuthn challenge               |
| Passkey verify  | `POST /api/auth/passkey/login/verify`  | Verify passkey, create session            |
| Health check    | `GET /api/health`                      | Confirm API is running                    |

---

## Quick Start (Windows)

Double-click or run:

```cmd
start_up.bat
```

This checks your virtual environment, runtime dependencies, and `.env` file. If setup is needed, it installs only runtime dependencies (and skips pip entirely when only `.env` is missing), then launches the server at `http://localhost:8000`.

To run setup manually:

```cmd
setup.bat
```

Manual setup also installs the test dependencies. Pip warnings and errors are saved to `logs/pip-install.log`.

### Manual Setup Steps

#### 1. Create Virtual Environment

```powershell
python -m venv .venv
```

#### 2. Activate Virtual Environment

```powershell
.\.venv\Scripts\Activate.ps1
```

#### 3. Install Dependencies

```powershell
pip install -e ".[test]"
```

#### 4. Create Local .env

```powershell
cp .env.example .env
```

#### 5. Run Tests

```powershell
pytest
```

#### 6. Start Development Server

```powershell
uvicorn app.main:app --reload --port 8000
```

### URLs When Running

- **API Root**: http://localhost:8000
- **Health Check**: http://localhost:8000/api/health
- **Swagger Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## Dependencies

### Runtime

- `fastapi` — Web framework
- `uvicorn[standard]` — ASGI server
- `pydantic-settings` — Environment variable management

### Testing

- `pytest` — Test runner
- `httpx` — HTTP client (required by FastAPI TestClient)

### Planned (Added As You Reach Each Phase)

- `sqlalchemy` — Database ORM
- `psycopg[binary]` — PostgreSQL driver
- `alembic` — Database migrations
- `argon2-cffi` — Password hashing
- `google-auth` — Google Sign-In token verification
- `py_webauthn` — Passkey (WebAuthn) support
- `pyotp` — TOTP 2FA codes

---

## CORS Notes

- Frontend: `http://localhost:5173` (or whichever port Vite uses)
- Backend: `http://localhost:8000`
- Different ports = different origins = CORS required
- **NEVER** combine `allow_origins=["*"]` with `allow_credentials=True`
- Always list the exact frontend origin when cookies are involved
