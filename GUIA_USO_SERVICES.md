# Guia de Uso - Services Google Ads

## Visão Geral

Os services encapsulam toda a lógica de negócio relacionada a contas Google Ads. Use-os em controllers, jobs, ou qualquer outro lugar que precise dessa lógica.

## Services Disponíveis

### 1. CustomerNameService

Gerencia nomes personalizados das contas.

#### Inicializar
```ruby
service = GoogleAds::CustomerNameService.new(current_user)
```

#### Atualizar Nome de Uma Conta
```ruby
result = service.update_custom_name(customer_id, custom_name)

# Resultado
{
  success: true,
  message: "Nome personalizado atualizado com sucesso",
  customer_id: "123456789",
  custom_name: "Minha Conta",
  effective_name: "Minha Conta"
}
```

#### Atualizar Múltiplas Contas
```ruby
updates = [
  { customer_id: "123456789", custom_name: "Conta 1" },
  { customer_id: "987654321", custom_name: "Conta 2" }
]

result = service.bulk_update_custom_names(updates)

# Resultado
{
  success: true,
  message: "Atualização concluída",
  updated_count: 2,
  total_processed: 2,
  errors: []
}
```

#### Busca Inteligente de Nomes
```ruby
result = service.smart_fetch_names

# Resultado
{
  success: true,
  message: "Busca inteligente concluída",
  updated_count: 3,
  total_processed: 5,
  note: "Apenas contas com permissão adequada foram processadas"
}
```

### 2. CustomerListService

Gerencia lista e seleção de contas.

#### Inicializar
```ruby
service = GoogleAds::CustomerListService.new(current_user)
```

#### Obter Todas as Contas
```ruby
customers = service.all_customers

# Resultado
[
  {
    id: "123456789",
    display_name: "Minha Conta",
    currency_code: "USD",
    role: "ADMIN",
    login_customer_id: "123456789",
    google_account_id: 1
  },
  # ... mais contas
]
```

#### Encontrar Uma Conta
```ruby
customer = service.find_customer(customer_id)

# Resultado
#<AccessibleCustomer id=1, customer_id="123456789", display_name="Minha Conta", ...>
```

#### Selecionar Conta Ativa
```ruby
result = service.select_customer(customer_id)

# Resultado
{
  success: true,
  message: "Conta ativa atualizada",
  customer_id: "123456789",
  display_name: "Minha Conta",
  previous_customer_id: "987654321"
}
```

### 3. CustomerRefreshService

Atualiza contas da API do Google Ads.

#### Inicializar
```ruby
service = GoogleAds::CustomerRefreshService.new(current_user)
```

#### Atualizar Contas
```ruby
result = service.refresh_customers

# Resultado
{
  success: true,
  message: "Contas atualizadas com sucesso",
  customers: [
    {
      id: "123456789",
      display_name: "Minha Conta",
      currency_code: "USD",
      role: "ADMIN",
      login_customer_id: "123456789",
      google_account_id: 1
    },
    # ... mais contas
  ]
}
```

## Exemplos de Uso em Controllers

### Exemplo 1: Atualizar Nome
```ruby
class Api::GoogleAds::CustomerNamesController < Api::BaseController
  def update
    service = GoogleAds::CustomerNameService.new(current_user)
    result = service.update_custom_name(params[:customer_id], params[:custom_name])

    if result[:success]
      render json: result
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
```

### Exemplo 2: Listar Contas
```ruby
class Api::GoogleAds::CustomersController < Api::BaseController
  def index
    service = GoogleAds::CustomerListService.new(current_user)
    customers = service.all_customers

    render json: { customers: customers }
  end
end
```

### Exemplo 3: Selecionar Conta
```ruby
class Api::GoogleAds::CustomersController < Api::BaseController
  def select
    service = GoogleAds::CustomerListService.new(current_user)
    result = service.select_customer(params[:customer_id])

    unless result[:success]
      return render json: { error: result[:error] }, status: :not_found
    end

    session[:active_customer_id] = result[:customer_id]
    render json: result
  end
end
```

## Exemplos de Uso em Jobs

### Exemplo: Background Job
```ruby
class RefreshCustomersJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    service = GoogleAds::CustomerRefreshService.new(user)
    result = service.refresh_customers

    if result[:success]
      Rails.logger.info("Customers refreshed for user #{user_id}")
    else
      Rails.logger.error("Failed to refresh customers: #{result[:error]}")
    end
  end
end
```

## Tratamento de Erros

### Padrão de Resposta
```ruby
result = service.update_custom_name(customer_id, custom_name)

if result[:success]
  # Sucesso
  puts result[:message]
  puts result[:customer_id]
else
  # Erro
  puts result[:error]
end
```

### Erros Comuns
```ruby
# Conta não encontrada
{
  success: false,
  error: "Conta não encontrada"
}

# Nenhuma atualização fornecida
{
  success: false,
  error: "Nenhuma atualização fornecida"
}

# Erro ao atualizar
{
  success: false,
  error: "Erro ao atualizar nome: ..."
}
```

## Logging

Todos os services registram suas operações:

```
[CustomerNameService] ✅ Fetched name for 123456789: Minha Conta
[CustomerRefreshService] Processing customer 1/10: 123456789
[CustomerRefreshService] ❌ Could not fetch details for 987654321
```

Procure por esses prefixos nos logs para debugar.

## Boas Práticas

### 1. Sempre Verificar Sucesso
```ruby
result = service.update_custom_name(customer_id, custom_name)

if result[:success]
  # Fazer algo
else
  # Tratar erro
end
```

### 2. Usar em Controllers
```ruby
# ✅ Bom
def update
  service = GoogleAds::CustomerNameService.new(current_user)
  result = service.update_custom_name(params[:customer_id], params[:custom_name])
  render json: result
end

# ❌ Evitar
def update
  # Lógica diretamente no controller
end
```

### 3. Reutilizar Services
```ruby
# ✅ Bom - Reutilizar em múltiplos lugares
service = GoogleAds::CustomerListService.new(current_user)
customer = service.find_customer(customer_id)

# ❌ Evitar - Duplicar lógica
customer = AccessibleCustomer.find_by(customer_id: customer_id)
```

### 4. Testar Services
```ruby
# ✅ Bom - Testar service isoladamente
describe GoogleAds::CustomerNameService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  it "updates custom name" do
    result = service.update_custom_name(customer_id, "New Name")
    expect(result[:success]).to be true
  end
end
```

## Estrutura de Resposta Padrão

Todos os services retornam:

```ruby
{
  success: true/false,           # Indica sucesso ou erro
  message: "Mensagem",           # Mensagem para usuário
  error: "Erro (se houver)",     # Mensagem de erro
  # ... dados específicos do service
}
```

## Próximos Passos

1. **Adicionar Testes**: Crie testes para cada service
2. **Adicionar Validações**: Valide inputs mais rigorosamente
3. **Adicionar Cache**: Cache resultados frequentes
4. **Adicionar Async**: Use jobs para operações longas

## Suporte

Para dúvidas ou problemas:
1. Verifique os logs com prefixo `[ServiceName]`
2. Consulte a documentação em `ARQUITETURA_SERVICES.md`
3. Verifique os testes para exemplos de uso
