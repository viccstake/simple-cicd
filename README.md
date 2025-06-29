## Repository CICD script tool
     # Used by all endpoints running any repository code
     # Called with different parameters to modify the behaviour
     # The tool is meant to be mantained as development progress 
     # The script, cicd.sh, should never be altered. Only called with parameters
     # Developers need to:
     #    Add relevant testing scripts in tools/util/
     #    Call the scripts from test.sh
     # Build code just needs to be written once per type of machine

# Example folder structure
. (localRepo)
├── cicd
│   ├── cicd.sh
│   ├── automation_server.py
│   ├── logs
│   │   └── ...
│   ├── README.md
│   └── tools
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

# .gitignore
     'logs/*'
     'tools/webhookhandler.sh'

# Branch model
For any task, create a branch e.g. feature/*, bugfix/* and work on it. 
     'git commit --amend --no-edit': to just patch the last commit. keeps it clean
     'git push --force-with-lease': might be needed on remote
Progress on the 'origin/main' branch happens through '--deploy' or by pull-requests.
     Pushing is allowed on all branches. 
The script has a '--deploy' option. This will try to merge on remote.
If problems occur 'git merge' is done manually.

# Script config
Depending on how you set up 'build.sh' the script will work on different plattforms.
     Linux/MacOS - natively
     Windows - bash is a dependancy so 'wsl' is reccomended
Depending on how you set up 'webhookhandler.sh' the script can be configured for automatic actions
     Only needed for code that most machines cant run
          Frontend: MacOS
          Backend: Needs server access
     Simple action ex: ('git switch "$pulledbranch" ; cicd --deploy main')
Github webhooks / automation_server.py:
     The server creates a tailscale tunnel
     Github wekhooks sends to the tailscale address
     Runs webhookhandler.sh with webhook as parameter

# How to use
This CICD script is meant to be simple and versatile for automating integration and platform delivery
 *  For developers:
     Use without branch paramter to just build/test your current branch
     Use without deploy to fully test your branch and its merge
     Use with deploy to automatically cause merge on remote to happen after
     Use the cicd/resources/* files to manually test individual parts
 *  Server/deployment setup:
     Configure GitHub webhooks to 'automation_server.py' for automated actions. 