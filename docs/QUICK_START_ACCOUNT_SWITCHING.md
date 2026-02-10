# Quick Start: Implementar Solução de Account Switching

## ⚡ 5 Minutos para Implementar

### 1️⃣ Executar Migração (1 min)
```bash
rails db:migrate
```

### 2️⃣ Corrigir Contas Existentes (1 min)
```bash
rails google_accounts:fix_login_customer_ids
```

### 3️⃣ Verificar Configuração (1 min)
```bash
rails google_accounts:verify_configuration
```

### 4️⃣ Testar (2 min)
1. Conectar conta Google Ads
2. Trocar de account
3. Verificar se campanhas carregam

## 📁 Arquivos Modificados

```
✅ db/migrate/20260210140000_add_manager_customer_id_to_google_accounts.rb (novo)
✅ app/models/google_account.rb (modificado)
✅ app/controllers/google_ads/connections_controller.rb (modificado)
✅ config/routes.rb (modificado)
✅ lib/tasks/fix_google_accounts.rake (novo)
```

## 🔧 Comandos Úteis

### Corrigir Contas
```bash
rails google_accounts:fix_login_customer_ids
```

### Verificar Status
```bash
rails google_accounts:verify_configuration
```

### Ver Contas no Console
```bash
rails console
GoogleAccount.all.map { |a| { id: a.id, manager: a.manager_customer_id, login: a.login_customer_id } }
```

### Ver Seleção Ativa
```bash
rails console
user = User.find(1)
selection = user.active_customer_selection
puts "Customer: #{selection.customer_id}, Account: #{selection.google_account_id}"
```

## 🧪 Testes Rápidos

### Teste 1: Conexão
1. Ir para `/dashboard`
2. Clicar "Conectar Google Ads"
3. Fazer OAuth
4. Selecionar conta
5. ✅ Deve redirecionar para `/leads`

### Teste 2: Trocar de Account
```javascript
// No console do navegador
fetch('/google_ads/auth/switch_customer', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
  },
  body: JSON.stringify({
    google_account_id: 1,
    customer_id: '9876543210'
  })
})
.then(r => r.json())
.then(d => console.log(d))
```

### Teste 3: Campanhas
1. Ir para `/leads` ou `/dashboard/campaigns`
2. ✅ Campanhas devem carregar sem erro 403

## 📊 Antes vs Depois

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Erro ao trocar | 403 ❌ | Nenhum ✅ |
| manager_customer_id | Não existe | Definido ✅ |
| login_customer_id | Muda | Permanece ✅ |
| Endpoint | save_account_selection | switch_customer ✅ |

## 🚨 Se Algo Der Errado

### Erro: "User doesn't have permission"
```bash
rails google_accounts:fix_login_customer_ids
```

### Erro: "manager_customer_id is nil"
```bash
rails console
account = GoogleAccount.find(1)
account.ensure_manager_customer_id!
```

### Ver Logs
```bash
tail -f log/development.log | grep "GoogleAds"
```

## 📚 Documentação Completa

- **SOLUCAO_PERMISSAO_ACCOUNT_SWITCHING.md** - Explicação detalhada
- **IMPLEMENTACAO_SOLUCAO_PERMISSAO.md** - Guia passo a passo
- **DIAGRAMA_FLUXO_ACCOUNT_SWITCHING.md** - Diagramas visuais
- **GUIA_TESTES_ACCOUNT_SWITCHING.md** - Testes completos
- **RESUMO_EXECUTIVO_SOLUCAO.md** - Resumo executivo

## ✅ Checklist

- [ ] Migração executada
- [ ] Contas corrigidas
- [ ] Configuração verificada
- [ ] Teste 1 passou
- [ ] Teste 2 passou
- [ ] Teste 3 passou
- [ ] Logs verificados
- [ ] Pronto para deploy

## 🎯 Próximos Passos

1. ✅ Implementar (5 min)
2. ✅ Testar (15 min)
3. ✅ Deploy (5 min)
4. ✅ Monitorar (24h)

**Total: ~30 minutos**

---

**Dúvidas?** Consulte a documentação completa ou os guias de troubleshooting.
