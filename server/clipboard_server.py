#!/usr/bin/env python3
"""
BlueClip Cloud Receiver & Web Viewer Server (Zero Dependency - Python Standard Library)
Listens for clipboard sync & merge payloads from the BlueClip macOS app,
partitioned by Account / Email with shareword token protection.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import json
import urllib.parse
from datetime import datetime
import uuid
import re

def extract_simple_keywords(text, max_keywords=5):
    if not text:
        return ["General"]
    clean = re.sub(r"[^a-zA-Z0-9\s]", " ", text)
    stopwords = {
        "this", "that", "with", "from", "your", "have", "will", "what", "there", "about",
        "which", "when", "make", "like", "time", "just", "know", "take", "people", "into",
        "year", "good", "some", "could", "them", "other", "than", "then", "now", "look",
        "only", "come", "its", "over", "think", "also", "back", "after", "use", "two", "http", "https"
    }
    words = [w.capitalize() for w in clean.split() if len(w) >= 4 and w.lower() not in stopwords]
    if not words:
        return ["General"]
    from collections import Counter
    counts = Counter(words)
    top = [w for w, _ in counts.most_common(max_keywords)]
    return top if top else ["General"]

DIR = os.path.dirname(os.path.abspath(__file__))
VIEWER_FILE = os.path.join(DIR, "web_viewer.html")

def get_data_dir():
    mac_app_support = os.path.expanduser("~/Library/Application Support/BlueClip")
    if os.path.exists(mac_app_support):
        return mac_app_support
    linux_data = os.path.expanduser("~/.blueclip")
    os.makedirs(linux_data, exist_ok=True)
    return linux_data

DATA_DIR = get_data_dir()

def normalize_shareword(s):
    if not s:
        return ""
    import re
    clean = re.sub(r"[^a-z0-9]", " ", s.lower())
    tokens = clean.split()
    if not tokens:
        return ""

    def stem(w):
        if w.endswith("ies") and len(w) > 4:
            return w[:-3] + "y"
        if w.endswith("ves") and len(w) > 4:
            return w[:-3] + "f"
        if w.endswith("es") and len(w) > 3 and (
            w.endswith("xes") or w.endswith("ses") or w.endswith("ches") or w.endswith("shes")
        ):
            return w[:-2]
        if w.endswith("s") and not w.endswith("ss") and len(w) > 2:
            return w[:-1]
        return w

    tokens = [stem(t) for t in tokens]
    return "".join(tokens)

def get_shareword_hash(s):
    norm = normalize_shareword(s)
    if not norm:
        return ""
    import hashlib
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()

def get_account_path(account_id):
    clean = "".join(c for c in (account_id or "default") if c.isalnum() or c in "._-@").lower()
    return os.path.join(DATA_DIR, f"clipboard_history_{clean}.json")

def merge_clip_lists(existing_clips, incoming_clips, max_clips=500):
    """
    Unifies clippings across multiple computers signed into the same Email / Shareword.
    Deduplicates by text content, keeps most recent timestamp and pinned state.
    """
    clip_map = {}
    
    # Process existing first
    for clip in existing_clips:
        text = clip.get("text", "")
        if text:
            clip_map[text] = clip
            
    # Process incoming, updating with newer info if present
    for clip in incoming_clips:
        text = clip.get("text", "")
        if not text:
            continue
        if text in clip_map:
            # Preserve pinned state
            if clip.get("isPinned") or clip_map[text].get("isPinned"):
                clip["isPinned"] = True
            # Keep newest timestamp
            t_incoming = clip.get("timestamp", "")
            t_existing = clip_map[text].get("timestamp", "")
            if t_incoming < t_existing:
                clip["timestamp"] = t_existing
            clip_map[text] = clip
        else:
            clip_map[text] = clip
            
    unified = list(clip_map.values())
    
    # Sort chronologically (newest first, pinned at top)
    def sort_key(c):
        pinned = 1 if c.get("isPinned") else 0
        timestamp = c.get("timestamp", "")
        return (pinned, timestamp)
        
    unified.sort(key=sort_key, reverse=True)
    return unified[:max_clips]

class BlueClipHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-Email, X-Shareword, X-Account-ID")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/" or path == "/index.html" or path == "/web_viewer.html":
            if os.path.exists(VIEWER_FILE):
                with open(VIEWER_FILE, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(content)
                return
            else:
                body = b"<h1>BlueClip Server Active</h1><p>Send POST to /api/clipboard-sync</p>"
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return

        if path == "/api/clipboard-sync" or path.startswith("/clipboard_history"):
            account = query.get("account", [None])[0] or query.get("email", [None])[0]
            incoming_hash = query.get("hash", [None])[0] or query.get("token_hash", [None])[0]
            incoming_token = query.get("token", [None])[0] or query.get("shareword", [None])[0]
            target_file = None

            if account and account != "default":
                candidate = get_account_path(account)
                if os.path.exists(candidate):
                    target_file = candidate

            if not target_file:
                # Find the most recently updated account history file
                candidates = [
                    os.path.join(DATA_DIR, f) for f in os.listdir(DATA_DIR)
                    if f.startswith("clipboard_history_") and f.endswith(".json") and "test@" not in f
                ]
                if candidates:
                    candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
                    target_file = candidates[0]
                else:
                    target_file = os.path.join(DATA_DIR, "clipboard_history.json")
                    if not os.path.exists(target_file):
                        sample_file = os.path.join(DIR, "clipboard_history.sample.json")
                        if os.path.exists(sample_file):
                            target_file = sample_file

            data = {"clips": [], "email": account or "default", "shareword": ""}
            if target_file and os.path.exists(target_file):
                try:
                    with open(target_file, "r", encoding="utf-8") as f:
                        loaded = json.load(f)
                    if isinstance(loaded, list):
                        data = {
                            "email": account or "user@example.com",
                            "shareword": "",
                            "device": "Mac",
                            "timestamp": datetime.utcnow().isoformat() + "Z",
                            "totalClips": len(loaded),
                            "clips": loaded
                        }
                    elif isinstance(loaded, dict):
                        data = loaded
                except Exception:
                    pass

            saved_shareword = data.get("shareword") or ""
            expected_hash = get_shareword_hash(saved_shareword)
            data["shareword_hash"] = expected_hash

            if saved_shareword:
                if incoming_hash:
                    if incoming_hash.lower() != expected_hash.lower():
                        resp = {"status": "unauthorized", "message": "Invalid token hash for this account."}
                        resp_bytes = json.dumps(resp).encode("utf-8")
                        self.send_response(401)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(resp_bytes)))
                        self._send_cors_headers()
                        self.end_headers()
                        self.wfile.write(resp_bytes)
                        return
                elif incoming_token:
                    if normalize_shareword(incoming_token) != normalize_shareword(saved_shareword):
                        resp = {"status": "unauthorized", "message": "Incorrect shareword for this account."}
                        resp_bytes = json.dumps(resp).encode("utf-8")
                        self.send_response(401)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(resp_bytes)))
                        self._send_cors_headers()
                        self.end_headers()
                        self.wfile.write(resp_bytes)
                        return

            if incoming_hash and "shareword" in data:
                data["shareword_masked"] = "●●●●●●●● (Verified Hash)"

            resp_bytes = json.dumps(data, indent=2).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp_bytes)))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(resp_bytes)
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/api/clipboard-sync":
            self.send_response(404)
            self.end_headers()
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length > 0 else b"{}"
            data = json.loads(body.decode("utf-8"))
            
            email = (
                data.get("email") or 
                data.get("account") or 
                self.headers.get("X-User-Email") or 
                self.headers.get("X-Account-ID") or 
                "default"
            )
            shareword = (
                data.get("shareword") or 
                data.get("token") or 
                self.headers.get("X-Shareword") or 
                self.headers.get("Authorization", "").replace("Bearer ", "").strip()
            )
            incoming_hash = (
                data.get("hash") or
                data.get("token_hash") or
                self.headers.get("X-Shareword-Hash")
            )
            action = data.get("action", "merge")
            incoming_clips = data.get("clips", [])
            device = data.get("device", "Mac")
            
            account_file = get_account_path(email)
            existing_data = {"clips": [], "shareword": ""}
            if os.path.exists(account_file):
                try:
                    with open(account_file, "r", encoding="utf-8") as f:
                        existing_data = json.load(f)
                except Exception:
                    pass
            
            saved_shareword = existing_data.get("shareword") or existing_data.get("token")
            if saved_shareword:
                if incoming_hash:
                    if incoming_hash.lower() != get_shareword_hash(saved_shareword).lower():
                        resp = {"status": "unauthorized", "message": "Incorrect shareword hash for this email account."}
                        resp_bytes = json.dumps(resp).encode("utf-8")
                        self.send_response(401)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(resp_bytes)))
                        self._send_cors_headers()
                        self.end_headers()
                        self.wfile.write(resp_bytes)
                        return
                elif shareword:
                    if normalize_shareword(saved_shareword) != normalize_shareword(shareword):
                        resp = {"status": "unauthorized", "message": "Incorrect shareword for this email account."}
                        resp_bytes = json.dumps(resp).encode("utf-8")
                        self.send_response(401)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(resp_bytes)))
                        self._send_cors_headers()
                        self.end_headers()
                        self.wfile.write(resp_bytes)
                        return

            existing_clips = existing_data.get("clips", [])

            if action == "toggle_pin":
                target_id = data.get("clip_id") or data.get("id")
                target_text = data.get("text")
                for c in existing_clips:
                    if (target_id and c.get("id") == target_id) or (target_text and c.get("text") == target_text):
                        c["isPinned"] = not c.get("isPinned", False)
                        break
                def sort_key(c):
                    return (1 if c.get("isPinned") else 0, c.get("timestamp", ""))
                existing_clips.sort(key=sort_key, reverse=True)
                merged_clips = existing_clips

            elif action == "delete":
                target_id = data.get("clip_id") or data.get("id")
                target_text = data.get("text")
                merged_clips = [
                    c for c in existing_clips
                    if not ((target_id and c.get("id") == target_id) or (target_text and c.get("text") == target_text))
                ]

            elif action in ("delete_all", "clear"):
                merged_clips = []

            elif action == "add":
                new_text = (data.get("text") or "").strip()
                if new_text:
                    new_clip = {
                        "id": data.get("id") or str(uuid.uuid4()).upper(),
                        "text": new_text,
                        "timestamp": datetime.utcnow().isoformat() + "Z",
                        "appName": data.get("appName", "Web"),
                        "appBundleId": "com.blueclip.web",
                        "isPinned": False,
                        "keywords": data.get("keywords") or extract_simple_keywords(new_text)
                    }
                    merged_clips = merge_clip_lists(existing_clips, [new_clip])
                else:
                    merged_clips = existing_clips

            elif action == "merge":
                merged_clips = merge_clip_lists(existing_clips, incoming_clips)
            else:
                merged_clips = incoming_clips

            save_payload = {
                "email": email,
                "shareword": shareword or saved_shareword or "",
                "device": device,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "totalClips": len(merged_clips),
                "clips": merged_clips
            }

            with open(account_file, "w", encoding="utf-8") as f:
                json.dump(save_payload, f, indent=2)

            with open(os.path.join(DATA_DIR, "clipboard_history.json"), "w", encoding="utf-8") as f:
                json.dump(save_payload, f, indent=2)

            with open(os.path.join(DATA_DIR, "clipboard_history_cache.json"), "w", encoding="utf-8") as f:
                json.dump(save_payload, f, indent=2)

            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Merged {len(merged_clips)} clips for account '{email}' from device '{device}'")

            resp = {
                "status": "success",
                "action": action,
                "account": email,
                "email": email,
                "message": f"Successfully unified {len(merged_clips)} clips across devices",
                "timestamp": save_payload["timestamp"],
                "totalClips": len(merged_clips),
                "clips": merged_clips
            }
            resp_bytes = json.dumps(resp).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp_bytes)))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(resp_bytes)
        except Exception as e:
            err = {"status": "error", "message": str(e)}
            err_bytes = json.dumps(err).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(err_bytes)))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(err_bytes)

def run(port=8008):
    server_address = ("0.0.0.0", port)
    httpd = HTTPServer(server_address, BlueClipHandler)
    print(f"BlueClip Zero-Dependency Server running on http://127.0.0.1:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()

if __name__ == "__main__":
    import sys
    port = 8008
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run(port)
