import http.server
import socketserver
import json
import subprocess
import os

# --- Configuration ---
PORT = 8000
WEBHOOK_PATH = "/webhook"
# This should be the path to the webhookaction.sh script relative to this file.
ACTION_SCRIPT = "./tools/webhookaction.sh"

class WebhookHandler(http.server.SimpleHTTPRequestHandler):
    """
    A simple HTTP request handler for GitHub webhooks.
    """
    def do_POST(self):
        if self.path == WEBHOOK_PATH:
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                payload = json.loads(post_data.decode('utf-8'))

                # --- Extract branch name from payload ---
                # For push events, the branch is in the 'ref' field.
                # e.g., "ref": "refs/heads/feature/new-stuff"
                ref = payload.get('ref', '')
                branch = ref.split('/')[-1]

                if branch:
                    print(f"Webhook received for branch: {branch}")
                    
                    # --- Run the action script ---
                    # Ensure the script is executable
                    if not os.access(ACTION_SCRIPT, os.X_OK):
                        print(f"Error: {ACTION_SCRIPT} is not executable. Please run 'chmod +x {ACTION_SCRIPT}'.")
                        self.send_response(500)
                        self.end_headers()
                        self.wfile.write(b"Internal Server Error: Action script not executable.")
                        return

                    try:
                        # We pass the branch name as an argument to the script
                        result = subprocess.run(
                            [ACTION_SCRIPT, branch],
                            capture_output=True,
                            text=True,
                            check=True
                        )
                        print("Action script stdout:")
                        print(result.stdout)
                        print("Action script stderr:")
                        print(result.stderr)
                        
                        self.send_response(200)
                        self.end_headers()
                        self.wfile.write(b"Webhook processed successfully.")

                    except subprocess.CalledProcessError as e:
                        print(f"Error executing {ACTION_SCRIPT}:")
                        print(e.stdout)
                        print(e.stderr)
                        self.send_response(500)
                        self.end_headers()
                        self.wfile.write(b"Error processing webhook.")

                else:
                    print("Webhook received, but no branch ref found. Nothing to do.")
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"Webhook received, but no action taken.")

            except Exception as e:
                print(f"Error processing webhook: {e}")
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Error processing webhook.")
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found.")

def run_server():
    """
    Starts the webhook listener server.
    """
    with socketserver.TCPServer(('', PORT), WebhookHandler) as httpd:
        print("--- Automation Server Started ---")
        print(f"Listening on port {PORT} for webhooks at {WEBHOOK_PATH}")
        print("\n--- Tailscale Integration ---")
        print("To expose this server to the internet using Tailscale, first ensure Tailscale is running, then run:")
        print(f"  tailscale up")
        print("And to expose the server, run:")
        print(f"  tailscale serve localhost:{PORT}")
        print("\nThen, configure your GitHub webhook to point to your Tailscale DNS name.")
        print("-----------------------------")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()