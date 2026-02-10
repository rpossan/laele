# Guia de Testes: Account Switching

## 🧪 Testes Manuais

### Teste 1: Conexão Inicial

**Objetivo:** Verificar se a primeira conexão funciona corretamente

**Passos:**
1. Abrir navegador em `http://localhost:3000/dashboard`
2. Clicar em "Conectar Google Ads"
3. Fazer login no Google
4. Selecionar uma conta
5. Clicar "Confirmar seleção"

**Verificações:**
- [ ] Redireciona para `/leads`
- [ ] Mostra mensagem "Conta Google Ads conectada com sucesso!"
- [ ] Campanhas carregam na página

**Verificar no banco:**
```bash
rails console
account = GoogleAccount.first
puts "Manager ID: #{account.manager_customer_id}"
puts "Login ID: #{account.login_customer_id}"
puts "Refresh Token: #{account.refresh_token.present?}"
```

**Resultado esperado:**
```
Manager ID: 7986774301
Login ID: 7986774301
Refresh Token: true
```

---

### Teste 2: Trocar de Account (Novo Endpoint)

**Objetivo:** Verificar se trocar de account funciona sem alterar `login_customer_id`

**Pré-requisitos:**
- Ter uma conta conectada com múltiplas clientes acessíveis
- Ter pelo menos 2 contas em `accessible_customers`

**Passos:**
1. Abrir console do navegador (F12)
2. Executar:
```javascript
fetch('/google_ads/auth/switch_customer', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
  },
  body: JSON.stringify({
    google_account_id: 1,
    customer_id: '9876543210'  // ID de outra conta
  })
})
.then(r => r.json())
.then(d => console.log(d))
```

**Resultado esperado:**
```json
{
  "success": true,
  "customer_id": "9876543210",
  "display_name": "Outro Negócio"
}
```

**Verificar no banco:**
```bash
rails console
selection = User.first.active_customer_selection
account = selection.google_account
puts "Selected Customer: #{selection.customer_id}"
puts "Manager ID: #{account.manager_customer_id}"
puts "Login ID: #{account.login_customer_id}"
```

**Resultado esperado:**
```
Selected Customer: 9876543210
Manager ID: 7986774301  ← NÃO MUDOU ✅
Login ID: 7986774301    ← NÃO MUDOU ✅
```

---

### Teste 3: Campanhas Carregam Corretamente

**Objetivo:** Verificar se as campanhas da nova conta carregam

**Passos:**
1. Após trocar de account (Teste 2)
2. Ir para `/leads` ou `/dashboard/campaigns`
3. Verificar se campanhas carregam

**Verificações:**
- [ ] Campanhas carregam sem erro
- [ ] Não há erro 403 nos logs
- [ ] Status da requisição é 200

**Verificar nos logs:**
```bash
tail -f log/development.log | grep "GoogleAds::CampaignService"
```

**Resultado esperado:**
```
[GoogleAds::CampaignService] Customer ID: 9876543210
[GoogleAds::CampaignService] Login Customer ID: 7986774301
[GoogleAds::CampaignService] Response status: 200
[GoogleAds::CampaignService] Found 3 LSA campaigns
```

---

### Teste 4: Corrigir Contas Existentes

**Objetivo:** Verificar se o rake task corrige contas antigas

**Passos:**
1. Abrir terminal
2. Executar:
```bash
rails google_accounts:fix_login_customer_ids
```

**Resultado esperado:**
```
🔧 Fixing Google Accounts login_customer_id...
✅ Fixed account 1: manager_customer_id = 7986774301
✅ Fixed account 2: manager_customer_id = 9876543210

📊 Summary:
  Fixed: 2
  Errors: 0
```

---

### Teste 5: Verificar Configuração

**Objetivo:** Verificar se todas as contas estão configuradas corretamente

**Passos:**
1. Abrir terminal
2. Executar:
```bash
rails google_accounts:verify_configuration
```

**Resultado esperado:**
```
🔍 Verifying Google Accounts configuration...

User: user@example.com
  Account ID: 1
  Manager Customer ID: 7986774301
  Login Customer ID: 7986774301
  Accessible Customers: 3
  Active Selection:
    Customer ID: 9876543210
    Google Account ID: 1
```

---

## 🔍 Testes de Integração

### Teste 6: Fluxo Completo

**Objetivo:** Testar o fluxo completo de conexão e troca de account

**Passos:**
1. Limpar dados (opcional):
```bash
rails console
User.first.google_accounts.destroy_all
```

2. Conectar primeira conta (Teste 1)
3. Trocar de account (Teste 2)
4. Verificar campanhas (Teste 3)
5. Verificar configuração (Teste 5)

**Verificações:**
- [ ] Todas as etapas funcionam
- [ ] Sem erros 403
- [ ] `manager_customer_id` nunca muda
- [ ] `customer_id` muda quando troca

---

### Teste 7: Múltiplas Contas Google

**Objetivo:** Testar com múltiplas contas Google conectadas

**Pré-requisitos:**
- Ter múltiplas contas Google Ads

**Passos:**
1. Conectar primeira conta Google
2. Clicar "Conectar outra conta Google"
3. Fazer OAuth com outra conta Google
4. Selecionar uma conta
5. Trocar entre as contas

