"""Database repository with CRUD operations for StoryBuddy entities."""

from datetime import datetime
from uuid import UUID, uuid4

from src.db.init import get_db_connection
from src.models import (
    MessageRole,
    PendingQuestionStatus,
    QASessionStatus,
    StorySource,
    VoiceProfileStatus,
)
from src.models.parent import Parent, ParentCreate, ParentUpdate
from src.models.qa import (
    QAMessage,
    QAMessageCreate,
    QASession,
    QASessionCreate,
    QASessionUpdate,
)
from src.models.question import (
    PendingQuestion,
    PendingQuestionCreate,
)
from src.models.story import Story, StoryCreate, StoryUpdate
from src.models.voice import (
    VoiceAudio,
    VoiceAudioCreate,
    VoiceProfile,
    VoiceProfileCreate,
    VoiceProfileUpdate,
)


class ParentRepository:
    """Repository for Parent CRUD operations."""

    @staticmethod
    async def create(data: ParentCreate) -> Parent:
        """Create a new parent."""
        parent_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO parent (id, name, email, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (parent_id, data.name, data.email, now, now),
            )
            await db.commit()

            return Parent(
                id=UUID(parent_id),
                name=data.name,
                email=data.email,
                created_at=datetime.fromisoformat(now),
                updated_at=datetime.fromisoformat(now),
            )

    @staticmethod
    async def get_by_id(parent_id: UUID) -> Parent | None:
        """Get a parent by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM parent WHERE id = ?",
                (str(parent_id),),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return Parent(
                id=UUID(row["id"]),
                name=row["name"],
                email=row["email"],
                created_at=datetime.fromisoformat(row["created_at"]),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )

    @staticmethod
    async def get_all(limit: int = 100, offset: int = 0) -> list[Parent]:
        """Get all parents with pagination."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                SELECT * FROM parent
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                (limit, offset),
            )
            rows = await cursor.fetchall()

            return [
                Parent(
                    id=UUID(row["id"]),
                    name=row["name"],
                    email=row["email"],
                    created_at=datetime.fromisoformat(row["created_at"]),
                    updated_at=datetime.fromisoformat(row["updated_at"]),
                )
                for row in rows
            ]

    @staticmethod
    async def update(parent_id: UUID, data: ParentUpdate) -> Parent | None:
        """Update an existing parent."""
        # Get current parent
        current = await ParentRepository.get_by_id(parent_id)
        if current is None:
            return None

        # Build update fields
        update_fields = {}
        if data.name is not None:
            update_fields["name"] = data.name
        if data.email is not None:
            update_fields["email"] = data.email

        if not update_fields:
            return current

        update_fields["updated_at"] = datetime.utcnow().isoformat()

        # Build SQL
        set_clause = ", ".join(f"{k} = ?" for k in update_fields)
        values = list(update_fields.values()) + [str(parent_id)]

        async with get_db_connection() as db:
            await db.execute(
                f"UPDATE parent SET {set_clause} WHERE id = ?",
                values,
            )
            await db.commit()

        return await ParentRepository.get_by_id(parent_id)

    @staticmethod
    async def delete(parent_id: UUID) -> bool:
        """Delete a parent by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "DELETE FROM parent WHERE id = ?",
                (str(parent_id),),
            )
            await db.commit()
            return cursor.rowcount > 0

    @staticmethod
    async def get_by_email(email: str) -> Parent | None:
        """Get a parent by email."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM parent WHERE email = ?",
                (email,),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return Parent(
                id=UUID(row["id"]),
                name=row["name"],
                email=row["email"],
                created_at=datetime.fromisoformat(row["created_at"]),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )


