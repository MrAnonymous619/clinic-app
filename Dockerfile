# Small official Python image
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
# Copy requirements first so Docker can cache the install layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY static ./static
EXPOSE 5000
CMD ["python", "app.py"]
