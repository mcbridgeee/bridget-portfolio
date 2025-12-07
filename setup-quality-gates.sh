#!/usr/bin/env bash
set -e

echo "=== Eleventy + Quality Gates Setup Script ==="

# 1. Ensure package.json exists
if [ ! -f package.json ]; then
  echo "No package.json found – running 'npm init -y'..."
  npm init -y
else
  echo "package.json found."
fi

# 2. Install dev dependencies (includes Eleventy)
echo "Installing dev dependencies (Eleventy, Prettier, ESLint v8, Stylelint, Husky, Lighthouse CI)..."
npm install --save-dev \
  @11ty/eleventy \
  prettier \
  eslint@8 \
  stylelint \
  stylelint-config-standard \
  husky \
  @lhci/cli

# 3. Basic Eleventy structure (if missing)
echo "Ensuring Eleventy structure exists..."

if [ ! -f eleventy.config.js ]; then
  echo "Creating eleventy.config.js..."
  cat > eleventy.config.js << 'EOF'
module.exports = function (_eleventyConfig) {
  return {
    dir: {
      input: "src",
      includes: "_includes",
      layouts: "_includes/layouts",
      output: "_site"
    },
    templateFormats: ["njk", "md", "html"]
  };
};
EOF
else
  echo "eleventy.config.js already exists – leaving it alone."
fi

if [ ! -d src ]; then
  echo "Creating src folder and basic files..."
  mkdir -p src/_includes/layouts

  cat > src/_includes/layouts/base.njk << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>{{ title or "portfolio" }}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" href="/style.css" />
  </head>
  <body>
    <header>
      <h1>{{ title or "portfolio" }}</h1>
      <nav>
        <a href="/">home</a>
      </nav>
    </header>

    <main>
      {{ content | safe }}
    </main>

    <footer>
      <p>&copy; {{ "now" | date("yyyy") }} bridget</p>
    </footer>
  </body>
</html>
EOF

  cat > src/index.njk << 'EOF'
---
layout: base.njk
title: "bridget – portfolio"
---

<section>
  <h2>coming soon</h2>
  <p>this is the starter shell for my eleventy site.</p>
</section>
EOF

  cat > src/style.css << 'EOF'
*,
*::before,
*::after {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.5;
}

header,
main,
footer {
  padding: 1.5rem;
}

header {
  border-bottom: 1px solid #ddd;
}

footer {
  border-top: 1px solid #ddd;
  font-size: 0.875rem;
  color: #555;
}
EOF
else
  echo "src folder already exists – not touching your files."
fi

# 4. Prettier config
echo "Creating Prettier config..."
cat > .prettierrc << 'EOF'
{
  "printWidth": 80,
  "singleQuote": true,
  "trailingComma": "es5",
  "semi": true,
  "tabWidth": 2,
  "overrides": [
    {
      "files": ["*.njk"],
      "options": {
        "parser": "html"
      }
    }
  ]
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

# 5. ESLint config
echo "Creating ESLint config..."
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

# 6. Stylelint config
echo "Creating Stylelint config..."
cat > .stylelintrc.json << 'EOF'
{
  "extends": ["stylelint-config-standard"],
  "rules": {
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

# 7. Lighthouse CI config
echo "Creating Lighthouse CI config..."
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

# 8. Update package.json scripts
echo "Updating package.json scripts..."
node << 'NODE'
const fs = require('fs');

const pkgPath = 'package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

pkg.scripts = pkg.scripts || {};

if (!pkg.scripts.dev) {
  pkg.scripts.dev = "npx eleventy --serve --quiet";
}
if (!pkg.scripts.build) {
  pkg.scripts.build = "ELEVENTY_ENV=production npx eleventy";
}

pkg.scripts.format = "prettier --write \"**/*.{js,jsx,ts,tsx,css,scss,md,json,njk,html}\"";
pkg.scripts["format:check"] = "prettier --check \"**/*.{js,jsx,ts,tsx,css,scss,md,json,njk,html}\"";
pkg.scripts["lint:js"] = "eslint .";
pkg.scripts["lint:css"] = "stylelint \"src/**/*.css\"";
pkg.scripts.lint = "npm run lint:js && npm run lint:css";
pkg.scripts.precommit = "npm run format:check && npm run lint";
pkg.scripts.lhci = "lhci autorun";
pkg.scripts.prepare = "husky install";

fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
NODE

# 9. Husky setup
echo "Setting up Husky..."
npx husky install

mkdir -p .husky
cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env sh
npm run precommit
EOF
chmod +x .husky/pre-commit

# 10. GitHub Actions workflow
echo "Creating GitHub Actions workflow..."
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

echo "=== Done. Eleventy + quality gates configured. ==="
echo
echo "You now have:"
echo "  - Eleventy base project (eleventy.config.js + src/ structure)"
echo "  - Prettier (.prettierrc, .prettierignore)"
echo "  - ESLint v8 (.eslintrc.cjs, .eslintignore)"
echo "  - Stylelint (.stylelintrc.json, .stylelintignore)"
echo "  - Husky pre-commit hook (runs format:check + lint)"
echo "  - Lighthouse CI config (lighthouserc.json)"
echo "  - GitHub Actions CI/CD workflow (.github/workflows/ci-cd.yml)"
echo "  - This setup script (setup-quality-gates.sh) for reuse"
echo
echo "Try:"
echo "  npm run format:check"
echo "  npm run lint"
echo "  npm run build"
echo "  npm run dev"
echo
echo "Then commit and push to trigger CI on GitHub."
