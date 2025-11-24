# 🎨 Running Python Backend in Visual Studio

Complete guide for running the Face Recognition backend in Visual Studio IDE or VS Code.

---

## 🤔 Which Visual Studio Do You Have?

### Visual Studio Code (VS Code) ✅ Recommended
- **Icon:** Blue/White square
- **Size:** ~100 MB
- **Free:** Yes
- **Best for:** Python, JavaScript, Web Development
- **Download:** https://code.visualstudio.com/

### Visual Studio (Full IDE)
- **Icon:** Purple square
- **Size:** ~5-10 GB
- **Free:** Community Edition
- **Best for:** C#, .NET, Windows Development
- **Download:** https://visualstudio.microsoft.com/

**For Python, VS Code is much better!** Use this guide for both.

---

# 🚀 Visual Studio Code Setup (Recommended)

## Step 1: Install VS Code

If you don't have it:
```
Download: https://code.visualstudio.com/
Install and open
```

## Step 2: Install Python Extension

1. Open VS Code
2. Click **Extensions** icon (left sidebar)
   - Or press: `Ctrl+Shift+X` (Windows) / `Cmd+Shift+X` (Mac)
3. Search: **"Python"**
4. Install: **"Python" by Microsoft** (the official one)
5. Wait for installation to complete

**Also recommended:**
- **Pylance** (Python language server)
- **Python Debugger** (debugging support)

## Step 3: Open Backend Project

### Option A: Open Folder
```
File → Open Folder
Navigate to: /backend
Click: Select Folder
```

### Option B: From Terminal
```bash
cd /path/to/backend
code .
```

You should see all Python files in the Explorer sidebar.

## Step 4: Select Python Interpreter

1. Press: `Ctrl+Shift+P` (Windows) / `Cmd+Shift+P` (Mac)
2. Type: **"Python: Select Interpreter"**
3. Select: **Python 3.8+** from the list
   - Look for: `/usr/bin/python3` or similar
   - Should show version: `Python 3.x.x`

**If no Python found:**
```bash
# Install Python first
brew install python3  # macOS
# OR download from python.org
```

## Step 5: Open Terminal in VS Code

**Option 1:** Menu
```
Terminal → New Terminal
```

**Option 2:** Keyboard
```
Ctrl+` (backtick)
```

**Option 3:** Button
- Click terminal icon at top-right
- Or bottom panel "TERMINAL" tab

You should see a terminal at the bottom of VS Code.

## Step 6: Install Dependencies

**In the VS Code terminal:**

```bash
# Check you're in backend folder
pwd
# Should show: /path/to/backend

# Install dependencies
pip3 install -r requirements.txt

# Wait 5-10 minutes for installation
```

**If you see permission errors:**
```bash
# Use virtual environment
python3 -m venv venv
source venv/bin/activate  # Mac/Linux
# OR
venv\Scripts\activate     # Windows

# Then install
pip install -r requirements.txt
```

## Step 7: Configure Environment

1. **Copy example config:**
   - Right-click `.env.example` in Explorer
   - Click "Copy"
   - Right-click in Explorer
   - Click "Paste"
   - Rename to `.env`

2. **Edit `.env` file:**
   - Click `.env` to open
   - Update database URL:
   ```env
   DATABASE_URL=postgresql://user:password@localhost:5432/face_recognition_db
   ```
   - Save: `Ctrl+S`

## Step 8: Run Backend

### Method 1: Direct Run (Easiest)

**In terminal:**
```bash
python3 main.py
```

**Expected output:**
```
✅ Database tables created successfully
🚀 Face Recognition Backend Started
📍 API running at: http://0.0.0.0:3000
INFO:     Uvicorn running on http://0.0.0.0:3000
```

**API is running!** Open browser: http://localhost:3000

### Method 2: Debug Mode (Best for Development)

1. **Open `main.py`**
2. **Set breakpoint:** Click left of line number (red dot appears)
3. **Press F5** or click "Run and Debug" icon (left sidebar)
4. **Select:** "Python: FastAPI Backend"
5. **Backend starts in debug mode**

**Debug features:**
- Pause at breakpoints
- Inspect variables
- Step through code
- View console output

### Method 3: Run Button

1. **Open `main.py`**
2. **Click ▶️ button** (top-right corner)
3. **Select:** "Run Python File"
4. **Backend starts in terminal**

## Step 9: Test Backend

**In a new terminal** (keep backend running):

```bash
# Click "+" icon in terminal panel to open new terminal
python3 test_api.py
```

**Expected:**
```
✅ API is healthy!
✅ Registration successful!
✅ Test Suite Complete!
```

---

# 🎨 Visual Studio (Full IDE) Setup

## Step 1: Install Python Support

1. Open **Visual Studio Installer**
2. Click **Modify** on your VS installation
3. Check **"Python development"** workload
4. Click **Modify** to install
5. Wait for installation (5-10 GB)

## Step 2: Open Project

```
File → Open → Folder
Select: /backend folder
Click: Select Folder
```

## Step 3: Set Python Environment

1. **View → Other Windows → Python Environments**
2. Click **"+ Add Environment"**
3. Select **"Existing Environment"**
4. Choose Python 3.8+ installation
5. Click **OK**

## Step 4: Install Dependencies

1. **View → Other Windows → Package Manager Console**
2. **In console:**
   ```bash
   pip install -r requirements.txt
   ```

## Step 5: Configure Startup

1. **Right-click `main.py`** in Solution Explorer
2. **Click "Set as Startup File"**
3. **Edit `.env` file** with database credentials

## Step 6: Run

**Press F5** or click **Start** button (▶️)

Backend will start in console window.

---

# 🛠️ VS Code Features for This Project

## 1. Terminal Commands

**Access terminal:** `` Ctrl+` ``

