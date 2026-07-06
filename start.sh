#!/bin/bash

set -e

# Configuration
export DISPLAY=:1
export XVFB_RESOLUTION="${WIDTH:-1920}x${HEIGHT:-1080}"
export XVFB_DPI="${DPI:-96}"
export CHROMIUM_USER_DATA_DIR="/data/chrome"
export CHROMIUM_DOWNLOADS_DIR="/data/downloads"
export TZ="${TZ:-UTC}"
export LANGUAGE="${LANGUAGE:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Use PORT from Railway environment, default to 8080
export KASMVNC_PORT="${PORT:-8080}"

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Cleanup function
cleanup() {
    log "Cleaning up stale lock files and sockets..."
    rm -f /tmp/.X1-lock
    rm -f /tmp/.X11-unix/X1
    rm -f /tmp/pulse-*
    rm -f /tmp/pulse-socket
    rm -f /run/user/1000/pulse/native
}

# Start dbus
start_dbus() {
    log "Starting D-Bus..."
    if ! pgrep -u root dbus-daemon > /dev/null; then
        rm -f /var/run/dbus/pid
        mkdir -p /var/run/dbus
        dbus-daemon --config-file=/etc/dbus-1/system.conf --nofork --print-address &
        DBUS_PID=$!
        sleep 1
    fi
}

# Start PulseAudio
start_pulseaudio() {
    log "Starting PulseAudio..."
    mkdir -p /run/user/1000/pulse
    chown browser:browser /run/user/1000/pulse
    
    if ! pgrep -u browser pulseaudio > /dev/null 2>&1; then
        # Kill any existing pulseaudio processes
        pkill -9 -u browser pulseaudio 2>/dev/null || true
        sleep 1
        
        # Start with minimal configuration for containers
        su - browser -c "pulseaudio --daemonize --exit-idle-time=0 \
            --load=module-alsa-sink \
            --load=module-alsa-source \
            --load=module-native-protocol-unix \
            --load=module-null-sink \
            2>&1 | grep -v 'W:' || true" &
        
        # Wait for PulseAudio socket
        local max_attempts=20
        local attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if [ -S /run/user/1000/pulse/native ]; then
                log "PulseAudio started successfully"
                return 0
            fi
            sleep 0.5
            attempt=$((attempt + 1))
        done
        
        error "PulseAudio failed to start"
        return 1
    fi
}

# Start Xvfb
start_xvfb() {
    log "Starting Xvfb (${XVFB_RESOLUTION})..."
    Xvfb :1 -screen 0 ${XVFB_RESOLUTION}x24 -dpi ${XVFB_DPI} \
        -ac -extension GLX +extension RANDR +extension RENDER \
        > /tmp/xvfb.log 2>&1 &
    XVFB_PID=$!
    
    # Wait for X to be ready
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if xdpyinfo -display :1 > /dev/null 2>&1; then
            log "X server (:1) is ready"
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    error "Xvfb failed to start or become ready"
    cat /tmp/xvfb.log
    return 1
}

# Start Openbox
start_openbox() {
    log "Starting Openbox..."
    
    # Ensure autostart file is executable
    chmod +x /home/browser/.config/openbox/autostart
    
    su - browser -c "DISPLAY=:1 openbox --sm-client-id=default --replace" > /tmp/openbox.log 2>&1 &
    OPENBOX_PID=$!
    
    # Wait for window manager
    local max_attempts=20
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if DISPLAY=:1 wmctrl -m > /dev/null 2>&1; then
            log "Window manager (Openbox) is ready"
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    error "Openbox failed to start or become ready"
    cat /tmp/openbox.log 2>/dev/null || true
    return 1
}

