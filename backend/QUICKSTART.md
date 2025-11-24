# 🚀 Quick Start Guide

Get the backend running in **5 minutes**!

## Step 1: Install Python Dependencies

```bash
cd backend

# Install packages
pip3 install -r requirements.txt
```

**Wait 5-10 minutes** for installation (downloads ML models).

---

## Step 2: Set Up Database

### Option A: PostgreSQL (Recommended)

```bash
# Install PostgreSQL
brew install postgresql  # macOS

# Start PostgreSQL
brew services start postgresql

# Create database
psql postgres -c "CREATE DATABASE face_recognition_db;"
```

### Option B: MySQL

```bash
# Install MySQL
brew install mysql

# Start MySQL
brew services start mysql

# Create database
mysql -u root -e "CREATE DATABASE face_recognition_db;"
```

---

## Step 3: Configure Settings

```bash
# Copy example config
cp .env.example .env

# Edit with your database credentials
nano .env
```

**For PostgreSQL (default):**
```env
DATABASE_URL=postgresql://your_username:your_password@localhost:5432/face_recognition_db
```

**For MySQL:**
```env
DATABASE_URL=mysql+pymysql://your_username:your_password@localhost:3306/face_recognition_db
```

---

## Step 4: Run the Backend

```bash
python3 main.py
```

**Expected output:**
```
✅ Database tables created successfully
🚀 Face Recognition Backend Started
📍 API running at: http://0.0.0.0:3000
```

**API is ready at:** http://localhost:3000

---

## Step 5: Test the Backend

```bash
# In a new terminal
python3 test_api.py
```

**If you see:**
```
✅ API is healthy!
✅ Registration successful!
✅ Detected 1 face(s)
✅ Test Suite Complete!
```

**You're ready! 🎉**

---

## Step 6: Connect Flutter App

1. **Start Flutter web:**
   ```bash
   cd ..  # Go back to project root
   flutter run -d chrome
   ```

2. **Click "Recognize Face"**

3. **Allow camera permission**

4. **Look at camera** - you should see face detection!

---

## 🐛 Troubleshooting

### "pip: command not found"
```bash
# Use pip3 instead
pip3 install -r requirements.txt
```

### "No module named 'face_recognition'"
```bash
# Install build tools first
pip3 install cmake
pip3 install dlib
pip3 install face-recognition
```

### "Database connection error"
```bash
# Check database is running
psql postgres  # PostgreSQL
mysql         # MySQL

# Verify DATABASE_URL in .env file
```

### "Permission denied: /usr/local/..."
```bash
# Use virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## ✅ Quick Checklist

- [ ] Python 3.8+ installed
- [ ] PostgreSQL or MySQL running
- [ ] Dependencies installed (`pip install -r requirements.txt`)
- [ ] `.env` file configured
- [ ] Backend running (`python main.py`)
- [ ] Test passes (`python test_api.py`)
- [ ] Flutter web connects

---

## 📚 Next Steps

1. ✅ **Backend running** → Go to Step 6 (Connect Flutter)
2. ⚠️ **Errors?** → Check troubleshooting section
3. 📖 **More details?** → Read `README.md`

---

## 🆘 Need Help?

**Check:**
1. This guide (QUICKSTART.md)
2. Full docs (README.md)
3. Terminal error messages
4. Database is running
5. `.env` file is correct

**Common issues:**
- Wrong database credentials in `.env`
- Database not running
- Missing dependencies
- Wrong Python version (need 3.8+)

---

## 🎉 Success!

Backend is running! Now connect your Flutter web app and test the complete system!

**API Endpoints Ready:**
- ✅ `/api/detect-recognize` - Face detection
- ✅ `/api/employees/register-with-image` - Registration
- ✅ `/api/attendance` - Attendance logs

**Happy coding! 🚀**