```bash
# Start backend
python3 main.py

# Test API
python3 test_api.py

# Check database
psql face_recognition_db

# View logs
tail -f uvicorn.log
```

## 2. Debugging

**Set breakpoints:**
- Click left of line number

**Debug configurations:**
- `F5` - Run with debugging
- `Ctrl+F5` - Run without debugging
- `Shift+F5` - Stop debugging

**Debug shortcuts:**
- `F10` - Step over
- `F11` - Step into
- `Shift+F11` - Step out
- `F5` - Continue

## 3. Code Navigation

**Shortcuts:**
- `Ctrl+P` - Quick file open
- `Ctrl+Shift+F` - Search in files
- `F12` - Go to definition
- `Alt+Left/Right` - Navigate back/forward

## 4. Git Integration

**Left sidebar → Source Control:**
- View changes
- Commit changes
- Push to remote

## 5. Extensions Recommended

**Install these for better Python development:**

1. **Python** - Microsoft (required)
2. **Pylance** - Microsoft (language server)
3. **Python Debugger** - Microsoft
4. **autoDocstring** - Generate docstrings
5. **Better Comments** - Colorful comments
6. **GitLens** - Git supercharged

**Install:**
- `Ctrl+Shift+X` → Search → Install

## 6. Database Explorer

**Install: "SQLTools"**
- View database tables
- Run SQL queries
- Visual table browser

**Install: "PostgreSQL" (SQLTools driver)**
- Connect to PostgreSQL
- Browse data

**Setup:**
1. Click SQLTools icon (left)
2. "Add New Connection"
3. Select PostgreSQL
4. Enter database credentials
5. Test connection

## 7. API Testing

**Install: "REST Client"**

Create `test.http` file:
```http
### Health Check
GET http://localhost:3000/health

### Detect Faces
POST http://localhost:3000/api/detect-recognize
Content-Type: application/json

{
  "image": "base64_string_here"
}

### Get Employees
GET http://localhost:3000/api/employees
```

**Click "Send Request"** above each request!

---

# 🎯 Quick Reference

## Starting Backend in VS Code

```bash
# Terminal 1: Backend
python3 main.py

# Terminal 2: Test (keep backend running)
python3 test_api.py
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open file | `Ctrl+P` |
| Command palette | `Ctrl+Shift+P` |
| New terminal | `` Ctrl+` `` |
| Run file | `F5` |
| Search | `Ctrl+Shift+F` |
| Toggle sidebar | `Ctrl+B` |
| Save all | `Ctrl+K S` |

## Common Tasks

### Install Package
```bash
pip3 install package-name
```

### Check Running
```bash
curl http://localhost:3000/health
```

### View Logs
```bash
# In terminal while backend running
# Logs appear automatically
```

### Stop Backend
```bash
# In terminal:
Ctrl+C

# Or click trash icon in terminal panel
```

### Restart Backend
```bash
# Stop with Ctrl+C
python3 main.py
```

---

# 🐛 Troubleshooting

## Issue: "Python not found"

**Solution:**
1. Install Python 3.8+
2. Add to PATH
3. Restart VS Code
4. Select interpreter: `Ctrl+Shift+P` → "Python: Select Interpreter"

## Issue: "Module not found"

**Solution:**
```bash
# Check you're in backend folder
pwd

# Reinstall dependencies
pip3 install -r requirements.txt

# Or use virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Issue: Can't see terminal

**Solution:**
- Press `` Ctrl+` ``
- Or: View → Terminal

## Issue: Database connection error

**Solution:**
1. Check `.env` file exists
2. Verify DATABASE_URL is correct
3. Check database is running:
   ```bash
   psql postgres
   ```

## Issue: Backend won't start

**Solution:**
```bash
# Check Python version
python3 --version  # Should be 3.8+

# Check dependencies
pip3 list

# Check logs for errors
python3 main.py
```

## Issue: Port already in use

**Solution:**
```bash
# Find process using port 3000
lsof -i :3000

# Kill it
kill -9 <PID>

# Or change port in .env
API_PORT=3001
```

---

# ✅ Quick Setup Checklist

- [ ] VS Code installed
- [ ] Python extension installed
- [ ] Opened backend folder in VS Code
- [ ] Python interpreter selected
- [ ] Terminal opened
- [ ] Dependencies installed (`pip3 install -r requirements.txt`)
- [ ] `.env` file created and configured
- [ ] Database running
- [ ] Backend runs (`python3 main.py`)
- [ ] Test passes (`python3 test_api.py`)
- [ ] Can access http://localhost:3000

---

# 🎉 You're Ready!

**Your VS Code is now set up for Python development!**

### To start working:

1. **Open VS Code**
2. **Open backend folder**
3. **Open terminal:** `` Ctrl+` ``
4. **Run:** `python3 main.py`
5. **Code, debug, test!**

### To debug:

1. **Open `main.py`**
2. **Set breakpoint** (click left of line number)
3. **Press F5**
4. **Backend starts in debug mode**
5. **Step through code, inspect variables**

### To test:

1. **Open new terminal** (click `+` in terminal panel)
2. **Run:** `python3 test_api.py`
3. **View results**

---

# 📚 Learn More

**VS Code Python:**
https://code.visualstudio.com/docs/python/python-tutorial

**Debugging:**
https://code.visualstudio.com/docs/python/debugging

**Extensions:**
https://marketplace.visualstudio.com/vscode

---

**Happy coding in Visual Studio Code! 🚀**
