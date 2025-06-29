# CICD Script Tool

This repository contains a simple and versatile CICD script for automating integration and platform delivery.

## Overview

The core of this tool is the `cicd.sh` script. It's designed to be a stable tool that developers can use to build and test their code without altering the script itself. Developers contribute by adding testing and build scripts to the `tools/` directory.

## Folder Structure

Here is an example of the recommended folder structure for a repository using this CICD tool:

```
. (localRepo)
├── cicd
│   ├── cicd.sh
│   ├── automation_server.py
│   ├── logs
│   │   └── ...
│   ├── README.md
│   └── tools
│       ├── build.sh
│       ├── test.sh
│       ├── webhookaction.sh
│       └── util
│           ├── test_roa.py
│           └── build_backend.py
├── app
│   ├── src
│   │   ├── main.py
│   │   └── ...
│   └── ...
└── ...
```

## Getting Started

1.  **Add your testing scripts** to the `tools/util/` directory.
2.  **Call your testing scripts** from `tools/test.sh`.
3.  **Write your build code** in `tools/build.sh`. This should be done once per machine type.

### .gitignore

You might want to add the following to your `.gitignore` file:

```
logs/*
tools/webhookhandler.sh
```

## Branching Model

*   For any task, create a feature or bugfix branch (e.g., `feature/*`, `bugfix/*`).
*   Use `git commit --amend --no-edit` to patch the last commit and keep the history clean.
*   Use `git push --force-with-lease` if you need to force push to a remote branch.
*   Merges to `origin/main` happen through the `--deploy` option or via pull requests.
*   Pushing is allowed on all branches.

## Configuration

### Platform Support

The script can be configured to work on different platforms:

*   **Linux/macOS:** Runs natively.
*   **Windows:** Requires `bash`, so WSL is recommended.

### Webhooks

The `webhookhandler.sh` script can be configured for automatic actions, which is useful for code that has specific machine requirements (e.g., macOS for frontend builds, or a server with special access for backend builds).

**Example Action:**

```bash
git switch "$pulledbranch" && ./cicd.sh --deploy main
```

The `automation_server.py` script creates a Tailscale tunnel to receive GitHub webhooks and then runs `webhookhandler.sh`.

## Usage

This CICD script is designed for both developers and server/deployment setups.

### For Developers

*   **Build and test your current branch:**
    ```bash
    ./cicd.sh
    ```
*   **Test your branch and its merge with `main`:**
    ```bash
    ./cicd.sh --test-merge main
    ```
*   **Deploy your branch to `main`:**
    ```bash
    ./cicd.sh --deploy main
    ```

### Server/Deployment Setup

*   Configure GitHub webhooks to point to `automation_server.py` for automated actions.