class VoiceProfileRepository:
    """Repository for VoiceProfile CRUD operations."""

    @staticmethod
    async def create(data: VoiceProfileCreate) -> VoiceProfile:
        """Create a new voice profile."""
        profile_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO voice_profile (id, parent_id, name, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    profile_id,
                    str(data.parent_id),
                    data.name,
                    VoiceProfileStatus.PENDING.value,
                    now,
                    now,
                ),
            )
            await db.commit()

            return VoiceProfile(
                id=UUID(profile_id),
                parent_id=data.parent_id,
                name=data.name,
                elevenlabs_voice_id=None,
                status=VoiceProfileStatus.PENDING,
                sample_duration_seconds=None,
                created_at=datetime.fromisoformat(now),
                updated_at=datetime.fromisoformat(now),
            )

    @staticmethod
    async def get_by_id(profile_id: UUID) -> VoiceProfile | None:
        """Get a voice profile by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM voice_profile WHERE id = ?",
                (str(profile_id),),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return VoiceProfile(
                id=UUID(row["id"]),
                parent_id=UUID(row["parent_id"]),
                name=row["name"],
                elevenlabs_voice_id=row["elevenlabs_voice_id"],
                status=VoiceProfileStatus(row["status"]),
                sample_duration_seconds=row["sample_duration_seconds"],
                created_at=datetime.fromisoformat(row["created_at"]),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )

    @staticmethod
    async def get_by_parent_id(parent_id: UUID) -> list[VoiceProfile]:
        """Get all voice profiles for a parent."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                SELECT * FROM voice_profile
                WHERE parent_id = ?
                ORDER BY created_at DESC
                """,
                (str(parent_id),),
            )
            rows = await cursor.fetchall()

            return [
                VoiceProfile(
                    id=UUID(row["id"]),
                    parent_id=UUID(row["parent_id"]),
                    name=row["name"],
                    elevenlabs_voice_id=row["elevenlabs_voice_id"],
                    status=VoiceProfileStatus(row["status"]),
                    sample_duration_seconds=row["sample_duration_seconds"],
                    created_at=datetime.fromisoformat(row["created_at"]),
                    updated_at=datetime.fromisoformat(row["updated_at"]),
                )
                for row in rows
            ]

    @staticmethod
    async def update(profile_id: UUID, data: VoiceProfileUpdate) -> VoiceProfile | None:
        """Update an existing voice profile."""
        current = await VoiceProfileRepository.get_by_id(profile_id)
        if current is None:
            return None

        update_fields: dict[str, str | int | None] = {}
        if data.name is not None:
            update_fields["name"] = data.name
        if data.elevenlabs_voice_id is not None:
            update_fields["elevenlabs_voice_id"] = data.elevenlabs_voice_id
        if data.status is not None:
            update_fields["status"] = data.status.value
        if data.sample_duration_seconds is not None:
            update_fields["sample_duration_seconds"] = data.sample_duration_seconds

        if not update_fields:
            return current

        update_fields["updated_at"] = datetime.utcnow().isoformat()

        set_clause = ", ".join(f"{k} = ?" for k in update_fields)
        values = list(update_fields.values()) + [str(profile_id)]

        async with get_db_connection() as db:
            await db.execute(
                f"UPDATE voice_profile SET {set_clause} WHERE id = ?",
                values,
            )
            await db.commit()

        return await VoiceProfileRepository.get_by_id(profile_id)

    @staticmethod
    async def delete(profile_id: UUID) -> bool:
        """Delete a voice profile by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "DELETE FROM voice_profile WHERE id = ?",
                (str(profile_id),),
            )
            await db.commit()
            return cursor.rowcount > 0


class VoiceAudioRepository:
    """Repository for VoiceAudio CRUD operations."""

    @staticmethod
    async def create(data: VoiceAudioCreate) -> VoiceAudio:
        """Create a new voice audio record."""
        audio_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO voice_audio
                (id, voice_profile_id, file_path, file_size_bytes, duration_seconds, format, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    audio_id,
                    str(data.voice_profile_id),
                    data.file_path,
                    data.file_size_bytes,
                    data.duration_seconds,
                    data.format,
                    now,
                ),
            )
            await db.commit()

            return VoiceAudio(
                id=UUID(audio_id),
                voice_profile_id=data.voice_profile_id,
                file_path=data.file_path,
                file_size_bytes=data.file_size_bytes,
                duration_seconds=data.duration_seconds,
                format=data.format,
                created_at=datetime.fromisoformat(now),
            )

    @staticmethod
    async def get_by_profile_id(profile_id: UUID) -> list[VoiceAudio]:
        """Get all audio files for a voice profile."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                SELECT * FROM voice_audio
                WHERE voice_profile_id = ?
                ORDER BY created_at DESC
                """,
                (str(profile_id),),
            )
            rows = await cursor.fetchall()

            return [
                VoiceAudio(
                    id=UUID(row["id"]),
                    voice_profile_id=UUID(row["voice_profile_id"]),
                    file_path=row["file_path"],
                    file_size_bytes=row["file_size_bytes"],
                    duration_seconds=row["duration_seconds"],
                    format=row["format"],
                    created_at=datetime.fromisoformat(row["created_at"]),
                )
                for row in rows
            ]


