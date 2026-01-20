# Setup Docker para Desenvolvimento

Este guia explica como executar o projeto em ambiente de desenvolvimento usando Docker Compose.

## Pré-requisitos

- Docker
- Docker Compose

## Estrutura

O setup inclui 4 serviços:

- **web**: Aplicação Rails
- **css**: Compilador Tailwind CSS (watch mode)
- **db**: PostgreSQL 16
- **redis**: Redis 7 (para cache e jobs)

## Como usar

### 1. Build dos containers

```bash
docker-compose build
```

### 2. Iniciar os serviços

```bash
docker-compose up
```

Ou em background:

```bash
docker-compose up -d
```

### 3. Acessar a aplicação

A aplicação estará disponível em: http://localhost:3000

### 4. Executar comandos Rails

```bash
# Abrir console Rails
docker-compose exec web bundle exec rails console

# Executar migrations
docker-compose exec web bundle exec rails db:migrate

# Criar seed data
docker-compose exec web bundle exec rails db:seed

# Executar testes
docker-compose exec web bundle exec rails test

# Acessar bash no container
docker-compose exec web bash
```

### 5. Ver logs

```bash
# Todos os serviços
docker-compose logs -f

# Apenas a aplicação web
docker-compose logs -f web

# Apenas o banco de dados
docker-compose logs -f db
```

### 6. Parar os serviços

```bash
docker-compose down
```

Para remover também os volumes (dados do banco):

```bash
docker-compose down -v
```

## Variáveis de Ambiente

As variáveis de ambiente são carregadas do arquivo `.env` na raiz do projeto.

Principais variáveis:

- `GOOGLE_ADS_CLIENT_ID`
- `GOOGLE_ADS_CLIENT_SECRET`
- `GOOGLE_ADS_DEVELOPER_TOKEN`
- `GOOGLE_ADS_REDIRECT_URI`

## Troubleshooting

### Erro de permissão

Se encontrar erros de permissão, execute:

```bash
sudo chown -R $USER:$USER .
```

### Resetar o banco de dados

```bash
docker-compose down -v
docker-compose up -d db
docker-compose exec web bundle exec rails db:create db:migrate db:seed
```

### Reinstalar gems

```bash
docker-compose down
docker-compose build --no-cache web
docker-compose up
```

### Container não inicia

Verifique os logs:

```bash
docker-compose logs web
```

## Desenvolvimento

Os arquivos do projeto são montados como volume, então mudanças no código são refletidas automaticamente (com hot reload do Rails).

O serviço `css` monitora mudanças nos arquivos e recompila o Tailwind CSS automaticamente.

Para instalar novas gems:

1. Adicione a gem no `Gemfile`
2. Execute: `docker-compose exec web bundle install`
3. Reinicie o container: `docker-compose restart web`
