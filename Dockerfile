FROM alpine:3.16

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    DIA_LOG_DIR=/var/log/dia

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-numpy \
    alsa-utils \
    alsa-lib \
    alsa-lib-dev \
    portaudio-dev \
    espeak \
    gcc \
    g++ \
    make \
    linux-headers \
    python3-dev \
    git \
    sqlite \
    sudo \
    pulseaudio-utils \
    pulseaudio-alsa

# Create app directory
WORKDIR /opt/dia

# Create log directory
RUN mkdir -p /var/log/dia && chmod 777 /var/log/dia

# Create necessary directories
RUN mkdir -p /opt/dia/models/{asr,llm,tts,wake} \
    && mkdir -p /opt/dia/config \
    && mkdir -p /opt/dia/logs

# Copy requirements first (for better caching)
COPY requirements.txt .
RUN pip3 install --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY config/ ./config/
COPY scripts/ ./scripts/

# Make scripts executable
RUN chmod +x ./scripts/*.sh

# Create a non-root user to run the app
RUN adduser -D -u 1000 diauser && \
    chown -R diauser:diauser /opt/dia /var/log/dia

# Switch to non-root user
USER diauser

# Run the application
CMD ["python3", "src/dia_assistant.py", "--config", "config/dia.yaml"]
