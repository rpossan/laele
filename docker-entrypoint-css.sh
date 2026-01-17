#!/bin/bash
set -e

# Remove um PID de servidor pré-existente se existir
rm -f /rails/tmp/pids/server.pid

echo "Iniciando compilador Tailwind CSS..."

# Executar o comando passado para o container
exec "$@"
