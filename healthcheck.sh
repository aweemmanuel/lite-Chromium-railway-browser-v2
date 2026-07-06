#!/bin/bash
# Health check script for KasmVNC service
curl -f http://localhost:8080/ > /dev/null 2>&1
exit $?
