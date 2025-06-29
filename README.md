# CICD Script Tool

This repository contains a simple and versatile CICD script for automating integration and platform delivery.

## Overview

The core of this tool is the `cicd.sh` script. It's designed to be a stable tool that developers and servers can use to build and test their code without altering the script itself. Developers contribute by adding testing and build code to the `tools/` scripts and `utils/`.

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
│       ├── webhookhandler.sh
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
*   Merges to `origin` happen through the `--deploy` option.
*   Pushing is allowed on all branches but some branches could redirect a webhook for a server to deploy.

## Configuration

### Platform Support

The script can be configured to work on different platforms:

*   **Linux/macOS:** Runs natively.
*   **Windows:** Requires `bash`, so WSL is recommended.

### Webhooks

The `webhookhandler.sh` script takes one argument, $pulledBranch.
The `automation_server.py` script creates a Tailscale tunnel to receive GitHub webhooks and then runs `webhookhandler.sh` with specified branch.
Github webhooks handle all branch- and user-specific logic around this.

**Example Action:**

```bash
git switch "$pulledbranch" && ./cicd.sh --deploy main
```

## Usage

This CICD script is designed for both developers and server/deployment setups.

### For Developers

*   **Build and test your current branch:**
    ```bash
    ./cicd.sh
    ```
*   **Deploy your current branch:**
    ```bash
    ./cicd.sh --deploy
    ```
*   **Test your branch and its merge with `main`:**
    ```bash
    ./cicd.sh main
    ```
*   **Deploy your branch to `main`:**
    ```bash
    ./cicd.sh --deploy main
    ```

### Server/Deployment Setup

*   Configure GitHub webhooks on specified branches to point to `automation_server.py` for automated actions.
*   Add your desired action logic for said branch/* inside webhookhandler.