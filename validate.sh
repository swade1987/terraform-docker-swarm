
#!/usr/bin/env bash
set -e
function validate {
    terraform validate $1
}
function list_dirs {
    for path in $1; do
        [ -d "${path}" ] || continue
        echo "  $path"
        validate $path
    done
}
function log_validation_started {
    echo "Validating $1 config..."
}
function log_validation_complete {
    echo "[OK] $1 config"
}

log_validation_started "environments/ci"
validate environments/ci
log_validation_complete "environments/ci"

log_validation_started "modules"
list_dirs "modules/*/"
log_validation_complete "module"