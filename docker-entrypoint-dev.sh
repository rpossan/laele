#!/bin/bash
set -e

# Remove um PID de servidor pré-existente se existir
rm -f /rails/tmp/pids/server.pid

# Aguardar o banco de dados estar pronto
echo "Aguardando o banco de dados..."
until pg_isready -h $DB_HOST -U $DB_USER; do
  echo "Banco de dados não está pronto - aguardando..."
  sleep 2
done

echo "Banco de dados está pronto!"

# Criar o banco de dados se não existir
bundle exec rails db:create 2>/dev/null || true

# Executar migrations
bundle exec rails db:migrate 2>/dev/null || true

# Executar o comando passado para o container
exec "$@"
