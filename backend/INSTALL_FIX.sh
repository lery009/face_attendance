#!/bin/bash
echo "🔧 Fixing Python 3.12 Installation Issues..."

# Upgrade pip and setuptools
echo "📦 Upgrading pip and setuptools..."
pip3 install --upgrade pip setuptools wheel

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install --user -r requirements.txt

echo "✅ Installation complete!"
