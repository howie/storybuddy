<!--
  SYNC IMPACT REPORT
  ==================
  Version Change: (new) -> 1.0.0

  Added Principles:
  - I. Test-First (NON-NEGOTIABLE)
  - II. Modular Design
  - III. Security & Privacy
  - IV. Observability
  - V. Simplicity

  Added Sections:
  - Children's Safety Standards
  - Privacy Requirements
  - Development Workflow
  - Quality Gates
  - Governance

  Removed Sections: None (initial creation)

  Templates Requiring Updates:
  - .specify/templates/plan-template.md: ✅ Constitution Check section aligns
  - .specify/templates/spec-template.md: ✅ No changes needed
  - .specify/templates/tasks-template.md: ✅ No changes needed

  Follow-up TODOs: None
-->

# StoryBuddy Constitution

## Core Principles

### I. Test-First (NON-NEGOTIABLE)

All features MUST follow Test-Driven Development (TDD):
- Tests MUST be written before implementation code
- Tests MUST fail before implementation begins (Red phase)
- Implementation MUST make tests pass with minimal code (Green phase)
- Code MUST be refactored while keeping tests green (Refactor phase)

**Rationale**: TDD ensures code correctness, prevents regressions, and produces testable
architecture. For a children's app handling voice data, reliability is critical.

**Enforcement**: PRs without corresponding tests for new functionality MUST be rejected.

### II. Modular Design

The codebase MUST maintain clear separation of concerns:
- **API Layer**: HTTP routing, request/response handling, validation
- **Service Layer**: Business logic, orchestration, external API integration
- **Data Layer**: Database access, file storage, caching

Each layer MUST be independently testable with mocked dependencies.

**Rationale**: Modularity enables parallel development, easier testing, and cleaner
maintenance. External AI services (ElevenLabs, Azure, Claude) can be swapped without
affecting business logic.

### III. Security & Privacy

Voice data and user information MUST be protected:
- Voice samples MUST be encrypted at rest
- API keys MUST be stored in environment variables, never in code
- User consent MUST be obtained before voice cloning
- Data transmission MUST use HTTPS/TLS

**Rationale**: Voice cloning involves biometric-adjacent data. Children's privacy
requires extra protection under regulations like COPPA.

### IV. Observability

All system behavior MUST be observable:
- Structured logging MUST be used (JSON format preferred)
- Error states MUST include actionable context
- External API calls MUST log request/response summaries (excluding sensitive data)
- Performance metrics SHOULD be collected for critical paths

**Rationale**: Debugging voice/AI integration issues requires visibility into
system state. Parents need confidence the app works correctly for their children.

### V. Simplicity

Solutions MUST favor simplicity over cleverness:
- YAGNI (You Aren't Gonna Need It) - implement only what's needed now
- No premature optimization without measured performance data
- Prefer standard library solutions over external dependencies
- MVP scope MUST be respected - no feature creep

**Rationale**: StoryBuddy MVP targets single-family use. Over-engineering delays
delivery and adds maintenance burden without proportional value.

## Children's Safety Standards

Content generated or displayed to children MUST meet these standards:

- **Age-Appropriate Content**: All AI-generated stories MUST be filtered for
  age-appropriateness using content moderation systems
- **No Harmful Content**: Violence, adult themes, and inappropriate language
  MUST be blocked before reaching children
- **Safe Defaults**: When uncertain, the system MUST err on the side of caution
- **Parental Oversight**: Parents MUST have visibility into all content and
  interactions their children experience
- **Question Boundaries**: Questions outside story scope MUST be deferred to
  parents rather than answered speculatively by AI

**Compliance Note**: Design decisions SHOULD consider COPPA, GDPR-K, and similar
child protection regulations.

## Privacy Requirements

User data handling MUST follow these requirements:

- **Data Minimization**: Collect only data necessary for functionality
- **Consent First**: Obtain explicit consent before voice recording or cloning
- **Local First**: Prefer local storage over cloud when feasible
- **Retention Limits**: Define and enforce data retention policies
- **Deletion Rights**: Users MUST be able to delete their voice data
- **Third-Party Disclosure**: Clearly document what data is sent to external
  services (ElevenLabs, Azure, Anthropic)

## Development Workflow

All development MUST follow this workflow:

1. **Feature Branch**: Create branch from main with format `###-feature-name`
2. **Specification**: Document requirements in `docs/features/###-feature-name/spec.md`
3. **Planning**: Create implementation plan in `plan.md`
4. **Tasks**: Break down into tracked tasks in `tasks.md`
5. **Implementation**: Follow TDD, commit frequently
6. **Review**: PR requires passing tests and code review
7. **Merge**: Squash merge to main after approval

**Commit Message Format**: `type: description`
- Types: feat, fix, docs, test, refactor, chore

## Quality Gates

Code MUST pass these gates before merge:

| Gate | Requirement | Enforcement |
|------|-------------|-------------|
| Tests | All tests pass | CI blocks merge on failure |
| Coverage | New code has tests | PR review |
| Linting | `ruff check .` passes | CI blocks merge on failure |
| Types | `mypy` passes (when configured) | CI warning |
| Security | No secrets in code | Pre-commit hook |
| Docs | Public APIs documented | PR review |

## Governance

This constitution supersedes all other development practices in this repository.

**Amendment Process**:
1. Propose changes via PR modifying this file
2. Document rationale for each change
3. Require maintainer approval
4. Update version according to semantic versioning

**Version Policy**:
- MAJOR: Principle removal or incompatible redefinition
- MINOR: New principle or section added
- PATCH: Clarifications, wording improvements

**Compliance Review**:
- All PRs MUST verify compliance with applicable principles
- Constitution Check in `plan.md` MUST pass before implementation
- Deviations require explicit justification and approval

**Version**: 1.0.0 | **Ratified**: 2026-01-01 | **Last Amended**: 2026-01-01
