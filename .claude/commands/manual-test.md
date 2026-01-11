# Manual Test Environment

Start the backend server and Flutter app for manual testing.

## Instructions

Execute the following steps in order:

### Step 1: Stop any existing processes

Kill any running backend or Flutter processes:

```bash
# Kill existing uvicorn/python processes on port 8001
lsof -ti:8001 | xargs kill -9 2>/dev/null || true

# Kill any existing Flutter run processes
pkill -f "flutter run" 2>/dev/null || true
```

### Step 2: Start the backend server

Start the FastAPI backend server in the background:

```bash
cd /Users/howie/Workspace/github/storybuddy_wg/storybuddy && \
source venv/bin/activate && \
nohup uvicorn src.main:app --host 0.0.0.0 --port 8001 --reload > /tmp/storybuddy_backend.log 2>&1 &
```

Wait and verify the server is running:

```bash
sleep 3 && curl -s http://localhost:8001/health
```

Expected output: `{"status":"healthy","version":"0.1.0"}`

### Step 3: Start the Flutter app on Android Emulator

**Important:** For Android emulator, use `10.0.2.2` instead of `localhost` to connect to the host machine.

```bash
cd /Users/howie/Workspace/github/storybuddy_wg/storybuddy/mobile && \
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
```

## Notes

- Backend runs on `http://localhost:8001` (host machine)
- Android emulator connects via `http://10.0.2.2:8001` (special IP for host access)
- Backend logs: `tail -f /tmp/storybuddy_backend.log`
- Use `r` for hot reload, `R` for hot restart in Flutter
- Use `q` to quit the Flutter app

## Cleanup

To stop everything:
```bash
# Stop backend
lsof -ti:8001 | xargs kill -9 2>/dev/null || true

# Stop Flutter (if detached)
pkill -f "flutter run" 2>/dev/null || true
```

## Verification

After both are running, you should see in Flutter logs:
- `200 http://10.0.2.2:8001/api/v1/parents/...` - Parent API working
- `200 http://10.0.2.2:8001/api/v1/stories` - Stories API working
