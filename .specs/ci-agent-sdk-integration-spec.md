# CI/CD Agent SDK Integration Specification

## 概述 (Overview)

本規範定義如何在 GitHub Actions CI/CD 流程中整合 Claude Agent SDK，實現自動化程式碼審查和錯誤修正功能。

This specification defines how to integrate Claude Agent SDK into GitHub Actions CI/CD pipelines for automated code review and error correction.

## 目標 (Objectives)

1. **自動錯誤修正**: CI 檢查失敗時自動修正 lint、type check 和測試錯誤
2. **智能程式碼審查**: 使用 AI 進行程式碼品質檢查和最佳實踐建議
3. **安全性保障**: 限制 Agent 權限，確保自動化操作的安全性
4. **開發體驗優化**: 減少手動修正錯誤的時間，加快開發迭代

---

## 架構設計 (Architecture Design)

### 1. CI/CD 工作流程結構

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions Trigger                │
│              (push to main / pull_request)               │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │   Job 1: Lint & Test  │
         │   - Python: ruff,     │
         │     mypy, pytest      │
         │   - Flutter: flutter  │
         │     analyze, test     │
         └───────────┬───────────┘
                     │
          ┌─────────┴─────────┐
          │                   │
    ┌─────▼─────┐       ┌────▼────┐
    │  SUCCESS  │       │  FAIL   │
    └─────┬─────┘       └────┬────┘
          │                  │
          │            ┌─────▼──────────────────┐
          │            │  Job 2: Agent Auto-Fix │
          │            │  - Install Claude CLI  │
          │            │  - Run agent with      │
          │            │    limited permissions │
          │            │  - Commit & push fixes │
          │            └─────┬──────────────────┘
          │                  │
          │            ┌─────▼─────┐
          │            │  Re-check │
          │            └─────┬─────┘
          │                  │
    ┌─────▼──────────────────▼─────┐
    │   Job 3: Integration Tests   │
    │   - E2E tests (if applicable) │
    │   - Smoke tests               │
    └──────────────────────────────┘
```

### 2. Agent SDK 整合模式

#### 模式 A: 錯誤觸發型自動修正 (Error-Triggered Auto-Fix)

**使用場景**: Lint、type check、unit test 失敗時自動修正

**工作流程**:
```yaml
auto-fix:
  runs-on: ubuntu-latest
  needs: [check]
  if: failure()
  steps:
    - name: Checkout with PAT
      uses: actions/checkout@v4
      with:
        token: ${{ secrets.GH_PAT }}

    - name: Install Claude CLI
      run: npm install -g @anthropic-ai/claude-code

    - name: Run Auto-Fix Agent
      env:
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      run: |
        claude agent run \
          --model sonnet \
          --allowed-tools "Read,Edit,Bash" \
          --allowed-commands "npm,pip,flutter,git" \
          --max-iterations 5 \
          --prompt "CI checks failed. Fix all lint, type, and test errors. Only make necessary changes."

    - name: Commit and Push Fixes
      run: |
        git config user.name "Claude Agent"
        git config user.email "claude@ci.bot"
        git add -A
        git commit -m "fix(ci): auto-fix lint and test errors" || echo "No changes"
        git push origin ${{ github.head_ref || github.ref_name }}
```

#### 模式 B: 預提交程式碼審查 (Pre-Commit Code Review)

**使用場景**: PR 創建或更新時進行程式碼品質審查

**工作流程**:
```yaml
code-review:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Run Code Review Agent
      env:
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      run: |
        claude agent run \
          --model sonnet \
          --allowed-tools "Read,Grep,Glob,Bash" \
          --output review-report.md \
          --prompt "Review changed files for: 1) Code quality issues, 2) Security vulnerabilities, 3) Performance concerns, 4) Best practice violations. Generate a detailed review report."

    - name: Post Review as Comment
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const review = fs.readFileSync('review-report.md', 'utf8');
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: '## 🤖 Claude Agent Code Review\n\n' + review
          });
