# CI/CD Setup Guide

## 概述 (Overview)

此專案使用 GitHub Actions 與 Claude Agent SDK 實現自動化 CI/CD，包含程式碼檢查、自動修正和程式碼審查功能。

This project uses GitHub Actions with Claude Agent SDK for automated CI/CD, including code checks, auto-fixing, and code review.

## 必要設定 (Required Setup)

### 1. GitHub Secrets

在 GitHub repository 設定中新增以下 secrets：

Navigate to: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `ANTHROPIC_API_KEY` | Claude API key for Agent SDK | Get from [console.anthropic.com](https://console.anthropic.com/) |
| `GITHUB_PAT` | Personal Access Token for pushing fixes | Create at [github.com/settings/tokens](https://github.com/settings/tokens) |

#### GitHub PAT 設定:

1. 前往 GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 點擊 "Generate new token (classic)"
3. 設定以下權限:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
4. 複製 token 並新增為 secret `GITHUB_PAT`

### 2. Pre-commit Hooks (本地開發)

```bash
# 安裝 pre-commit
pip install pre-commit

# 安裝 hooks 到 git
pre-commit install

# (可選) 在所有檔案上執行一次
pre-commit run --all-files
```

### 3. Python 開發環境

```bash
# 建立虛擬環境
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 或: venv\Scripts\activate  # Windows

# 安裝開發依賴
pip install -e ".[dev]"
```

### 4. Flutter 開發環境

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

## CI/CD 工作流程 (Workflows)

### 主要 CI 流程 (`ci.yml`)

**觸發時機**:
- Push 到 `main`, `develop`, 或 `claude/**` 分支
- Pull request 到 `main` 或 `develop`

**工作流程**:

```
1. Python Check & Flutter Check (並行執行)
   ├─ Ruff linting
   ├─ Ruff formatting
   ├─ MyPy type checking
   ├─ Pytest unit tests
   ├─ Flutter analyze
   ├─ Dart format
   └─ Flutter tests

2a. ✅ 成功 → Integration Tests
2b. ❌ 失敗 → Agent Auto-Fix
   ├─ 安裝 Claude CLI
   ├─ 執行 Agent 修正錯誤
   ├─ 重新執行檢查驗證
   ├─ Commit & Push 修正
   └─ (失敗時) 建立 GitHub Issue

3. Code Review (僅 PR)
   ├─ 分析變更檔案
   ├─ AI 程式碼審查
   └─ 發布審查評論
```

### Agent Auto-Fix 特性

**支援的修正類型**:
- 🐍 Python: Ruff linting, formatting, MyPy types, pytest failures
- 📱 Flutter: Dart formatting, Flutter analyze issues, test failures

**智能模型選擇**:
- `haiku`: 簡單的格式化問題 (快速 & 便宜)
- `sonnet`: 標準的 linting 和測試問題
- `opus`: 複雜的類型錯誤 (未使用，可按需啟用)

**安全限制**:
- 僅允許 `Read`, `Edit`, `Bash` 工具
- Bash 指令限制為: `ruff`, `mypy`, `pytest`, `flutter`, `dart`, `git`
- 最大迭代次數: 3-5 (依錯誤類型)
- 重試機制: 最多 3 次嘗試

## 程式碼審查 Agent (Code Review)

當建立或更新 PR 時自動觸發:

**審查範圍**:
1. 程式碼品質 (可讀性、可維護性)
2. 安全性 (SQL injection, XSS, etc.)
3. 效能問題
4. 測試覆蓋率
5. 架構設計
6. 語言特定最佳實踐

**輸出**: 詳細的 Markdown 審查報告作為 PR comment

## 本地開發工作流程 (Local Development Workflow)

### 建議的開發流程:

```bash
# 1. 建立新分支
git checkout -b feature/your-feature

# 2. 開發程式碼
# ... 編寫程式碼 ...

# 3. Pre-commit hooks 會自動執行
git add .
git commit -m "feat: your feature"
# → Pre-commit hooks 自動檢查和修正

# 4. 推送到 GitHub
git push -u origin feature/your-feature

# 5. CI 自動執行
# → 如果失敗，Agent 會自動嘗試修正並 push

# 6. 建立 Pull Request
# → Code Review Agent 自動審查
```

### 手動執行檢查:

```bash
# Python
ruff check .
ruff format .
mypy src/
pytest

# Flutter
cd mobile
flutter analyze
dart format .
flutter test
```

## 監控與除錯 (Monitoring & Debugging)

### 查看 CI 狀態

1. GitHub Actions tab: 查看所有 workflow runs
2. Pull Request checks: 查看每個 PR 的檢查狀態
3. Issues: Agent 失敗時會自動建立 issue

### 查看 Agent 日誌

Workflow 執行後可下載 artifacts:
- `python-agent-logs`: Agent 執行日誌
- `code-review-report`: 程式碼審查報告
- `*-coverage`: 測試覆蓋率報告

### 常見問題排除

**Q: Agent auto-fix 失敗怎麼辦？**

A: 查看自動建立的 GitHub Issue，包含失敗原因和需要手動修正的項目。

**Q: Pre-commit hooks 太慢？**

A: 可以跳過特定 hook:
```bash
SKIP=mypy git commit -m "..."
```

**Q: 如何停用 Agent auto-fix？**

A: 在 commit message 中加入 `[skip ci]` 或修改 `.github/workflows/ci.yml`:
```yaml
python-auto-fix:
  if: false  # 停用
```

**Q: 如何增加 Agent 重試次數？**

A: 修改 `ci.yml` 中的 `max_attempts` 變數。

## 成本優化 (Cost Optimization)

### API 使用估算:

| 場景 | 模型 | 估計 Token | 約成本 (USD) |
|-----|------|-----------|-------------|
| 簡單格式化修正 | Haiku | ~5K | $0.01 |
| 標準 linting 修正 | Sonnet | ~15K | $0.05 |
| 複雜類型錯誤修正 | Sonnet | ~30K | $0.10 |
| 程式碼審查 (PR) | Sonnet | ~20K | $0.06 |

**每月估算** (假設 100 次 CI runs):
- 80% 成功無需 Agent: $0
- 15% 簡單修正: $0.15
- 5% 複雜修正: $0.50
- 20 個 PR 審查: $1.20

**總計**: ~$2-5 / 月 (取決於專案活動)

### 節省成本建議:

1. ✅ 啟用本地 pre-commit hooks (減少 CI 失敗)
2. ✅ 使用分支保護避免直接 push 到 main
3. ✅ 限制 Agent 最大迭代次數
4. ✅ 使用 Haiku 處理簡單問題

## 進階配置 (Advanced Configuration)

### 自訂 Agent Prompt

編輯 `.github/workflows/ci.yml` 中的 `--prompt` 參數來自訂 Agent 行為。

### 新增額外檢查

在 `ci.yml` 中新增步驟:

```yaml
- name: Custom Security Scan
  run: |
    # Your custom security scanning tool
    bandit -r src/
```

### 整合其他工具

- **Codecov**: 上傳測試覆蓋率
- **SonarCloud**: 程式碼品質分析
- **Dependabot**: 依賴更新
- **Slack**: 通知整合

## 參考資源 (References)

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Claude Agent SDK](https://github.com/anthropics/claude-code)
- [Pre-commit Framework](https://pre-commit.com/)
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [Flutter CI/CD](https://docs.flutter.dev/deployment/cd)

## 支援 (Support)

如有問題請:
1. 查看 GitHub Issues
2. 查閱 `.specs/ci-agent-sdk-integration-spec.md` 完整規範
3. 聯絡開發團隊

---

**最後更新**: 2026-01-08
**維護者**: StoryBuddy Development Team