class StoryRepository:
    """Repository for Story CRUD operations."""

    @staticmethod
    async def create(data: StoryCreate) -> Story:
        """Create a new story."""
        import json

        story_id = str(uuid4())
        now = datetime.utcnow().isoformat()
        word_count = Story.calculate_word_count(data.content)
        estimated_duration = Story.calculate_duration_minutes(word_count)
        keywords_json = json.dumps(data.keywords) if data.keywords else None

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO story (
                    id, parent_id, title, content, source, keywords,
                    word_count, estimated_duration_minutes, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    story_id,
                    str(data.parent_id),
                    data.title,
                    data.content,
                    data.source.value,
                    keywords_json,
                    word_count,
                    estimated_duration,
                    now,
                    now,
                ),
            )
            await db.commit()

            return Story(
                id=UUID(story_id),
                parent_id=data.parent_id,
                title=data.title,
                content=data.content,
                source=data.source,
                keywords=data.keywords,
                word_count=word_count,
                estimated_duration_minutes=estimated_duration,
                audio_file_path=None,
                audio_generated_at=None,
                created_at=datetime.fromisoformat(now),
                updated_at=datetime.fromisoformat(now),
            )

    @staticmethod
    async def get_by_id(story_id: UUID) -> Story | None:
        """Get a story by ID."""
        import json

        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM story WHERE id = ?",
                (str(story_id),),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            keywords = json.loads(row["keywords"]) if row["keywords"] else None

            return Story(
                id=UUID(row["id"]),
                parent_id=UUID(row["parent_id"]),
                title=row["title"],
                content=row["content"],
                source=StorySource(row["source"]),
                keywords=keywords,
                word_count=row["word_count"],
                estimated_duration_minutes=row["estimated_duration_minutes"],
                audio_file_path=row["audio_file_path"],
                audio_generated_at=(
                    datetime.fromisoformat(row["audio_generated_at"])
                    if row["audio_generated_at"]
                    else None
                ),
                created_at=datetime.fromisoformat(row["created_at"]),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )

    @staticmethod
    async def get_by_parent_id(
        parent_id: UUID,
        source: StorySource | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Story], int]:
        """Get all stories for a parent with pagination."""
        import json

        async with get_db_connection() as db:
            # Build query with optional source filter
            where_clause = "WHERE parent_id = ?"
            params: list[str | int] = [str(parent_id)]

            if source is not None:
                where_clause += " AND source = ?"
                params.append(source.value)

            # Get total count
            count_cursor = await db.execute(
                f"SELECT COUNT(*) FROM story {where_clause}",
                params,
            )
            count_row = await count_cursor.fetchone()
            total = count_row[0] if count_row else 0

            # Get paginated results
            cursor = await db.execute(
                f"""
                SELECT * FROM story
                {where_clause}
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                [*params, limit, offset],
            )
            rows = await cursor.fetchall()

            stories = [
                Story(
                    id=UUID(row["id"]),
                    parent_id=UUID(row["parent_id"]),
                    title=row["title"],
                    content=row["content"],
                    source=StorySource(row["source"]),
                    keywords=json.loads(row["keywords"]) if row["keywords"] else None,
                    word_count=row["word_count"],
                    estimated_duration_minutes=row["estimated_duration_minutes"],
                    audio_file_path=row["audio_file_path"],
                    audio_generated_at=(
                        datetime.fromisoformat(row["audio_generated_at"])
                        if row["audio_generated_at"]
                        else None
                    ),
                    created_at=datetime.fromisoformat(row["created_at"]),
                    updated_at=datetime.fromisoformat(row["updated_at"]),
                )
                for row in rows
            ]

            return stories, total

    @staticmethod
    async def update(story_id: UUID, data: StoryUpdate) -> Story | None:
        """Update an existing story."""
        current = await StoryRepository.get_by_id(story_id)
        if current is None:
            return None

        update_fields: dict[str, str | int | None] = {}
        if data.title is not None:
            update_fields["title"] = data.title
        if data.content is not None:
            update_fields["content"] = data.content
            word_count = Story.calculate_word_count(data.content)
            update_fields["word_count"] = word_count
            update_fields["estimated_duration_minutes"] = Story.calculate_duration_minutes(
                word_count
            )

        if not update_fields:
            return current

        update_fields["updated_at"] = datetime.utcnow().isoformat()

        set_clause = ", ".join(f"{k} = ?" for k in update_fields)
        values = list(update_fields.values()) + [str(story_id)]

        async with get_db_connection() as db:
            await db.execute(
                f"UPDATE story SET {set_clause} WHERE id = ?",
                values,
            )
            await db.commit()

        return await StoryRepository.get_by_id(story_id)

    @staticmethod
    async def delete(story_id: UUID) -> bool:
        """Delete a story by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "DELETE FROM story WHERE id = ?",
                (str(story_id),),
            )
            await db.commit()
            return cursor.rowcount > 0

    @staticmethod
    async def update_audio(story_id: UUID, audio_file_path: str) -> Story | None:
        """Update story with generated audio file path."""
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                UPDATE story
                SET audio_file_path = ?, audio_generated_at = ?, updated_at = ?
                WHERE id = ?
                """,
                (audio_file_path, now, now, str(story_id)),
            )
            await db.commit()

            if cursor.rowcount == 0:
                return None

        return await StoryRepository.get_by_id(story_id)


class QASessionRepository:
    """Repository for QASession CRUD operations."""

    @staticmethod
    async def create(data: QASessionCreate) -> QASession:
        """Create a new Q&A session."""
        session_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO qa_session (id, story_id, started_at, message_count, status)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    session_id,
                    str(data.story_id),
                    now,
                    0,
                    QASessionStatus.ACTIVE.value,
                ),
            )
            await db.commit()

            return QASession(
                id=UUID(session_id),
                story_id=data.story_id,
                started_at=datetime.fromisoformat(now),
                ended_at=None,
                message_count=0,
                status=QASessionStatus.ACTIVE,
            )

    @staticmethod
    async def get_by_id(session_id: UUID) -> QASession | None:
        """Get a Q&A session by ID."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM qa_session WHERE id = ?",
                (str(session_id),),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return QASession(
                id=UUID(row["id"]),
                story_id=UUID(row["story_id"]),
                started_at=datetime.fromisoformat(row["started_at"]),
                ended_at=(datetime.fromisoformat(row["ended_at"]) if row["ended_at"] else None),
                message_count=row["message_count"],
                status=QASessionStatus(row["status"]),
            )

    @staticmethod
    async def update(session_id: UUID, data: QASessionUpdate) -> QASession | None:
        """Update an existing Q&A session."""
        current = await QASessionRepository.get_by_id(session_id)
        if current is None:
            return None

        update_fields: dict[str, str | int | None] = {}
        if data.status is not None:
            update_fields["status"] = data.status.value
        if data.ended_at is not None:
            update_fields["ended_at"] = data.ended_at.isoformat()

        if not update_fields:
            return current

        set_clause = ", ".join(f"{k} = ?" for k in update_fields)
        values = list(update_fields.values()) + [str(session_id)]

        async with get_db_connection() as db:
            await db.execute(
                f"UPDATE qa_session SET {set_clause} WHERE id = ?",
                values,
            )
            await db.commit()

        return await QASessionRepository.get_by_id(session_id)

    @staticmethod
    async def increment_message_count(session_id: UUID) -> QASession | None:
        """Increment the message count for a session."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                UPDATE qa_session
                SET message_count = message_count + 1
                WHERE id = ? AND message_count < 10
                """,
                (str(session_id),),
            )
            await db.commit()

            if cursor.rowcount == 0:
                return None

        return await QASessionRepository.get_by_id(session_id)

    @staticmethod
    async def get_by_story_id(story_id: UUID) -> list[QASession]:
        """Get all Q&A sessions for a story."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                SELECT * FROM qa_session
                WHERE story_id = ?
                ORDER BY started_at DESC
                """,
                (str(story_id),),
            )
            rows = await cursor.fetchall()

            return [
                QASession(
                    id=UUID(row["id"]),
                    story_id=UUID(row["story_id"]),
                    started_at=datetime.fromisoformat(row["started_at"]),
                    ended_at=(datetime.fromisoformat(row["ended_at"]) if row["ended_at"] else None),
                    message_count=row["message_count"],
                    status=QASessionStatus(row["status"]),
                )
                for row in rows
            ]


