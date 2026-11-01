# ☁️ BlueClip Cloud Server Deployment Guide

This companion server allows you to sync your clipboard history from the **BlueClip macOS menu bar app** to your private cloud infrastructure or local network, and inspect it in any web browser.

---

## 🚀 Option 1: Deploying to AWS EC2 or Remote Linux Server

1. **SSH into the Server**:
   ```bash
   ssh -i your-key.pem user@your-server-ip
   ```

2. **Add BlueClip to your Application Fleet or Systemd Service**:
   ```bash
   # Create server directory
   sudo mkdir -p /var/www/blueclip
   sudo chown -R $USER:$USER /var/www/blueclip
   ```

3. **Deploy the Server Files**:
   Copy `clipboard_server.py` and `web_viewer.html` to the server:
   ```bash
   # From your Mac:
   scp -i your-key.pem server/* user@your-server-ip:/var/www/blueclip/
   ```

4. **Run or Configure Reverse Proxy**:
   ```bash
   cd /var/www/blueclip
   python3 clipboard_server.py 8008
   ```

5. **Visit the Web Viewer**:
   Open `https://your-domain.com` (or `http://your-server-ip:8008`) in any web browser!

---

## 💻 Option 2: Running Locally on your Mac or LAN

You can run the zero-dependency Python server directly on your Mac or local network:
```bash
python3 server/clipboard_server.py 8008
```
Then visit `http://127.0.0.1:8008` in Safari or Chrome.