**Verificações:**
- [ ] Cada conta tem seu próprio `manager_customer_id`
- [ ] Trocar entre contas funciona
- [ ] Campanhas corretas carregam para cada conta

---

## 📊 Testes de Banco de Dados

### Teste 8: Integridade de Dados

**Objetivo:** Verificar se os dados estão corretos no banco

```bash
rails console

# Verificar todas as contas
GoogleAccount.all.each do |a|
  puts "Account #{a.id}:"
  puts "  Manager: #{a.manager_customer_id}"
  puts "  Login: #{a.login_customer_id}"
  puts "  Accessible: #{a.accessible_customers.count}"
end

# Verificar seleções ativas
ActiveCustomerSelection.all.each do |s|
  puts "Selection #{s.id}:"
  puts "  User: #{s.user.email}"
  puts "  Customer: #{s.customer_id}"
  puts "  Account: #{s.google_account_id}"
end

# Verificar contas acessíveis
AccessibleCustomer.all.each do |c|
  puts "Accessible #{c.id}:"
  puts "  Account: #{c.google_account_id}"
  puts "  Customer: #{c.customer_id}"
  puts "  Name: #{c.display_name}"
end
```

---

## 🐛 Testes de Erro

### Teste 9: Erro 403 (Antes da Correção)

**Objetivo:** Reproduzir o erro original (para verificar que foi corrigido)

**Passos:**
1. Verificar logs de uma requisição antiga
2. Procurar por:
```
[GoogleAds::CampaignService] Response status: 403
[GoogleAds::CampaignService] REST API error: 403
"User doesn't have permission"
```

**Resultado esperado:**
- Não deve haver mais erros 403
- Todas as requisições devem retornar 200

---

### Teste 10: Validação de Parâmetros

**Objetivo:** Testar validação do endpoint `switch_customer`

**Teste 10a: Parâmetros inválidos**
```javascript
fetch('/google_ads/auth/switch_customer', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
  },
  body: JSON.stringify({
    google_account_id: null,
    customer_id: null
  })
})
.then(r => r.json())
.then(d => console.log(d))
```

**Resultado esperado:**
```json
{
  "error": "Parâmetros inválidos"
}
```

**Teste 10b: Customer não acessível**
```javascript
fetch('/google_ads/auth/switch_customer', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
  },
  body: JSON.stringify({
    google_account_id: 1,
    customer_id: '9999999999'  // ID que não existe
  })
})
.then(r => r.json())
.then(d => console.log(d))
```

**Resultado esperado:**
```json
{
  "error": "Conta não acessível"
}
```

---

## 📈 Testes de Performance

### Teste 11: Tempo de Resposta

**Objetivo:** Verificar se o novo endpoint é rápido

**Passos:**
1. Abrir DevTools (F12)
2. Ir para aba "Network"
3. Executar `switch_customer`
4. Verificar tempo de resposta

**Resultado esperado:**
- Tempo de resposta < 500ms
- Sem requisições bloqueantes

---

## ✅ Checklist de Testes

- [ ] Teste 1: Conexão Inicial
- [ ] Teste 2: Trocar de Account
- [ ] Teste 3: Campanhas Carregam
- [ ] Teste 4: Corrigir Contas Existentes
- [ ] Teste 5: Verificar Configuração
- [ ] Teste 6: Fluxo Completo
- [ ] Teste 7: Múltiplas Contas Google
- [ ] Teste 8: Integridade de Dados
- [ ] Teste 9: Erro 403 (Corrigido)
- [ ] Teste 10: Validação de Parâmetros
- [ ] Teste 11: Performance

---

## 🚀 Testes em Produção

### Antes de Deploy

1. **Executar migração:**
```bash
rails db:migrate RAILS_ENV=production
```

2. **Corrigir contas existentes:**
```bash
rails google_accounts:fix_login_customer_ids RAILS_ENV=production
```

3. **Verificar configuração:**
```bash
rails google_accounts:verify_configuration RAILS_ENV=production
```

4. **Testar com usuários reais:**
   - Pedir para alguns usuários testarem
   - Monitorar logs de erro
   - Verificar se campanhas carregam

5. **Monitorar por 24 horas:**
   - Verificar se há erros 403
   - Verificar performance
   - Verificar se usuários conseguem trocar de account

---

## 📝 Notas

- Todos os testes devem passar antes de fazer deploy
- Se algum teste falhar, verificar logs e corrigir
- Manter este guia atualizado com novos testes
- Documentar qualquer problema encontrado

---

## 🆘 Troubleshooting

### Problema: Erro 403 ainda aparece

**Solução:**
1. Executar `rails google_accounts:fix_login_customer_ids`
2. Verificar se `manager_customer_id` está definido
3. Verificar logs de requisição

### Problema: Campanhas não carregam

**Solução:**
1. Verificar se `customer_id` está correto
2. Verificar se `login_customer_id` está correto
3. Verificar se refresh_token é válido
4. Verificar logs de erro

### Problema: Trocar de account não funciona

**Solução:**
1. Verificar se `google_account_id` está correto
2. Verificar se `customer_id` é acessível
3. Verificar se há erro de validação
4. Verificar logs de erro
