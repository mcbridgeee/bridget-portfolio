#!/usr/bin/env bash
set -e

echo "=== Quality Gates Setup Script ==="

# 1. Sanity checks
if [ ! -f package.json ]; then
  echo "No package.json found. Run 'npm init -y' first, then rerun this script."
  exit 1
fi

# 2. Install dev dependencies
echo "Installing dev dependencies (Prettier, ESLint, Stylelint, Husky, Lighthouse CI)..."
npm install --save-dev \
  prettier \
  eslint \
  stylelint \
  stylelint-config-standard \
  husky \
  @lhci/cli

# 3. Create Prettier config
echo "Creating .prettierrc and .prettierignore..."
cat > .prettierrc << 'EOF'
{
  "printWidth": 80,
  "singleQuote": true,
  "trailingComma": "es5",
  "semi": true,
  "tabWidth": 2
}
EOF

cat > .prettierignore << 'EOF'
node_modules
_site
dist
coverage
.build
.cache
*.min.js
EOF

# 4. Create ESLint config
echo "Creating .eslintrc.cjs and .eslintignore..."
cat > .eslintrc.cjs << 'EOF'
/** @type {import('eslint').Linter.Config} */
module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true
  },
  extends: ['eslint:recommended'],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    'no-undef': 'error',
    'no-console': 'off'
  },
  ignorePatterns: ['_site/**', 'dist/**', 'node_modules/**']
};
EOF

cat > .eslintignore << 'EOF'
node_modules
_site
dist
coverage
EOF

# 5. Create Stylelint config
echo "Creating .stylelintrc.json and .stylelintignore..."
cat > .stylelintrc.json << 'EOF'
{
  "extends": ["stylelint-config-standard"],
  "rules": {
    "color-hex-case": "lower",
    "color-hex-length": "short",
    "block-no-empty": true,
    "declaration-block-no-duplicate-properties": true,
    "no-descending-specificity": null
  }
}
EOF

cat > .stylelintignore << 'EOF'
node_modules
_site
dist
EOF

# 6. Lighthouse CI config
echo "Creating lighthouserc.json..."
cat > lighthouserc.json << 'EOF'
{
  "ci": {
    "collect": {
      "staticDistDir": "_site"
    },
    "assert": {
      "assertions": {
        "categories:performance": ["warn", { "minScore": 0.9 }],
        "categories:accessibility": ["warn", { "minScore": 0.9 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }],
        "categories:seo": ["warn", { "minScore": 0.9 }]
      }
    }
  }
}
EOF

# 7. Update package.json scripts using Node (no jq dependency)
echo "Updating package.json scripts..."
node << 'NODE'
const fs = require('fs');

const pkgPath = 'package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

pkg.scripts = pkg.scripts || {};

// Only set defaults if they aren't already there
if (!pkg.scripts.dev) {
  pkg.scripts.dev = "npx eleventy --serve --quiet";
}
if (!pkg.scripts.build) {
  pkg.scripts.build = "ELEVENTY_ENV=production npx eleventy";
}

pkg.scripts.format = pkg.scripts.format || "prettier --write \"**/*.{js,jsx,ts,tsx,css,scss,md,json,njk,html}\"";
pkg.scripts["format:check"] = pkg.scripts["format:check"] || "prettier --check \"**/*.{js,jsx,ts,tsx,css,scss,md,json,njk,html}\"";
pkg.scripts["lint:js"] = pkg.scripts["lint:js"] || "eslint .";
pkg.scripts["lint:css"] = pkg.scripts["lint:css"] || "stylelint \"src/**/*.css\"";
pkg.scripts.lint = pkg.scripts.lint || "npm run lint:js && npm run lint:css";
pkg.scripts.precommit = pkg.scripts.precommit || "npm run format:check && npm run lint";
pkg.scripts.lhci = pkg.scripts.lhci || "lhci autorun";
pkg.scripts.prepare = pkg.scripts.prepare || "husky install";

fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
NODE

# 8. Set up Husky
echo "Setting up Husky pre-commit hook..."
npx husky install

mkdir -p .husky
npx husky add .husky/pre-commit "npm run precommit" > /dev/null 2>&1 || {
  # If the above fails because the hook exists, just ensure it runs precommit
  cat > .husky/pre-commit << 'EOF'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

npm run precommit
EOF
  chmod +x .husky/pre-commit
}

# 9. GitHub Actions workflow
echo "Creating GitHub Actions workflow (.github/workflows/ci-cd.yml)..."
mkdir -p .github/workflows

cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Use Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Check formatting (Prettier)
        run: npm run format:check

      - name: Run linters
        run: npm run lint

      - name: Build Eleventy site
        run: npm run build

      - name: Lighthouse CI
        run: npm run lhci || echo "Lighthouse warnings – check reports"

  deploy:
    needs: build-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Use Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Build Eleventy site
        run: npm run build

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./_site
EOF

echo "=== Done. Quality gates are configured. ==="
echo "You now have:"
echo "  - Prettier (.prettierrc, .prettierignore)"
echo "  - ESLint (.eslintrc.cjs, .eslintignore)"
echo "  - Stylelint (.stylelintrc.json, .stylelintignore)"
echo "  - Husky pre-commit hook (runs format:check + lint)"
echo "  - Lighthouse CI (lighthouserc.json)"
echo "  - GitHub Actions CI/CD (.github/workflows/ci-cd.yml)"
echo
echo "Try: npm run format:check, npm run lint, npm run build"
echo "Then commit and push to see CI run on GitHub."
