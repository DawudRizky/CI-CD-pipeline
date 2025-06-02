#!/bin/bash
# Simple test script to check required files exist

echo "Running tests for CarVilla web application"

# Check if index.html exists
if [ ! -f index.html ]; then
  echo "Error: index.html not found!"
  exit 1
fi

# Check if assets directory exists
if [ ! -d assets ]; then
  echo "Error: assets directory not found!"
  exit 1
fi

# Check if required JavaScript files exist
if [ ! -f assets/js/custom.js ]; then
  echo "Error: custom.js not found!"
  exit 1
fi

# Check if CSS files exist
if [ ! -f assets/css/style.css ]; then
  echo "Error: style.css not found!"
  exit 1
fi

echo "All tests passed successfully!"
exit 0
