FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV PULSE_SERVER=unix:/run/user/1000/pulse/native

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add Chromium repository (bookworm-backports is official Debian, no custom keyring needed)
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bookworm-backports.list

# Install X11, display, and desktop environment
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    x11-utils \
    x11-xserver-utils \
    dbus-x11 \
    openbox \
    libgtk-3-0 \
    libxss1 \
    fonts-dejavu \
    fonts-liberation \
    fonts-noto \
    fonts-noto-cjk \
    xfce4-panel \
    xfce4-terminal \
    thunar \
    tint2 \
    supervisor \
    psmisc \
    procps \
    curl \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Chromium from backports (stable, optimized for containers)
RUN apt-get update && apt-get install -y --no-install-recommends \
    -t bookworm-backports \
    chromium \
    chromium-sandbox \
    && rm -rf /var/lib/apt/lists/*

# Install KasmVNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libc6 \
    libxfixes3 \
    libxdamage1 \
    libxrandr2 \
    libxtst6 \
    libxi6 \
    libxext6 \
    libxrender1 \
    libxkbfile1 \
    x11-xkb-utils \
    xfonts-encodings \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.3.2/KasmVNC-1.3.2-focal-x86_64.tar.gz && \
    tar -xzf KasmVNC-1.3.2-focal-x86_64.tar.gz -C / && \
    rm KasmVNC-1.3.2-focal-x86_64.tar.gz

# Create non-root user for browser
RUN useradd -m -s /bin/bash -u 1000 browser && \
    mkdir -p /data && \
    chown -R browser:browser /data && \
    chmod 755 /data

# Create directory structure
RUN mkdir -p /var/run/dbus && \
    mkdir -p /run/user/1000 && \
    mkdir -p /tmp/.X11-unix && \
    mkdir -p /data/chrome && \
    mkdir -p /data/downloads && \
    mkdir -p /home/browser/.config/openbox && \
    mkdir -p /home/browser/.config/pulse && \
    mkdir -p /home/browser/.cache && \
    chown -R browser:browser /run/user/1000 && \
    chown -R browser:browser /home/browser && \
    chmod 1777 /tmp/.X11-unix

# Copy configuration files
COPY openbox-autostart.sh /home/browser/.config/openbox/autostart
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pulseaudio-client.conf /home/browser/.config/pulse/client.conf

# Copy startup scripts
COPY start.sh /opt/start.sh
COPY healthcheck.sh /opt/healthcheck.sh

# Make scripts executable
RUN chmod +x /opt/start.sh /opt/healthcheck.sh && \
    chmod +x /home/browser/.config/openbox/autostart

# Fix permissions
RUN chown -R browser:browser /home/browser && \
    chown -R root:root /opt && \
    chown -R root:root /etc/supervisor

# Set working directory
WORKDIR /home/browser

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/healthcheck.sh

EXPOSE 8080

CMD ["/opt/start.sh"]
