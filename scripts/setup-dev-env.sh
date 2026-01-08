#!/bin/bash
# Development Environment Setup Script for StoryBuddy
# This script sets up pre-commit hooks and development dependencies

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   StoryBuddy Development Environment Setup      ║${NC}"
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running in project root
if [ ! -f "pyproject.toml" ]; then
    echo -e "${RED}❌ Error: Must run from project root directory${NC}"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print step
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# ==============================================================================
# 1. Check Prerequisites
# ==============================================================================
print_step "Checking prerequisites..."

if ! command_exists python3; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    exit 1
fi
print_success "Python $(python3 --version) found"

if ! command_exists git; then
    echo -e "${RED}❌ Git is not installed${NC}"
    exit 1
fi
print_success "Git $(git --version | cut -d' ' -f3) found"

# Check for Flutter (optional)
if command_exists flutter; then
    print_success "Flutter $(flutter --version | head -n1 | cut -d' ' -f2) found"
    HAS_FLUTTER=true
else
    print_warning "Flutter not found - mobile development will be skipped"
    HAS_FLUTTER=false
fi

echo ""

# ==============================================================================
# 2. Setup Python Virtual Environment
# ==============================================================================
print_step "Setting up Python virtual environment..."

if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Virtual environment created"
else
    print_warning "Virtual environment already exists"
fi

# Activate virtual environment
source venv/bin/activate 2>/dev/null || . venv/bin/activate

print_success "Virtual environment activated"
echo ""

# ==============================================================================
# 3. Install Python Dependencies
# ==============================================================================
print_step "Installing Python dependencies..."

pip install --upgrade pip -q
pip install -e ".[dev]" -q

print_success "Python dependencies installed"
echo ""

# ==============================================================================
# 4. Install Pre-commit
# ==============================================================================
print_step "Installing pre-commit hooks..."

if ! command_exists pre-commit; then
    pip install pre-commit -q
fi

pre-commit install --install-hooks
print_success "Pre-commit hooks installed"
echo ""

# ==============================================================================
# 5. Setup Flutter Dependencies (if available)
# ==============================================================================
if [ "$HAS_FLUTTER" = true ]; then
    print_step "Setting up Flutter dependencies..."
    cd mobile
    flutter pub get
    cd ..
    print_success "Flutter dependencies installed"
    echo ""
fi

# ==============================================================================
# 6. Initialize Secrets Baseline
# ==============================================================================
print_step "Checking secrets baseline..."

if [ ! -f ".secrets.baseline" ]; then
    print_warning "Secrets baseline not found - creating..."
    detect-secrets scan > .secrets.baseline 2>/dev/null || true
    print_success "Secrets baseline created"
else
    print_success "Secrets baseline exists"
fi
echo ""

# ==============================================================================
# 7. Run Initial Pre-commit Check (optional)
# ==============================================================================
echo -e "${YELLOW}Would you like to run pre-commit on all files now? (y/N)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_step "Running pre-commit on all files..."
    pre-commit run --all-files || print_warning "Some checks failed - please review and fix"
    echo ""
fi

# ==============================================================================
# 8. Display Next Steps
# ==============================================================================
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete! 🎉                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo -e "1. Activate the virtual environment:"
echo -e "   ${YELLOW}source venv/bin/activate${NC}"
echo ""
echo -e "2. Run tests:"
echo -e "   ${YELLOW}pytest${NC}"
echo ""
if [ "$HAS_FLUTTER" = true ]; then
    echo -e "3. Run Flutter tests:"
    echo -e "   ${YELLOW}cd mobile && flutter test${NC}"
    echo ""
fi
echo -e "4. Start coding! Pre-commit hooks will run automatically."
echo ""
echo -e "5. For CI/CD setup, see:"
echo -e "   ${YELLOW}.github/CI_SETUP.md${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  ${YELLOW}pre-commit run --all-files${NC}  - Run all hooks manually"
echo -e "  ${YELLOW}ruff check .${NC}                - Lint Python code"
echo -e "  ${YELLOW}mypy src/${NC}                   - Type check Python code"
echo -e "  ${YELLOW}pytest${NC}                       - Run Python tests"
if [ "$HAS_FLUTTER" = true ]; then
    echo -e "  ${YELLOW}flutter analyze${NC}             - Analyze Dart code"
    echo -e "  ${YELLOW}flutter test${NC}                - Run Flutter tests"
fi
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
