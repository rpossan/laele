# Implementação da Solução: Erro de Permissão ao Trocar de Account

## 📋 Resumo das Mudanças

### 1. Migração de Banco de Dados
- **Arquivo:** `db/migrate/20260210140000_add_manager_customer_id_to_google_accounts.rb`
- **O quê:** Adiciona coluna `manager_customer_id` à tabela `google_accounts`
- **Por quê:** Rastrear a conta manager original que nunca deve mudar

### 2. Modelo GoogleAccount
- **Arquivo:** `app/models/google_account.rb`
- **Mudanças:**
  - Adicionado método `manager_customer_id_formatted` para formatação
  - Adicionado método `ensure_manager_customer_id!` para garantir que está definido

### 3. Controller GoogleAds::ConnectionsController
- **Arquivo:** `app/controllers/google_ads/connections_controller.rb`
- **Mudanças:**
  - Método `save_account_selection`: Agora define `manager_customer_id` UMA VEZ
  - Novo método `switch_customer`: Permite trocar de account sem alterar `login_customer_id`

### 4. Rotas
- **Arquivo:** `config/routes.rb`
- **Mudanças:**
  - Adicionada rota `POST /google_ads/auth/switch_customer`

### 5. Rake Tasks
- **Arquivo:** `lib/tasks/fix_google_accounts.rake`
- **Tasks:**
  - `rails google_accounts:fix_login_customer_ids` - Corrige contas existentes
  - `rails google_accounts:verify_configuration` - Verifica status

## 🚀 Passos para Implementar

### Passo 1: Executar Migração
```bash
rails db:migrate
```

Isso vai criar a coluna `manager_customer_id` na tabela `google_accounts`.

### Passo 2: Corrigir Contas Existentes
```bash
rails google_accounts:fix_login_customer_ids
```

Isso vai:
1. Encontrar todas as contas sem `manager_customer_id`
2. Definir `manager_customer_id` para a primeira conta acessível
3. Garantir que `login_customer_id` está definido

**Saída esperada:**
```
🔧 Fixing Google Accounts login_customer_id...
✅ Fixed account 1: manager_customer_id = 7986774301
✅ Fixed account 2: manager_customer_id = 9876543210

📊 Summary:
  Fixed: 2
  Errors: 0
```

### Passo 3: Verificar Configuração
```bash
rails google_accounts:verify_configuration
```

**Saída esperada:**
```
🔍 Verifying Google Accounts configuration...

User: user@example.com
  Account ID: 1
  Manager Customer ID: 7986774301
  Login Customer ID: 7986774301
  Accessible Customers: 3
  Active Selection:
    Customer ID: 7986774301
    Google Account ID: 1
```

### Passo 4: Testar a Solução

#### Teste 1: Conectar Primeira Conta
1. Ir para Dashboard
2. Clicar "Conectar Google Ads"
3. Fazer OAuth
4. Selecionar uma conta
5. Verificar se campanhas carregam

#### Teste 2: Trocar de Account
1. Ir para Dashboard
2. Selecionar outra conta (se disponível)
3. Verificar se campanhas da nova conta carregam
4. Verificar se `login_customer_id` não mudou (via `verify_configuration`)

#### Teste 3: Verificar Logs
```bash
# Ver logs de requisição
tail -f log/development.log | grep "GoogleAds::CampaignService"
```

Procure por:
```
[GoogleAds::CampaignService] Customer ID: 7986774301
[GoogleAds::CampaignService] Login Customer ID: 7986774301
[GoogleAds::CampaignService] Response status: 200
```

## 🔍 Verificação Pós-Implementação

### Checklist
- [ ] Migração executada com sucesso
- [ ] Contas existentes corrigidas
- [ ] Configuração verificada
- [ ] Primeira conexão funciona
- [ ] Trocar de account funciona
- [ ] Campanhas carregam corretamente
- [ ] Logs mostram status 200 (não 403)

### Comandos de Verificação

**Ver todas as contas:**
```bash
rails console
GoogleAccount.all.map { |a| { id: a.id, manager: a.manager_customer_id, login: a.login_customer_id } }
```

**Ver seleção ativa de um usuário:**
```bash
rails console
user = User.find(1)
selection = user.active_customer_selection
puts "Customer: #{selection.customer_id}, Account: #{selection.google_account_id}"
```

**Ver contas acessíveis:**
```bash
rails console
account = GoogleAccount.find(1)
account.accessible_customers.map { |c| { id: c.customer_id, name: c.display_name } }
```

## 📝 Notas Importantes

1. **manager_customer_id é imutável:**
   - Uma vez definido, nunca deve ser alterado
   - Representa a conta manager original

2. **login_customer_id pode variar:**
   - Pode ser atualizado se necessário
   - Geralmente é igual a manager_customer_id

3. **customer_id muda frequentemente:**
   - Muda toda vez que o usuário troca de account
   - Armazenado em ActiveCustomerSelection

4. **Contas antigas:**
   - Se tiver contas criadas antes dessa mudança, execute `fix_login_customer_ids`
   - Isso vai garantir que estão configuradas corretamente

## 🐛 Troubleshooting

### Erro: "User doesn't have permission to access customer"
**Causa:** `login_customer_id` está incorreto
**Solução:** Execute `rails google_accounts:fix_login_customer_ids`

### Erro: "manager_customer_id is nil"
**Causa:** Conta não tem contas acessíveis
**Solução:** Verifique se a conta Google Ads está configurada corretamente no Google

### Campanhas não carregam
**Causa:** Múltiplas possíveis
**Solução:**
1. Verifique logs: `tail -f log/development.log`
2. Execute `verify_configuration`
3. Verifique se `login_customer_id` está correto

## 📚 Referências

- [SOLUCAO_PERMISSAO_ACCOUNT_SWITCHING.md](./SOLUCAO_PERMISSAO_ACCOUNT_SWITCHING.md) - Explicação detalhada do problema e solução
- [Google Ads API Docs](https://developers.google.com/google-ads/api/docs)
- [Manager Accounts](https://developers.google.com/google-ads/api/docs/concepts/managing-accounts)

## ✅ Conclusão

Após seguir esses passos, o erro de permissão ao trocar de account deve ser resolvido. O sistema agora:

1. ✅ Mantém `manager_customer_id` imutável
2. ✅ Permite trocar de account sem alterar `login_customer_id`
3. ✅ Envia headers corretos para Google Ads API
4. ✅ Retorna status 200 em vez de 403
