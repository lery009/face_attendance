# ⚡ VS Code Quick Start (2 Minutes)

Super quick guide to run the backend in VS Code!

---

## Step 1: Open VS Code

```
Open VS Code → File → Open Folder → Select "backend" folder
```

---

## Step 2: Install Python Extension

1. Click **Extensions icon** (4 squares on left sidebar)
2. Search: **"Python"**
3. Click **Install** on "Python by Microsoft"

---

## Step 3: Open Terminal

```
Press: Ctrl+` (backtick key, below Esc)
```

Or:
```
Menu: Terminal → New Terminal
```

---

## Step 4: Install Dependencies

**In terminal at bottom:**

```bash
pip3 install -r requirements.txt
```

⏳ Wait 5-10 minutes

---

## Step 5: Configure Database

1. **Duplicate `.env.example`** → rename to `.env`
2. **Edit `.env`** → Update `DATABASE_URL` with your credentials

```env
DATABASE_URL=postgresql://user:password@localhost:5432/face_recognition_db
```

---

## Step 6: Run!

**In terminal:**

```bash
python3 main.py
```

✅ **You should see:**
```
✅ Database tables created successfully
🚀 Face Recognition Backend Started
📍 API running at: http://0.0.0.0:3000
```

---

## Step 7: Test It

**Open NEW terminal** (click `+` icon in terminal panel)

```bash
python3 test_api.py
```

✅ **You should see:**
```
✅ API is healthy!
✅ Test Suite Complete!
```

---

## 🎉 Done!

**Backend is running in VS Code!**

**Access API:** http://localhost:3000

**Stop backend:** Press `Ctrl+C` in terminal

**Restart:** Run `python3 main.py` again

---

## 💡 Pro Tips

### Run with F5 (Debug Mode)

1. Open `main.py`
2. Press **F5**
3. Select: **"Python: FastAPI Backend"**
4. Backend starts with debugging enabled!

### Quick Tasks

Press `Ctrl+Shift+P` and type:

- **"Tasks: Run Task"** → Choose:
  - ▶️ Run Backend
  - 🧪 Test API
  - 📦 Install Dependencies

### Multiple Terminals

- Click **`+`** icon to open new terminal
- Keep backend running in Terminal 1
- Run tests in Terminal 2

---

## 🐛 Quick Fixes

### "Python not found"
```bash
# Install Python first
brew install python3  # macOS
# Or download from python.org
```

### "Module not found"
```bash
pip3 install -r requirements.txt
```

### Database error
```bash
# Check database is running
psql postgres

# Verify .env file is correct
```

---

## 📚 Need More Help?

**Full Guide:** Read `VISUAL_STUDIO_SETUP.md`

**Backend Docs:** Read `README.md`

**Quick Setup:** Read `QUICKSTART.md`

---

## ✅ That's It!

Your backend is running in VS Code! 🚀

**Now:**
1. Keep backend running
2. Open Flutter web: `flutter run -d chrome`
3. Test the complete system!
