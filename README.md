# Deploy Astro to GitHub Pages

This action for [Astro](https://github.com/withastro/astro) builds your static Astro project for [GitHub Pages](https://pages.github.com/).

For more information, please see our complete deployment guide—[Deploy your Astro Site to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/).

## Usage

> **Note**: Want to get started even faster? Create a repository from our official [GitHub Pages template](https://github.com/withastro/github-pages)!

### Inputs

- `path` - Optional: the root location of your Astro project inside the repository.
- `node-version` - Optional: the specific version of Node that should be used to build your site. Defaults to `22`.
- `package-manager` - Optional: the Node package manager that should be used to install dependencies and build your site. Automatically detected based on your lockfile. Accepted values: `npm`, `yarn`, `pnpm`, `bun`, and `deno`. A version tag is also accepted, for example `npm@11.6.2`, `pnpm@10`, `bun@latest`, or `deno@v2.x`. If not provided, version will default to `latest`.
- `build-cmd` - Optional: the command to run to build your site. Defaults to `deno task build` for sites using Deno and to `<package-manager> run build` for all other package managers.

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
        uses: actions/checkout@v5
      - name: Install, build, and upload your site output
        uses: withastro/action@v5
        # with:
            # path: . # The root location of your Astro project inside the repository. (optional)
            # node-version: 22 # The specific version of Node that should be used to build your site. Defaults to 22. (optional)
            # package-manager: pnpm@latest # The Node package manager that should be used to install dependencies and build your site. Automatically detected based on your lockfile. (optional)
            # build-cmd: pnpm run build # The command to run to build your site. Runs the package build script/task by default. (optional)

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```
