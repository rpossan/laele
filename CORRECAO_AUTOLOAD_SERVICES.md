# Correção - Autoload de Services

## Problema

Ao tentar usar os services, o Rails retornava:
```
NameError (uninitialized constant Api::GoogleAds::CustomerNameService)
```

## Causa

O Rails 8.0 não estava carregando automaticamente os services do diretório `app/services`.

## Solução

### 1. Adicionar Autoload Path

Editei `config/application.rb` para adicionar o autoload path:

```ruby
# Autoload services
config.autoload_paths << Rails.root.join("app/services")
```

Isso permite que o Rails carregue automaticamente qualquer classe em `app/services` e seus subdiretórios.

### 2. Usar Namespace Completo

Nos controllers, usei `::` para referenciar o namespace global:

```ruby
# ✅ Correto
service = ::GoogleAds::CustomerNameService.new(current_user)

# ❌ Evitar
service = GoogleAds::CustomerNameService.new(current_user)
```

O `::` garante que o Rails procure a constante no namespace global, não no namespace do controller.

## Arquivos Modificados

### `config/application.rb`
```ruby
config.autoload_paths << Rails.root.join("app/services")
```

### `app/controllers/api/google_ads/customer_names_controller.rb`
```ruby
service = ::GoogleAds::CustomerNameService.new(current_user)
```

### `app/controllers/api/google_ads/customers_controller.rb`
```ruby
service = ::GoogleAds::CustomerListService.new(current_user)
service = ::GoogleAds::CustomerRefreshService.new(current_user)
```

## Estrutura de Diretórios

```
app/
├── services/
│   └── google_ads/
│       ├── customer_name_service.rb
│       ├── customer_list_service.rb
│       └── customer_refresh_service.rb
└── controllers/
    └── api/
        └── google_ads/
            ├── customer_names_controller.rb
            └── customers_controller.rb
```

## Como Funciona

1. **Autoload Path**: Rails procura em `app/services` por classes
2. **Namespace**: `GoogleAds::CustomerNameService` é encontrado em `app/services/google_ads/customer_name_service.rb`
3. **Carregamento**: Rails carrega automaticamente quando a classe é referenciada
4. **Recarregamento**: Em desenvolvimento, Rails recarrega automaticamente quando o arquivo muda

## Verificação

Para verificar se está funcionando:

```ruby
# No console Rails
rails console

# Testar se a classe está disponível
GoogleAds::CustomerNameService
# => GoogleAds::CustomerNameService

# Criar instância
service = GoogleAds::CustomerNameService.new(User.first)
# => #<GoogleAds::CustomerNameService:0x...>
```

## Boas Práticas

### 1. Sempre Use `::` em Controllers
```ruby
# ✅ Bom
service = ::GoogleAds::CustomerNameService.new(current_user)

# ❌ Evitar
service = GoogleAds::CustomerNameService.new(current_user)
```

### 2. Estrutura de Diretórios
```
app/services/
├── google_ads/
│   ├── customer_name_service.rb
│   ├── customer_list_service.rb
│   └── customer_refresh_service.rb
└── other_domain/
    └── some_service.rb
```

### 3. Naming Convention
- Arquivo: `snake_case.rb`
- Classe: `CamelCase`
- Exemplo: `customer_name_service.rb` → `GoogleAds::CustomerNameService`

## Próximos Passos

Se adicionar novos services:

1. Crie arquivo em `app/services/google_ads/novo_service.rb`
2. Defina classe `GoogleAds::NovoService`
3. Use em controllers com `::GoogleAds::NovoService.new(current_user)`
4. Rails carregará automaticamente

## Troubleshooting

### Erro: "uninitialized constant"
- Verifique se o arquivo existe em `app/services`
- Verifique o nome da classe (deve ser CamelCase)
- Reinicie o servidor Rails

### Erro: "wrong number of arguments"
- Verifique se o service recebe `user` no construtor
- Verifique se está passando `current_user`

### Mudanças não aparecem
- Em desenvolvimento, Rails recarrega automaticamente
- Se não funcionar, reinicie o servidor

## Conclusão

A correção foi simples:
1. ✅ Adicionar autoload path em `config/application.rb`
2. ✅ Usar `::` para referenciar services nos controllers
3. ✅ Seguir naming conventions

Agora os services funcionam perfeitamente! 🚀
