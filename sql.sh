#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar variables de entorno
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Error: no se encuentra el archivo .env"
    exit 1
fi

set -a
source "$SCRIPT_DIR/.env"
set +a

# Validar argumento
if [ -z "$1" ]; then
    echo "Uso: $0 archivo.sql"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: no existe el archivo '$1'"
    exit 1
fi

# Ejecutar archivo SQL
psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -f "$1"

if [ $? -eq 0 ]; then
    echo "Archivo SQL ejecutado correctamente."
else
    echo "Error al ejecutar el archivo SQL."
    exit 1
fi 
