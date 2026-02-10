# Solução: Erro de Permissão ao Trocar de Account

## Problema

Quando você troca de account no Google Ads, recebe o erro:

```
403 PERMISSION_DENIED
"User doesn't have permission to access customer"
```

### Causa Raiz

O sistema estava salvando o `login_customer_id` incorretamente. Quando você selecionava uma nova conta, o sistema atualizava o `login_customer_id` para o `customer_id` selecionado. Isso causava conflitos porque:

1. **Requisição enviada:**
   - URL: `/customers/7986774301/googleAds:search`
   - Header `login-customer-id: 6766097246`

2. **Problema:**
   - O Google Ads API não permite acessar `7986774301` com `login-customer-id: 6766097246`
   - O `login-customer-id` deve ser a **conta gerenciadora** (manager account)
   - O `customer_id` na URL deve ser a **conta cliente** que você quer acessar

## Solução Implementada

### 1. Novo Campo: `manager_customer_id`

Adicionado um novo campo `manager_customer_id` na tabela `google_accounts`:

```ruby
# db/migrate/20260210140000_add_manager_customer_id_to_google_accounts.rb
add_column :google_accounts, :manager_customer_id, :string
```

**Propósito:**
- Rastreia a conta **raiz** (root manager account)
- Nunca deve ser alterado após a conexão inicial
- É definido UMA VEZ quando o usuário conecta pela primeira vez

### 2. Fluxo Corrigido

#### Conexão Inicial (Primeira Vez)
```
1. Usuário clica "Conectar Google Ads"
2. OAuth retorna refresh_token
3. Sistema busca contas acessíveis
4. Usuário seleciona uma conta
5. Sistema salva:
   - manager_customer_id = conta selecionada (NUNCA MUDA)
   - login_customer_id = conta selecionada (pode mudar)
   - customer_id em ActiveCustomerSelection = conta selecionada
```

#### Trocar de Account (Depois)
```
1. Usuário seleciona outra conta
2. Sistema atualiza APENAS:
   - customer_id em ActiveCustomerSelection = nova conta
3. Mantém:
   - manager_customer_id = original (NUNCA MUDA)
   - login_customer_id = original (ou pode ser atualizado se necessário)
```

### 3. Novo Endpoint: `switch_customer`

Adicionado novo endpoint para trocar de account sem alterar `login_customer_id`:

```ruby
POST /google_ads/auth/switch_customer
Parameters:
  - google_account_id: ID da conta Google
  - customer_id: ID do cliente para trocar
```

**Resposta:**
```json
{
  "success": true,
  "customer_id": "7986774301",
  "display_name": "Meu Negócio"
}
```

### 4. Rake Tasks para Manutenção

#### Corrigir Contas Existentes
```bash
rails google_accounts:fix_login_customer_ids
```

Isso vai:
1. Encontrar todas as contas sem `manager_customer_id`
2. Definir `manager_customer_id` para a primeira conta acessível
3. Garantir que `login_customer_id` está definido

#### Verificar Configuração
```bash
rails google_accounts:verify_configuration
```

Mostra o status de todas as contas e seleções ativas.

## Mudanças no Código

### 1. Controller: `GoogleAds::ConnectionsController`

**Antes:**
```ruby
# ❌ Atualizava login_customer_id toda vez
google_account.update!(login_customer_id: selected_customer_id)
```

**Depois:**
```ruby
# ✅ Define manager_customer_id UMA VEZ
unless google_account.manager_customer_id.present?
  google_account.update!(
    manager_customer_id: selected_customer_id,
    login_customer_id: selected_customer_id
  )
end
```

### 2. Novo Método: `switch_customer`

Permite trocar de account sem alterar `login_customer_id`:

```ruby
def switch_customer
  # Valida parâmetros
  # Verifica se customer_id é acessível
  # Atualiza APENAS customer_id em ActiveCustomerSelection
  # Retorna JSON com sucesso
end
```

### 3. Rota Adicionada

```ruby
post "auth/switch_customer", to: "connections#switch_customer"
```

## Como Usar

### Para Usuários Finais

1. **Primeira conexão:** Funciona normalmente
2. **Trocar de account:** Use o novo endpoint `switch_customer` em vez de `save_account_selection`

### Para Desenvolvedores

1. **Executar migração:**
   ```bash
   rails db:migrate
   ```

2. **Corrigir contas existentes:**
   ```bash
   rails google_accounts:fix_login_customer_ids
   ```

3. **Verificar status:**
   ```bash
   rails google_accounts:verify_configuration
   ```

## Estrutura de Dados

### Antes (Incorreto)
```
GoogleAccount:
  - login_customer_id: "7986774301" (muda quando troca de account) ❌
  - refresh_token: "xyz..."

ActiveCustomerSelection:
  - customer_id: "7986774301"
```

### Depois (Correto)
```
GoogleAccount:
  - manager_customer_id: "7986774301" (nunca muda) ✅
  - login_customer_id: "7986774301" (pode mudar se necessário)
  - refresh_token: "xyz..."

ActiveCustomerSelection:
  - customer_id: "7986774301" (muda quando troca de account) ✅
```

## Requisição Google Ads API

### Antes (Erro 403)
```
POST https://googleads.googleapis.com/v22/customers/7986774301/googleAds:search
Headers:
  Authorization: Bearer {access_token}
  developer-token: {token}
  login-customer-id: 6766097246  ❌ Incorreto!
```

### Depois (Sucesso 200)
```
POST https://googleads.googleapis.com/v22/customers/7986774301/googleAds:search
Headers:
  Authorization: Bearer {access_token}
  developer-token: {token}
  login-customer-id: 7986774301  ✅ Correto!
```

## Testes

Para testar a solução:

1. **Conectar primeira conta:**
   ```
   GET /google_ads/auth/start
   → OAuth flow
   → Selecionar conta
   → POST /google_ads/auth/select
   ```

2. **Trocar de account:**
   ```
   POST /google_ads/auth/switch_customer
   {
     "google_account_id": 1,
     "customer_id": "9876543210"
   }
   ```

3. **Verificar campanhas:**
   ```
   GET /api/google_ads/campaigns
   → Deve retornar campanhas da nova conta
   ```

## Notas Importantes

1. **manager_customer_id é imutável:** Uma vez definido, nunca deve ser alterado
2. **login_customer_id pode ser atualizado:** Se necessário para requisições específicas
3. **customer_id muda frequentemente:** Toda vez que o usuário troca de account
4. **Contas existentes:** Execute `rails google_accounts:fix_login_customer_ids` para corrigir

## Referências

- [Google Ads API - Authentication](https://developers.google.com/google-ads/api/docs/client-libs/ruby/authentication)
- [Google Ads API - Manager Accounts](https://developers.google.com/google-ads/api/docs/concepts/managing-accounts)
- [Google Ads API - login-customer-id Header](https://developers.google.com/google-ads/api/docs/client-libs/ruby/headers)