```

---

## 多語言支援策略 (Multi-Language Support)

### Python 專案

**檢查項目**:
- `ruff check .` - Linting
- `ruff format --check .` - Formatting
- `mypy .` - Type checking
- `pytest` - Unit tests

**Agent 修正策略**:
```bash
# Agent prompt for Python
"Fix Python code issues:
1. Run 'ruff check --fix .' for linting
2. Run 'ruff format .' for formatting
3. Fix type errors reported by mypy
4. Fix failing pytest tests
Only modify necessary code."
```

### Flutter/Dart 專案

**檢查項目**:
- `flutter analyze` - Static analysis
- `dart format --set-exit-if-changed .` - Formatting
- `flutter test` - Unit/widget tests

**Agent 修正策略**:
```bash
# Agent prompt for Flutter
"Fix Flutter/Dart code issues:
1. Run 'dart format .' to fix formatting
2. Fix issues from 'flutter analyze'
3. Fix failing widget tests
4. Ensure pubspec.yaml dependencies are correct
Only modify necessary code."
```

---

## 安全性與權限控制 (Security & Permissions)

### 1. Agent 工具權限限制

| 工具類別 | 允許工具 | 禁止工具 | 原因 |
|---------|---------|---------|------|
| 檔案操作 | Read, Edit | Write, Delete | 防止創建不必要檔案或刪除重要檔案 |
| 程式執行 | Bash (限定指令) | 不限制的 Bash | 防止執行危險指令 |
| 版本控制 | git add, commit, push | git reset --hard, force push | 防止破壞性操作 |
| 套件管理 | npm/pip/flutter install | - | 允許安裝依賴 |

### 2. 允許的 Bash 指令白名單

```yaml
allowed_commands:
  - npm
  - pip
  - python
  - pytest
  - ruff
  - mypy
  - flutter
  - dart
  - git
```

### 3. API Key 管理

- 使用 GitHub Secrets 儲存 `ANTHROPIC_API_KEY`
- 使用 GitHub PAT (Personal Access Token) 用於 push 操作
- 限制 PAT 權限僅為 repo scope
- 定期輪換 API keys

### 4. 分支保護策略

```yaml
# 建議的分支保護規則
branch_protection:
  require_pull_request: true
  require_code_review: true
  require_status_checks: true
  required_checks:
    - "lint-and-test"
  restrict_pushes: false  # 允許 Agent bot push
  allowed_push_actors:
    - "claude-ci-bot"
```

---

## 錯誤處理與重試機制 (Error Handling & Retry)

### 1. Agent 失敗處理

```yaml
- name: Run Auto-Fix with Retry
  id: auto_fix
  continue-on-error: true
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    max_attempts=3
    attempt=1

    while [ $attempt -le $max_attempts ]; do
      echo "Attempt $attempt of $max_attempts"

      if claude agent run --prompt "Fix CI errors..."; then
        echo "Agent succeeded"
        exit 0
      fi

      attempt=$((attempt + 1))
      sleep 10
    done

    echo "Agent failed after $max_attempts attempts"
    exit 1
```

### 2. 部分成功處理

```yaml
- name: Validate Fixes
  if: steps.auto_fix.outcome == 'success'
  run: |
    # 重新執行檢查確認修正有效
    npm run lint && npm run test

- name: Create Issue if Agent Failed
  if: steps.auto_fix.outcome == 'failure'
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: '🤖 CI Auto-Fix Failed',
        body: 'The Claude Agent was unable to fix CI errors automatically. Manual intervention required.',
        labels: ['ci-failure', 'needs-attention']
      });
```

---

## Pre-commit Hooks 整合 (Pre-commit Integration)

### 1. 本地 Pre-commit 配置

建立 `.pre-commit-config.yaml`:

```yaml
repos:
  # Python linting and formatting
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # Python type checking
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.11.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]

  # Dart/Flutter formatting
  - repo: local
    hooks:
      - id: dart-format
        name: dart format
        entry: dart format
        language: system
        files: \.dart$

      - id: flutter-analyze
        name: flutter analyze
        entry: flutter analyze
        language: system
        pass_filenames: false
        files: \.dart$

  # Generic checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
```

### 2. 安裝與啟用

```bash
# 安裝 pre-commit
pip install pre-commit

# 安裝 hooks
pre-commit install

# 在所有檔案上執行（首次）
pre-commit run --all-files
```

### 3. 與 CI 整合

```yaml
# .github/workflows/pre-commit.yml
name: Pre-commit Checks

