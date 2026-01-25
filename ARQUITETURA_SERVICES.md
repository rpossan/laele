# Arquitetura de Services - Google Ads Customers

## Estrutura de Diretórios

```
app/
├── services/
│   └── google_ads/
│       ├── customer_name_service.rb      ← Gerencia nomes personalizados
│       ├── customer_list_service.rb      ← Gerencia lista de contas
│       └── customer_refresh_service.rb   ← Atualiza contas da API
└── controllers/
    └── api/
        └── google_ads/
            ├── customer_names_controller.rb    ← Thin controller
            └── customers_controller.rb         ← Thin controller
```

## Services Criados

### 1. `GoogleAds::CustomerNameService`
**Responsabilidade**: Gerenciar nomes personalizados das contas

**Métodos públicos**:
- `update_custom_name(customer_id, custom_name)` - Atualiza nome de uma conta
- `bulk_update_custom_names(updates)` - Atualiza múltiplas contas
- `smart_fetch_names()` - Busca inteligente de nomes da API

**Métodos privados**:
- `find_customer_for_user(customer_id)` - Encontra conta do usuário
- `get_customers_without_names()` - Lista contas sem nome
- `fetch_names_for_customers(customers)` - Busca nomes em lote
- `fetch_and_update_customer_name(customer, google_account)` - Busca individual

**Retorno**: Hash com `success`, `message`, `error`, etc.

### 2. `GoogleAds::CustomerListService`
**Responsabilidade**: Gerenciar lista e seleção de contas

**Métodos públicos**:
- `all_customers()` - Retorna todas as contas do usuário
- `find_customer(customer_id)` - Encontra uma conta específica
- `select_customer(customer_id)` - Seleciona uma conta como ativa

**Retorno**: Hash com dados da conta ou erro

### 3. `GoogleAds::CustomerRefreshService`
**Responsabilidade**: Atualizar contas da API do Google Ads

**Métodos públicos**:
- `refresh_customers()` - Atualiza lista de contas da API

**Métodos privados**:
- `fetch_and_update_customers(service, google_account, customer_ids)` - Processa contas
- `fetch_batch_customer_details(service, customer_ids)` - Busca em lote
- `fetch_and_update_individual_customer(service, accessible_customer, customer_id)` - Busca individual

**Retorno**: Hash com `success`, `message`, `customers`, etc.

## Controllers Refatorados

### `Api::GoogleAds::CustomerNamesController`
```ruby
def update
  service = GoogleAds::CustomerNameService.new(current_user)
  result = service.update_custom_name(params[:customer_id], params[:custom_name])
  # Renderiza resultado
end
```

**Responsabilidades**:
- Receber requisição HTTP
- Chamar service apropriado
- Renderizar resposta JSON

### `Api::GoogleAds::CustomersController`
```ruby
def index
  service = GoogleAds::CustomerListService.new(current_user)
  customers = service.all_customers
  # Renderiza resultado
end
```

**Responsabilidades**:
- Receber requisição HTTP
- Chamar service apropriado
- Renderizar resposta JSON

## Fluxo de Dados

### Atualizar Nome Personalizado
```
Controller (update)
    ↓
CustomerNameService.update_custom_name()
    ↓
find_customer_for_user()
    ↓
customer.update()
    ↓
Retorna resultado
```

### Busca Inteligente de Nomes
```
Controller (smart_fetch)
    ↓
CustomerNameService.smart_fetch_names()
    ↓
get_customers_without_names()
    ↓
fetch_names_for_customers()
    ↓
fetch_and_update_customer_name() [para cada conta]
    ↓
GoogleAds::CustomerService.fetch_customer_details()
    ↓
customer.update()
    ↓
Retorna resultado
```

### Selecionar Conta
```
Controller (select)
    ↓
CustomerListService.select_customer()
    ↓
find_customer()
    ↓
ActiveCustomerSelection.save()
    ↓
fetch_customer_name_if_needed() [se necessário]
    ↓
Retorna resultado
```

## Benefícios da Arquitetura

✅ **Separação de Responsabilidades**
- Controllers: HTTP e renderização
- Services: Lógica de negócio
- Models: Persistência

✅ **Reutilização**
- Services podem ser usados em múltiplos controllers
- Fácil de testar isoladamente
- Lógica centralizada

✅ **Manutenção**
- Código mais limpo e legível
- Fácil de encontrar e atualizar lógica
- Menos duplicação

✅ **Testabilidade**
- Services podem ser testados sem HTTP
- Mocks mais simples
- Testes mais rápidos

✅ **Escalabilidade**
- Fácil adicionar novos services
- Estrutura pronta para crescer
- Padrão consistente

## Como Adicionar Novo Service

1. Crie arquivo em `app/services/google_ads/novo_service.rb`
2. Defina classe com `initialize(user)`
3. Implemente métodos públicos
4. Use em controllers chamando `GoogleAds::NovoService.new(current_user)`

Exemplo:
```ruby
module GoogleAds
  class NovoService
    def initialize(user)
      @user = user
    end

    def fazer_algo
      # lógica aqui
      { success: true, message: "Feito!" }
    end
  end
end
```

## Padrão de Retorno

Todos os services retornam hash com:
```ruby
{
  success: true/false,
  message: "Mensagem para usuário",
  error: "Mensagem de erro (se houver)",
  data: { ... }  # dados específicos
}
```

## Logging

Cada service registra suas operações:
- `[ServiceName]` - Prefixo para fácil identificação
- ✅ Sucesso
- ⚠️ Aviso
- ❌ Erro

Exemplo:
```
[CustomerNameService] ✅ Fetched name for 123456789: Minha Conta
[CustomerRefreshService] Processing customer 1/10: 123456789
[CustomerRefreshService] ❌ Could not fetch details for 987654321
```

## Próximos Passos

Para manter a qualidade:

1. **Testes**: Adicione testes unitários para cada service
2. **Validação**: Adicione validações mais robustas
3. **Cache**: Considere cache para operações frequentes
4. **Async**: Considere jobs para operações longas
