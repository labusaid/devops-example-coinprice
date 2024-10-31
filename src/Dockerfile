FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY httpServer.py .

# Expose port 5000
EXPOSE 5000

# Run app
CMD ["python", "httpServer.py"]