on: [push, pull_request]

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - uses: pre-commit/action@v3.0.1
```

---

## 成本與效能優化 (Cost & Performance Optimization)

### 1. Agent 使用成本控制

| 措施 | 說明 | 預期節省 |
|-----|------|---------|
| 限制 max-iterations | 設定最大迭代次數為 5 | 防止無限循環 |
| 使用 Haiku 模型 | 簡單修正使用較小模型 | 降低 50-70% API 成本 |
| 條件觸發 | 僅在失敗時執行 Agent | 減少不必要調用 |
| 快取依賴 | 使用 GitHub Actions cache | 加快執行速度 |

### 2. 模型選擇策略

```yaml
# 根據任務複雜度選擇模型
- name: Determine Model
  id: model
  run: |
    if [[ "${{ needs.check.outputs.error_type }}" == "formatting" ]]; then
      echo "model=haiku" >> $GITHUB_OUTPUT
    elif [[ "${{ needs.check.outputs.error_type }}" == "complex" ]]; then
      echo "model=opus" >> $GITHUB_OUTPUT
    else
      echo "model=sonnet" >> $GITHUB_OUTPUT
    fi

- name: Run Agent
  run: |
    claude agent run --model ${{ steps.model.outputs.model }} ...
```

### 3. 並行執行優化

```yaml
jobs:
  check:
    strategy:
      matrix:
        check: [lint, type, test]
    steps:
      - name: Run ${{ matrix.check }}
        run: npm run ${{ matrix.check }}
```

---

## 監控與分析 (Monitoring & Analytics)

### 1. Agent 執行指標

追蹤以下指標:
- Agent 成功率
- 平均修正時間
- API 成本
- 失敗原因分類

### 2. GitHub Actions 報告

```yaml
- name: Upload Agent Report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: agent-execution-report
    path: |
      agent-log.txt
      fixes-summary.md
    retention-days: 30
```

### 3. 通知整合

```yaml
- name: Notify on Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "CI Agent auto-fix failed for ${{ github.repository }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "🚨 *CI Failure*\n*Repo:* ${{ github.repository }}\n*Branch:* ${{ github.ref_name }}\n*Status:* Agent auto-fix failed"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 實施路線圖 (Implementation Roadmap)

### Phase 1: 基礎設施建立 (週 1-2)
- [ ] 設定 GitHub Actions workflows
- [ ] 配置 pre-commit hooks
- [ ] 設定 secrets (API keys, PAT)
- [ ] Python 專案 lint/test pipeline

### Phase 2: Agent SDK 整合 (週 3-4)
- [ ] 實作錯誤觸發型自動修正
- [ ] 配置 Agent 權限與安全限制
- [ ] 建立錯誤處理與重試機制
- [ ] Flutter 專案整合

### Phase 3: 程式碼審查功能 (週 5-6)
- [ ] 實作 PR 程式碼審查 Agent
- [ ] 整合審查結果到 PR comments
- [ ] 建立審查規則與檢查清單

### Phase 4: 優化與監控 (週 7-8)
- [ ] 成本優化（模型選擇、快取）
- [ ] 建立監控儀表板
- [ ] 效能調優
- [ ] 文件與培訓

---

## 範例配置檔案 (Example Configuration Files)

### 完整 CI Workflow

參見: `.github/workflows/ci.yml` (將在實作階段創建)

### Agent 配置檔

參見: `.claude/agent-config.json` (將在實作階段創建)

---

## 附錄 (Appendix)

### A. 參考資源

- [Claude Agent SDK Documentation](https://github.com/anthropics/claude-code)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Pre-commit Framework](https://pre-commit.com/)
- 參考專案: [hiimoliverwang/cc-demo](https://github.com/hiimoliverwang/cc-demo)

### B. 常見問題

**Q: Agent 會不會引入錯誤的修正？**
A: 通過限制工具權限、設定最大迭代次數，以及在修正後重新執行檢查來降低風險。

**Q: API 成本會不會很高？**
A: 通過使用較小模型處理簡單任務、條件觸發、以及設定 max-iterations 來控制成本。

**Q: 如何處理 Agent 無法修正的情況？**
A: 系統會自動建立 GitHub Issue 通知開發團隊需要人工介入。

**Q: 是否支援多個分支？**
A: 是，workflow 可配置在特定分支（如 main, develop）或所有 PR 上執行。

### C. 更新日誌

- **2026-01-08**: 初始規範創建
  - 定義架構設計
  - 多語言支援策略
  - 安全性與權限控制機制
  - 實施路線圖

---

**文件版本**: v1.0.0
**最後更新**: 2026-01-08
**維護者**: StoryBuddy Development Team
