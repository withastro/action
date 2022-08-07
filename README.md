# Astro Deploy Action

This action for [Astro](https://github.com/withastro/astro) builds your Astro project for [GitHub Pages](https://pages.github.com/).

## Usage

### Inputs

- `path` - Optional: the root location of your Astro project inside the repository. Defaults to `/`.
- `node-version` - Optional: the specific version of Node that should be used to build your site. Defaults to `16`.
- `package-manager` - Optional: the Node package manager that should be used to install dependencies and build your site. Automatically detected based on your lockfile.

### Example workflow:

#### Build and Deploy to GitHub Pages

Create a file at `.github/workflows/deploy.yml` with the following content.

```yml
name: Deploy

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
  workflow_dispatch:

concurrency: ${{ github.workflow }}-${{ github.ref }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: withastro/action@v0

  deploy:
    needs: build
    runs-on: ubuntu-latest
    # Grant GITHUB_TOKEN the permissions required to make a Pages deployment
    permissions:
      pages: write      # to deploy to Pages
      id-token: write   # to verify the deployment originates from an appropriate source
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v1
```