class QAMessageRepository:
    """Repository for QAMessage CRUD operations."""

    @staticmethod
    async def create(data: QAMessageCreate) -> QAMessage:
        """Create a new Q&A message."""
        message_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO qa_message (
                    id, session_id, role, content, is_in_scope,
                    audio_input_path, audio_output_path, created_at, sequence
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    message_id,
                    str(data.session_id),
                    data.role.value,
                    data.content,
                    1 if data.is_in_scope else 0 if data.is_in_scope is not None else None,
                    data.audio_input_path,
                    data.audio_output_path,
                    now,
                    data.sequence,
                ),
            )
            await db.commit()

            return QAMessage(
                id=UUID(message_id),
                session_id=data.session_id,
                role=data.role,
                content=data.content,
                is_in_scope=data.is_in_scope,
                audio_input_path=data.audio_input_path,
                audio_output_path=data.audio_output_path,
                created_at=datetime.fromisoformat(now),
                sequence=data.sequence,
            )

    @staticmethod
    async def get_by_session_id(session_id: UUID) -> list[QAMessage]:
        """Get all messages for a Q&A session."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                SELECT * FROM qa_message
                WHERE session_id = ?
                ORDER BY sequence ASC
                """,
                (str(session_id),),
            )
            rows = await cursor.fetchall()

            return [
                QAMessage(
                    id=UUID(row["id"]),
                    session_id=UUID(row["session_id"]),
                    role=MessageRole(row["role"]),
                    content=row["content"],
                    is_in_scope=(
                        bool(row["is_in_scope"]) if row["is_in_scope"] is not None else None
                    ),
                    audio_input_path=row["audio_input_path"],
                    audio_output_path=row["audio_output_path"],
                    created_at=datetime.fromisoformat(row["created_at"]),
                    sequence=row["sequence"],
                )
                for row in rows
            ]

    @staticmethod
    async def get_message_count(session_id: UUID) -> int:
        """Get the message count for a session."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT COUNT(*) FROM qa_message WHERE session_id = ?",
                (str(session_id),),
            )
            row = await cursor.fetchone()
            return row[0] if row else 0


class PendingQuestionRepository:
    """Repository for PendingQuestion CRUD operations."""

    @staticmethod
    async def create(data: PendingQuestionCreate) -> PendingQuestion:
        """Create a new pending question."""

        question_id = str(uuid4())
        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            await db.execute(
                """
                INSERT INTO pending_question (
                    id, parent_id, story_id, question, asked_at, status
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    question_id,
                    str(data.parent_id),
                    str(data.story_id) if data.story_id else None,
                    data.question,
                    now,
                    PendingQuestionStatus.PENDING.value,
                ),
            )
            await db.commit()

            return PendingQuestion(
                id=UUID(question_id),
                parent_id=data.parent_id,
                story_id=data.story_id,
                qa_session_id=data.qa_session_id,
                question=data.question,
                asked_at=datetime.fromisoformat(now),
                answer=None,
                answer_audio_path=None,
                answered_at=None,
                status=PendingQuestionStatus.PENDING,
            )

    @staticmethod
    async def get_by_id(question_id: UUID) -> PendingQuestion | None:
        """Get a pending question by ID."""

        async with get_db_connection() as db:
            cursor = await db.execute(
                "SELECT * FROM pending_question WHERE id = ?",
                (str(question_id),),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return PendingQuestion(
                id=UUID(row["id"]),
                parent_id=UUID(row["parent_id"]),
                story_id=UUID(row["story_id"]) if row["story_id"] else None,
                qa_session_id=None,
                question=row["question"],
                asked_at=datetime.fromisoformat(row["asked_at"]),
                answer=row["answer"],
                answer_audio_path=row["answer_audio_path"],
                answered_at=(
                    datetime.fromisoformat(row["answered_at"]) if row["answered_at"] else None
                ),
                status=PendingQuestionStatus(row["status"]),
            )

    @staticmethod
    async def get_by_parent_id(
        parent_id: UUID,
        status: PendingQuestionStatus | None = None,
    ) -> list[PendingQuestion]:
        """Get all pending questions for a parent."""

        async with get_db_connection() as db:
            if status:
                cursor = await db.execute(
                    """
                    SELECT * FROM pending_question
                    WHERE parent_id = ? AND status = ?
                    ORDER BY asked_at DESC
                    """,
                    (str(parent_id), status.value),
                )
            else:
                cursor = await db.execute(
                    """
                    SELECT * FROM pending_question
                    WHERE parent_id = ?
                    ORDER BY asked_at DESC
                    """,
                    (str(parent_id),),
                )
            rows = await cursor.fetchall()

            return [
                PendingQuestion(
                    id=UUID(row["id"]),
                    parent_id=UUID(row["parent_id"]),
                    story_id=UUID(row["story_id"]) if row["story_id"] else None,
                    qa_session_id=None,
                    question=row["question"],
                    asked_at=datetime.fromisoformat(row["asked_at"]),
                    answer=row["answer"],
                    answer_audio_path=row["answer_audio_path"],
                    answered_at=(
                        datetime.fromisoformat(row["answered_at"]) if row["answered_at"] else None
                    ),
                    status=PendingQuestionStatus(row["status"]),
                )
                for row in rows
            ]

    @staticmethod
    async def answer_question(
        question_id: UUID,
        answer: str,
        answer_audio_path: str | None = None,
    ) -> PendingQuestion | None:
        """Answer a pending question."""

        now = datetime.utcnow().isoformat()

        async with get_db_connection() as db:
            cursor = await db.execute(
                """
                UPDATE pending_question
                SET answer = ?, answer_audio_path = ?, answered_at = ?, status = ?
                WHERE id = ?
                """,
                (
                    answer,
                    answer_audio_path,
                    now,
                    PendingQuestionStatus.ANSWERED.value,
                    str(question_id),
                ),
            )
            await db.commit()

            if cursor.rowcount == 0:
                return None

        return await PendingQuestionRepository.get_by_id(question_id)

    @staticmethod
    async def find_answered_question(parent_id: UUID, question_text: str) -> PendingQuestion | None:
        """Find if a similar question has been answered before."""

        async with get_db_connection() as db:
            # Simple exact match for now - could be enhanced with fuzzy matching
            cursor = await db.execute(
                """
                SELECT * FROM pending_question
                WHERE parent_id = ? AND question = ? AND status = ?
                LIMIT 1
                """,
                (str(parent_id), question_text, PendingQuestionStatus.ANSWERED.value),
            )
            row = await cursor.fetchone()

            if row is None:
                return None

            return PendingQuestion(
                id=UUID(row["id"]),
                parent_id=UUID(row["parent_id"]),
                story_id=UUID(row["story_id"]) if row["story_id"] else None,
                qa_session_id=None,
                question=row["question"],
                asked_at=datetime.fromisoformat(row["asked_at"]),
                answer=row["answer"],
                answer_audio_path=row["answer_audio_path"],
                answered_at=(
                    datetime.fromisoformat(row["answered_at"]) if row["answered_at"] else None
                ),
                status=PendingQuestionStatus(row["status"]),
            )

    @staticmethod
    async def delete(question_id: UUID) -> bool:
        """Delete a pending question."""
        async with get_db_connection() as db:
            cursor = await db.execute(
                "DELETE FROM pending_question WHERE id = ?",
                (str(question_id),),
            )
            await db.commit()
            return cursor.rowcount > 0
