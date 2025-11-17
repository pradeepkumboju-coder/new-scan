#!/usr/bin/env bash
set -euo pipefail

mkdir -p .detect

PRIMARY_LANG="unknown"
BUILD_TOOL="none"
# SCAN_PROFILE must match a profile filename in profiles/*.yml (without extension)
SCAN_PROFILE="generic"
HAS_DOCKERFILE="false"
IS_MONOREPO="false"
IS_ROOT_WORKSPACE="true"

# Quick helpers
file_exists() { [[ -f "$1" ]]; }
any_file_glob() { ls $1 >/dev/null 2>&1; }

echo "🔍 Starting project detection in $(pwd)"

# Dockerfile
if ls | grep -qi "^Dockerfile"; then
  HAS_DOCKERFILE="true"
fi

# Node / TypeScript
if file_exists "package.json"; then
  if [[ -f "tsconfig.json" ]] || grep -q '"typescript"' package.json 2>/dev/null; then
    PRIMARY_LANG="typescript"
  else
    PRIMARY_LANG="node"
  fi

  if [[ -f "pnpm-lock.yaml" ]]; then
    BUILD_TOOL="pnpm"
    # For Node with pnpm we have an explicit node_pnpm profile
    if [[ "$PRIMARY_LANG" == "node" ]]; then
      SCAN_PROFILE="node_pnpm"
    else
      # TypeScript projects use the generic typescript profile
      SCAN_PROFILE="typescript"
    fi
  elif [[ -f "package-lock.json" ]]; then
    BUILD_TOOL="npm"
    if [[ "$PRIMARY_LANG" == "node" ]]; then
      SCAN_PROFILE="node_npm"
    else
      SCAN_PROFILE="typescript"
    fi
  elif [[ -f "yarn.lock" ]]; then
    BUILD_TOOL="yarn"
    # Use node_npm profile for yarn as well
    if [[ "$PRIMARY_LANG" == "node" ]]; then
      SCAN_PROFILE="node_npm"
    else
      SCAN_PROFILE="typescript"
    fi
  else
    BUILD_TOOL="npm"
    if [[ "$PRIMARY_LANG" == "node" ]]; then
      SCAN_PROFILE="node_npm"
    else
      SCAN_PROFILE="typescript"
    fi
  fi
fi

# Python
if file_exists "pyproject.toml"; then
  PRIMARY_LANG="python"
  if grep -q "\[tool.poetry\]" pyproject.toml 2>/dev/null; then
    BUILD_TOOL="poetry"
    SCAN_PROFILE="python_poetry"
  else
    BUILD_TOOL="pyproject"
    # Treat generic pyproject as pip-based for now
    SCAN_PROFILE="python_pip"
  fi
elif file_exists "requirements.txt"; then
  PRIMARY_LANG="python"
  BUILD_TOOL="pip"
  SCAN_PROFILE="python_pip"
elif file_exists "Pipfile"; then
  PRIMARY_LANG="python"
  BUILD_TOOL="pipenv"
  SCAN_PROFILE="python_pipenv"
fi

# Java
if file_exists "pom.xml"; then
  PRIMARY_LANG="java"
  BUILD_TOOL="maven"
  SCAN_PROFILE="java_maven"
elif file_exists "build.gradle" || file_exists "build.gradle.kts"; then
  PRIMARY_LANG="java"
  BUILD_TOOL="gradle"
  SCAN_PROFILE="java_gradle"
fi

# C#
if ls *.csproj >/dev/null 2>&1; then
  PRIMARY_LANG="csharp"
  BUILD_TOOL="dotnet"
  SCAN_PROFILE="dotnet"
fi

# C/C++
if file_exists "CMakeLists.txt"; then
  PRIMARY_LANG="cpp"
  BUILD_TOOL="cmake"
  SCAN_PROFILE="c_cpp"
elif file_exists "Makefile"; then
  if ls *.cpp >/dev/null 2>&1; then
    PRIMARY_LANG="cpp"
  elif ls *.c >/dev/null 2>&1; then
    PRIMARY_LANG="c"
  fi
  BUILD_TOOL="make"
  SCAN_PROFILE="c_cpp"
elif file_exists "WORKSPACE" || file_exists "BUILD"; then
  PRIMARY_LANG="cpp"
  BUILD_TOOL="bazel"
  SCAN_PROFILE="c_cpp"
fi

# Lua
if ls *.rockspec >/dev/null 2>&1; then
  PRIMARY_LANG="lua"
  BUILD_TOOL="luarocks"
  SCAN_PROFILE="lua"
fi

# Static frontend
if [[ "$PRIMARY_LANG" == "unknown" ]]; then
  if ls *.html *.css 2>/dev/null | grep -q .; then
    PRIMARY_LANG="frontend"
    BUILD_TOOL="none"
    SCAN_PROFILE="html_css"
  fi
fi

# Infra (terraform)
if [[ "$PRIMARY_LANG" == "unknown" ]] && ls *.tf >/dev/null 2>&1; then
  PRIMARY_LANG="infra"
  # Use generic profile for infra until a dedicated one is added
  SCAN_PROFILE="generic"
fi

# GitHub languages fallback (requires GITHUB_TOKEN to be available)
if [[ "$PRIMARY_LANG" == "unknown" ]] && [[ -n "${GITHUB_TOKEN:-}" ]] && [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  API_LANG=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}/languages" \
            | jq -r 'keys[0]' 2>/dev/null || true)
  if [[ -n "$API_LANG" ]] && [[ "$API_LANG" != "null" ]]; then
    PRIMARY_LANG=$(echo "$API_LANG" | tr '[:upper:]' '[:lower:]')
    # Fallback to generic profile when we only know the language
    SCAN_PROFILE="generic"
  fi
fi

# Write outputs
echo "$PRIMARY_LANG" > .detect/primary_language
echo "$BUILD_TOOL"   > .detect/build_tool
echo "$SCAN_PROFILE" > .detect/scan_profile
echo "$HAS_DOCKERFILE" > .detect/has_dockerfile
echo "$IS_MONOREPO"  > .detect/is_monorepo
echo "$IS_ROOT_WORKSPACE" > .detect/is_root_workspace

echo "Detection result: language=$PRIMARY_LANG build_tool=$BUILD_TOOL scan_profile=$SCAN_PROFILE docker=$HAS_DOCKERFILE"
