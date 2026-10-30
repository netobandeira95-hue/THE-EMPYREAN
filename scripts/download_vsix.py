import urllib.request, json, os, subprocess

url = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
headers = {
    "Accept": "application/json;api-version=3.0-preview.1",
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}
data = json.dumps({
    "filters": [{"criteria": [{"filterType": 7, "value": "ms-vscode.vscode-speech"}]}],
    "flags": 131
}).encode("utf-8")

req = urllib.request.Request(url, data=data, headers=headers)
with urllib.request.urlopen(req) as response:
    resp_data = json.loads(response.read().decode())
    
try:
    extension = resp_data["results"][0]["extensions"][0]
    versions = extension["versions"]
    latest_version = versions[0]
    version_str = latest_version["version"]
    vsix_url = f"https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/vscode-speech/{version_str}/vspackage"
    
    print(f"Downloading version {version_str} from {vsix_url}...")
    
    req = urllib.request.Request(vsix_url, headers={"User-Agent": headers["User-Agent"]})
    with urllib.request.urlopen(req) as response:
        with open("vscode-speech.vsix", "wb") as f:
            f.write(response.read())
            
    print("Download complete! Attempting to install...")
    
    # Try to install using "code" command
    result = subprocess.run(["code", "--install-extension", "vscode-speech.vsix"], capture_output=True, text=True)
    if result.returncode == 0:
        print("Installation successful!")
        print(result.stdout)
    else:
        print("Failed to install via 'code' command. You may need to install it manually.")
        print("Error:", result.stderr)
        
except Exception as e:
    print(f"Error: {e}")
