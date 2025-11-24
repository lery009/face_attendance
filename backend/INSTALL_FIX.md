# 🔧 Installation Fix for Python 3.12

## Problem
You have Python 3.12, and `numpy==1.24.3` isn't compatible. The error:
```
Cannot import 'setuptools.build_meta'
```

## ✅ Solution (Run These Commands)

### Step 1: Upgrade pip and setuptools

```bash
pip3 install --upgrade pip setuptools wheel
```

Wait for it to complete.

### Step 2: Install dependencies (updated)

```bash
pip3 install --user -r requirements.txt
```

This will install the **updated** requirements.txt that's compatible with Python 3.12.

---

## Alternative: Use Virtual Environment (Recommended)

**This isolates dependencies and prevents conflicts:**

```bash
# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate  # macOS/Linux
# OR
venv\Scripts\activate     # Windows

# Upgrade pip in venv
pip install --upgrade pip setuptools wheel

# Install dependencies
pip install -r requirements.txt
```

**Now everything installs in the virtual environment!**

When you want to run the backend:
```bash
# Always activate venv first
source venv/bin/activate

# Then run
python main.py
```

---

## What I Fixed

Updated `requirements.txt`:
- ❌ Old: `numpy==1.24.3` (incompatible with Python 3.12)
- ✅ New: `numpy>=1.26.0` (compatible)

---

## Try Now

```bash
# Quick fix
pip3 install --upgrade pip setuptools wheel
pip3 install --user -r requirements.txt

# OR use virtual environment (better)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Then run:
```bash
python3 main.py
```

✅ Should work now!
