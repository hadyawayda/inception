#!/bin/bash
set -e
# Healthy if any php-fpm process is running
pgrep -f "php-fpm" >/dev/null 2>&1
