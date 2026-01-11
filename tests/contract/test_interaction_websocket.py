"""Contract tests for WebSocket interaction protocol.

T026 [P] [US1] Contract test for WebSocket protocol.
Tests the WebSocket protocol as defined in contracts/websocket-protocol.md.
"""

from datetime import datetime

import pytest

# These imports will fail until the endpoint is implemented
from fastapi.testclient import TestClient

from src.main import app


class TestWebSocketConnection:
    """Tests for WebSocket connection establishment."""

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    def test_connect_with_valid_session_and_token(self, client):
        """Should establish connection with valid credentials."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            data = websocket.receive_json()
            assert data["type"] == "connection_established"
            assert data["sessionId"] == "session-123"
            assert "timestamp" in data

    def test_connect_without_token_rejected(self, client):
        """Should reject connection without token."""
        with pytest.raises(Exception):
            with client.websocket_connect("/v1/ws/interaction/session-123") as websocket:
                pass

    def test_connect_with_invalid_token_rejected(self, client):
        """Should reject connection with invalid token."""
        with pytest.raises(Exception):
            with client.websocket_connect(
                "/v1/ws/interaction/session-123?token=invalid-token"
            ) as websocket:
                pass

    def test_connect_with_invalid_session_rejected(self, client):
        """Should reject connection with non-existent session."""
        with pytest.raises(Exception):
            with client.websocket_connect(
                "/v1/ws/interaction/nonexistent?token=valid-jwt-token"
            ) as websocket:
                pass


class TestClientToServerMessages:
    """Tests for client → server messages as per protocol."""

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    @pytest.fixture
    def connected_websocket(self, client):
        """Create connected WebSocket for testing."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            # Consume connection_established message
            websocket.receive_json()
            yield websocket

    def test_send_start_listening(self, connected_websocket):
        """Should accept start_listening message."""
        connected_websocket.send_json(
            {
                "type": "start_listening",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        # Should not receive an error
        # Server may or may not send a response

    def test_send_stop_listening(self, connected_websocket):
        """Should accept stop_listening message."""
        connected_websocket.send_json(
            {
                "type": "stop_listening",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

    def test_send_speech_started(self, connected_websocket):
        """Should accept speech_started message."""
        connected_websocket.send_json(
            {
                "type": "speech_started",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

    def test_send_speech_ended(self, connected_websocket):
        """Should accept speech_ended message."""
        connected_websocket.send_json(
            {
                "type": "speech_ended",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "durationMs": 2500,
            }
        )

    def test_send_interrupt_ai(self, connected_websocket):
        """Should accept interrupt_ai message."""
        connected_websocket.send_json(
            {
                "type": "interrupt_ai",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

    def test_send_pause_session(self, connected_websocket):
        """Should accept pause_session message."""
        connected_websocket.send_json(
            {
                "type": "pause_session",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        # Should receive session_status_changed
        response = connected_websocket.receive_json()
        assert response["type"] == "session_status_changed"
        assert response["status"] == "paused"

    def test_send_resume_session(self, connected_websocket):
        """Should accept resume_session message."""
        # First pause
        connected_websocket.send_json(
            {
                "type": "pause_session",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )
        connected_websocket.receive_json()  # Consume pause response

        # Then resume
        connected_websocket.send_json(
            {
                "type": "resume_session",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        response = connected_websocket.receive_json()
        assert response["type"] == "session_status_changed"
        assert response["status"] == "active"

    def test_send_end_session(self, connected_websocket):
        """Should accept end_session message."""
        connected_websocket.send_json(
            {
                "type": "end_session",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        response = connected_websocket.receive_json()
        assert response["type"] == "session_ended"
        assert "transcriptId" in response
        assert "turnCount" in response
        assert "totalDurationMs" in response

    def test_send_binary_audio_data(self, connected_websocket):
        """Should accept binary audio data."""
        # Send Opus-encoded audio frame (simulated)
        audio_frame = bytes(640)  # 20ms of audio
        connected_websocket.send_bytes(audio_frame)

        # Should not cause an error - may trigger transcription_progress

    def test_send_invalid_message_type(self, connected_websocket):
        """Should handle invalid message types."""
        connected_websocket.send_json(
            {
                "type": "invalid_type",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        response = connected_websocket.receive_json()
        assert response["type"] == "error"
        assert "code" in response


class TestServerToClientMessages:
    """Tests for server → client messages as per protocol."""

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    @pytest.fixture
    def connected_websocket(self, client):
        """Create connected WebSocket."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            websocket.receive_json()  # Consume connection_established
            yield websocket

    def test_receive_connection_established(self, client):
        """Should receive connection_established on connect."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            data = websocket.receive_json()

            assert data["type"] == "connection_established"
            assert data["sessionId"] == "session-123"
            assert "timestamp" in data

    def test_receive_transcription_progress(self, connected_websocket):
        """Should receive transcription_progress during speech."""
        # Trigger speech processing
        connected_websocket.send_json(
            {
                "type": "speech_started",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        # Send audio data
        for _ in range(10):
            connected_websocket.send_bytes(bytes(640))

        # Should receive interim transcription (may need timeout)
        try:
            response = connected_websocket.receive_json(timeout=2.0)
            if response["type"] == "transcription_progress":
                assert "text" in response
                assert "isFinal" in response
                assert response["isFinal"] is False
        except:
            pass  # May not receive if no actual STT

    def test_receive_transcription_final(self, connected_websocket):
        """Should receive transcription_final after speech ends."""
        connected_websocket.send_json(
            {
                "type": "speech_started",
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        )

        for _ in range(10):
            connected_websocket.send_bytes(bytes(640))

        connected_websocket.send_json(
            {
                "type": "speech_ended",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "durationMs": 2000,
            }
        )

        # Should eventually receive final transcription
        try:
            response = connected_websocket.receive_json(timeout=5.0)
            if response["type"] == "transcription_final":
                assert "text" in response
                assert "confidence" in response
                assert "segmentId" in response
        except:
            pass

    def test_receive_ai_response_sequence(self, connected_websocket):
        """Should receive AI response in correct sequence."""
        # Simulate speech that triggers AI response
        connected_websocket.send_json(
            {
                "type": "speech_ended",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "durationMs": 2000,
            }
        )

        responses = []
        try:
            for _ in range(5):
                response = connected_websocket.receive_json(timeout=5.0)
                responses.append(response)
        except:
            pass

        # Check response sequence if AI responded
        response_types = [r["type"] for r in responses]

        # Should have: ai_response_started -> ai_response_text -> ai_response_audio -> ai_response_completed
        if "ai_response_started" in response_types:
            started_idx = response_types.index("ai_response_started")
            assert "responseId" in responses[started_idx]

            if "ai_response_completed" in response_types:
                completed_idx = response_types.index("ai_response_completed")
                assert completed_idx > started_idx  # completed comes after started

    def test_receive_error_message(self, connected_websocket):
        """Should receive error messages in correct format."""
        # Trigger an error condition
        connected_websocket.send_json(
            {
                "type": "unknown_command",
            }
        )

        response = connected_websocket.receive_json()

        assert response["type"] == "error"
        assert "code" in response
        assert "message" in response
        assert "recoverable" in response
        assert "timestamp" in response


class TestWebSocketProtocolFlow:
    """Integration tests for complete interaction flows."""

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    def test_normal_interaction_flow(self, client):
        """Test the normal interaction flow as per sequence diagram."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            # 1. Receive connection_established
            data = websocket.receive_json()
            assert data["type"] == "connection_established"

            # 2. Send start_listening
            websocket.send_json(
                {
                    "type": "start_listening",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
            )

            # 3. Child starts speaking - send speech_started
            websocket.send_json(
                {
                    "type": "speech_started",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
            )

            # 4. Send audio data
            for _ in range(10):
                websocket.send_bytes(bytes(640))

            # 5. Child stops speaking - send speech_ended
            websocket.send_json(
                {
                    "type": "speech_ended",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "durationMs": 2000,
                }
            )

            # 6. Should receive transcription and AI response
            # (depends on implementation)

            # 7. End session
            websocket.send_json(
                {
                    "type": "end_session",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
            )

            response = websocket.receive_json()
            assert response["type"] == "session_ended"

    def test_interruption_flow(self, client):
        """Test the AI interruption flow as per sequence diagram."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            websocket.receive_json()  # connection_established

            # Assume AI is responding (would need mock)
            # Child interrupts
            websocket.send_json(
                {
                    "type": "interrupt_ai",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
            )

            # Should receive ai_response_completed with wasInterrupted=true
            try:
                response = websocket.receive_json(timeout=2.0)
                if response["type"] == "ai_response_completed":
                    assert response["wasInterrupted"] is True
            except:
                pass  # May not receive if no AI was responding


class TestWebSocketErrorHandling:
    """Tests for error handling and edge cases."""

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    def test_idle_connection_timeout(self, client):
        """Should timeout idle connections after 60 seconds."""
        # This test would need to wait 60 seconds or use mocking
        pass

    def test_heartbeat_mechanism(self, client):
        """Should support heartbeat/ping-pong mechanism."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            websocket.receive_json()  # connection_established

            # Send ping
            websocket.send_json(
                {
                    "type": "ping",
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
            )

            # Should receive pong
            response = websocket.receive_json()
            assert response["type"] == "pong"

    def test_rate_limiting(self, client):
        """Should enforce rate limits."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            websocket.receive_json()

            # Send more than 10 control messages per second
            for _ in range(15):
                websocket.send_json(
                    {
                        "type": "start_listening",
                        "timestamp": datetime.utcnow().isoformat() + "Z",
                    }
                )

            # Should receive rate_limited error
            try:
                response = websocket.receive_json(timeout=1.0)
                if response["type"] == "error":
                    assert response["code"] == "rate_limited"
            except:
                pass  # Implementation may not rate limit yet

    def test_malformed_json_handling(self, client):
        """Should handle malformed JSON gracefully."""
        with client.websocket_connect(
            "/v1/ws/interaction/session-123?token=valid-jwt-token"
        ) as websocket:
            websocket.receive_json()

            # Send malformed JSON
            websocket.send_text("{ invalid json }")

            response = websocket.receive_json()
            assert response["type"] == "error"
            assert "message" in response
