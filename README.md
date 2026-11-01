# Deploy Astro to GitHub Pages

This action for [Astro](https://github.com/withastro/astro) builds your static Astro project for [GitHub Pages](https://pages.github.com/).

For more information, please see our complete deployment guide—[Deploy your Astro Site to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/).

## Usage

> **Note**: Want to get started even faster? Create a repository from our official [GitHub Pages template](https://github.com/withastro/github-pages)!

### Inputs

- `path` - Optional: the root location of your Astro project inside the repository.
- `node-version` - Optional: the specific version of Node that should be used to build your site. Defaults to `24`.
- `package-manager` - Optional: the Node package manager that should be used to install dependencies and build your site. Automatically detected based on your lockfile. Accepted values: `npm`, `yarn`, `pnpm`, `bun`, and `deno`. A version tag is also accepted, for example `npm@11.6.2`, `pnpm@10`, `bun@latest`, or `deno@v2.x`. If not provided, version will default to `latest`, except for pnpm as described below.
- `build-cmd` - Optional: the command to run to build your site. Defaults to `deno task build` for sites using Deno and to `<package-manager> run build` for all other package managers.
- `cache` - Optional: enable Astro build cache to speed up subsequent builds. Caches optimized images and other build assets. Defaults to `true`.
- `cache-dir` - Optional: path to the Astro cache directory (relative to `path`). Defaults to `node_modules/.astro`. Only used when `cache` is `true`.
- `out-dir` - Optional: path to the Astro output directory, as created by build (relative to `path`). Defaults to `dist`. This directory is artifacted by this action.

### pnpm version selection

When pnpm is selected, its version is chosen in this order:

1. An explicit version in the `package-manager` input, such as `pnpm@10` or `pnpm@latest`.
2. `devEngines.packageManager` in the site's `package.json`, when its `name` is `pnpm` and it declares a version. This uses [pnpm/setup](https://github.com/pnpm/setup) to select a compatible version from the package-manager document in `pnpm-lock.yaml` when the declaration is a range. If no compatible locked version exists, the declared range is resolved from the registry. Exact versions and dist-tags retain their normal behavior.
3. The `packageManager` field in `package.json`, such as `pnpm@10.30.0`.
4. `latest`, with a warning when no version declaration is found.

Both automatic pnpm detection and `package-manager: pnpm` use this precedence. An explicit version bypasses lockfile version selection and disables pnpm's project version switching during dependency-cache setup, installation, and building, so `devEngines.packageManager` cannot switch it back. Conflicts with a legacy `packageManager` pin are still rejected by the installer. Without an explicit version, existing `pmOnFail` configuration is preserved. The override is scoped to these action steps.

The `devEngines.packageManager` path requires pnpm 11 or newer. It delegates workspace manifest and lockfile selection to pnpm/setup, including shared and per-project workspace lockfiles. pnpm/setup also installs the requested `node-version`, caches the pnpm store, and installs dependencies with `--no-runtime` to avoid installing Node again from `devEngines.runtime`. The separate Node and Install steps are skipped on this path. Explicit versions and legacy `packageManager` pins keep using pnpm/action-setup and actions/setup-node, including support for pnpm 10 and older.

Detection checks the site directory given by `path`. A workspace member without its own lockfile must specify `package-manager: pnpm`. Delegation to pnpm/setup requires a `devEngines.packageManager` declaration in the site's own `package.json`; discovering a declaration only present in a parent workspace is outside this support.

### Example workflow:

#### Build and Deploy to GitHub Pages

Create a file at `.github/workflows/deploy.yml` with the following content.

```yml
name: Deploy to GitHub Pages

on:
  # Trigger the workflow every time you push to the `main` branch
  # Using a different branch name? Replace `main` with your branch’s name
  push:
    branches: [main]
  # Allows you to run this workflow manually from the Actions tab on GitHub.
  workflow_dispatch:

# Allow this job to clone the repo and create a page deployment
permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout your repository using git
        uses: actions/checkout@v7
      - name: Install, build, and upload your site output
        uses: withastro/action@v6
        # with:
            # path: . # The root location of your Astro project inside the repository. (optional)
            # node-version: 24 # The specific version of Node that should be used to build your site. Defaults to 24. (optional)
            # package-manager: pnpm@latest # The Node package manager that should be used to install dependencies and build your site. Automatically detected based on your lockfile. (optional)
            # build-cmd: pnpm run build # The command to run to build your site. Runs the package build script/task by default. (optional)
            # out-dir: dist # The output directory created by the build command. Defaults to dist. (optional)

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v5
```