# Launch Chromium
launch_chromium() {
    log "Launching Chromium..."
    
    mkdir -p "$CHROMIUM_USER_DATA_DIR"
    mkdir -p "$CHROMIUM_DOWNLOADS_DIR"
    chown -R browser:browser "$CHROMIUM_USER_DATA_DIR"
    chown -R browser:browser "$CHROMIUM_DOWNLOADS_DIR"
    
    # Set homepage
    local HOMEPAGE="${HOMEPAGE:-https://www.google.com}"
    
    # Chromium flags optimized for containers
    local CHROMIUM_FLAGS=(
        "--no-sandbox"
        "--disable-setuid-sandbox"
        "--disable-dev-shm-usage"
        "--disable-gpu"
        "--disable-software-rasterizer"
        "--disable-background-networking"
        "--disable-sync"
        "--disable-component-update"
        "--disable-default-apps"
        "--disable-extensions"
        "--disable-translate"
        "--disable-features=Translate"
        "--no-first-run"
        "--no-default-browser-check"
        "--password-store=basic"
        "--user-data-dir=$CHROMIUM_USER_DATA_DIR"
        "--download-dir=$CHROMIUM_DOWNLOADS_DIR"
        "--allow-running-insecure-content"
        "--disable-web-resources"
        "--disable-preconnect"
        "--disable-client-side-phishing-detection"
        "--disable-component-extensions-with-background-pages"
        "--disable-default-apps"
        "--disable-hang-monitor"
        "--disable-popup-blocking"
        "--disable-prompt-on-repost"
        "--disable-zero-copy"
        "--metrics-recording-only"
        "--mute-audio"
        "--autoplay-policy=user-gesture-required"
    )
    
    su - browser -c "DISPLAY=:1 chromium ${CHROMIUM_FLAGS[@]} '$HOMEPAGE'" > /tmp/chromium.log 2>&1 &
    CHROMIUM_PID=$!
    
    # Wait for Chromium window to appear
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if DISPLAY=:1 wmctrl -l 2>/dev/null | grep -i chromium > /dev/null; then
            log "Chromium window detected"
            sleep 2  # Extra time for rendering
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    error "Chromium window failed to appear"
    cat /tmp/chromium.log 2>/dev/null | tail -20
    return 1
}

# Start KasmVNC
start_kasmvnc() {
    log "Starting KasmVNC on 0.0.0.0:${KASMVNC_PORT}..."
    
    # Kill any existing KasmVNC processes
    pkill -f "KasmVNCSrv\|kasmvnc" 2>/dev/null || true
    sleep 1
    
    su - browser -c "DISPLAY=:1 /opt/kasmvnc/bin/vncserver \
        -name 'Railway Cloud Browser' \
        -geometry ${XVFB_RESOLUTION} \
        -depth 24 \
        -localhost no \
        -SecurityTypes None \
        -PasswordFile /dev/null \
        -interface 0.0.0.0 \
        :${KASMVNC_PORT} \
        > /tmp/kasmvnc.log 2>&1" &
    
    KASMVNC_PID=$!
    
    # Wait for KasmVNC to start
    local max_attempts=20
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if netstat -tuln 2>/dev/null | grep -q ":${KASMVNC_PORT}" || \
           ss -tuln 2>/dev/null | grep -q ":${KASMVNC_PORT}"; then
            log "KasmVNC listening on 0.0.0.0:${KASMVNC_PORT}"
            sleep 2
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    error "KasmVNC failed to start"
    cat /tmp/kasmvnc.log 2>/dev/null
    return 1
}

# Health check loop
health_check_loop() {
    log "Starting health check loop..."
    
    while true; do
        sleep 30
        
        # Check if Chromium is running
        if ! ps -p $CHROMIUM_PID > /dev/null 2>&1; then
            log "Chromium crashed, restarting..."
            launch_chromium || true
        fi
        
        # Check KasmVNC connectivity
        if ! netstat -tuln 2>/dev/null | grep -q ":${KASMVNC_PORT}" && \
           ! ss -tuln 2>/dev/null | grep -q ":${KASMVNC_PORT}"; then
            log "KasmVNC is not responding, restarting..."
            pkill -f "KasmVNCSrv\|kasmvnc" 2>/dev/null || true
            sleep 2
            start_kasmvnc || true
        fi
    done
}

# Main startup sequence
main() {
    log "========================================="
    log "Railway Cloud Browser - KasmVNC"
    log "========================================="
    log "Display: $DISPLAY"
    log "Resolution: $XVFB_RESOLUTION"
    log "KasmVNC Port: $KASMVNC_PORT"
    log "========================================="
    
    # Run as browser user where possible, preserve root for necessary operations
    if [ "$EUID" -ne 0 ]; then
        error "This script must run as root"
        exit 1
    fi
    
    cleanup || true
    
    if ! start_dbus; then
        error "Failed to start D-Bus"
        exit 1
    fi
    
    if ! start_pulseaudio; then
        error "Failed to start PulseAudio (audio will not work)"
        # Don't exit, continue without audio
    fi
    
    if ! start_xvfb; then
        error "Failed to start Xvfb"
        exit 1
    fi
    
    if ! start_openbox; then
        error "Failed to start Openbox"
        exit 1
    fi
    
    if ! launch_chromium; then
        error "Failed to launch Chromium"
        exit 1
    fi
    
    if ! start_kasmvnc; then
        error "Failed to start KasmVNC"
        exit 1
    fi
    
    log "========================================="
    log "✓ Ready"
    log "========================================="
    log "Access at: http://localhost:${KASMVNC_PORT}"
    log "Or visit your Railway app URL"
    log "========================================="
    
    # Run health check loop in background
    health_check_loop &
    
    # Keep the container running
    wait
}

# Run main function
main "$@"
