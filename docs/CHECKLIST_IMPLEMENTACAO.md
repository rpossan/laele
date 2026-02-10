# Checklist de Implementação: Account Switching

## ✅ Pré-Implementação

- [ ] Ler QUICK_START_ACCOUNT_SWITCHING.md
- [ ] Ler RESUMO_EXECUTIVO_SOLUCAO.md
- [ ] Entender o problema e a solução
- [ ] Fazer backup do banco de dados
- [ ] Criar branch git: `git checkout -b fix/account-switching-permission`

## ✅ Implementação

### Passo 1: Migração
- [ ] Executar: `rails db:migrate`
- [ ] Verificar se coluna `manager_customer_id` foi criada
- [ ] Verificar índice foi criado

**Verificação:**
```bash
rails console
GoogleAccount.column_names.include?('manager_customer_id')
# Deve retornar: true
```

### Passo 2: Corrigir Contas Existentes
- [ ] Executar: `rails google_accounts:fix_login_customer_ids`
- [ ] Verificar saída do comando
- [ ] Confirmar que todas as contas foram corrigidas

**Verificação:**
```bash
rails console
GoogleAccount.where(manager_customer_id: nil).count
# Deve retornar: 0
```

### Passo 3: Verificar Configuração
- [ ] Executar: `rails google_accounts:verify_configuration`
- [ ] Verificar que todas as contas têm `manager_customer_id`
- [ ] Verificar que `login_customer_id` está definido

**Verificação:**
```bash
rails console
GoogleAccount.all.each do |a|
  puts "Account #{a.id}: manager=#{a.manager_customer_id}, login=#{a.login_customer_id}"
end
```

## ✅ Testes Locais

### Teste 1: Conexão Inicial
- [ ] Abrir `http://localhost:3000/dashboard`
- [ ] Clicar "Conectar Google Ads"
- [ ] Fazer OAuth com conta Google
- [ ] Selecionar uma conta
- [ ] Clicar "Confirmar seleção"
- [ ] Verificar redirecionamento para `/leads`
- [ ] Verificar se campanhas carregam

**Verificação nos logs:**
```
[GoogleAds::CampaignService] Response status: 200
[GoogleAds::CampaignService] Found X LSA campaigns
```

### Teste 2: Trocar de Account
- [ ] Abrir console do navegador (F12)
- [ ] Executar comando `switch_customer`
- [ ] Verificar resposta JSON com sucesso
- [ ] Ir para `/leads`
- [ ] Verificar se campanhas da nova conta carregam

**Verificação nos logs:**
```
[GoogleAds::ConnectionsController] Switched to customer 9876543210
[GoogleAds::CampaignService] Response status: 200
```

### Teste 3: Verificar Dados
- [ ] Executar `rails google_accounts:verify_configuration`
- [ ] Verificar que `manager_customer_id` não mudou
- [ ] Verificar que `login_customer_id` não mudou
- [ ] Verificar que `customer_id` mudou

**Verificação:**
```
Manager Customer ID: 7986774301 (não mudou)
Login Customer ID: 7986774301 (não mudou)
Active Selection Customer ID: 9876543210 (mudou)
```

### Teste 4: Múltiplas Trocas
- [ ] Trocar de account 3-4 vezes
- [ ] Verificar se campanhas carregam cada vez
- [ ] Verificar se não há erro 403
- [ ] Verificar se `manager_customer_id` permanece igual

## ✅ Testes de Integração

### Teste 5: Fluxo Completo
- [ ] Limpar dados (opcional): `User.first.google_accounts.destroy_all`
- [ ] Conectar primeira conta
- [ ] Trocar de account
- [ ] Verificar campanhas
- [ ] Verificar configuração
- [ ] Tudo deve funcionar sem erros

### Teste 6: Múltiplas Contas Google
- [ ] Conectar segunda conta Google (se disponível)
- [ ] Trocar entre contas
- [ ] Verificar se cada conta tem seu próprio `manager_customer_id`
- [ ] Verificar se campanhas corretas carregam

### Teste 7: Erro Handling
- [ ] Tentar trocar para customer_id inválido
- [ ] Verificar se retorna erro apropriado
- [ ] Tentar com parâmetros inválidos
- [ ] Verificar se retorna erro apropriado

## ✅ Verificação de Código

- [ ] Verificar se não há erros de sintaxe
```bash
rails console
# Deve carregar sem erros
```

- [ ] Verificar se migrations estão corretas
```bash
rails db:migrate:status
# Deve mostrar todas as migrations como "up"
```

- [ ] Verificar se rotas estão corretas
```bash
rails routes | grep switch_customer
# Deve mostrar: POST /google_ads/auth/switch_customer
```

## ✅ Verificação de Banco de Dados

- [ ] Coluna `manager_customer_id` existe
```bash
rails console
GoogleAccount.column_names.include?('manager_customer_id')
```

- [ ] Índice foi criado
```bash
rails console
GoogleAccount.connection.indexes(:google_accounts).map(&:name)
```

- [ ] Dados estão corretos
```bash
rails console
GoogleAccount.all.each do |a|
  puts "#{a.id}: manager=#{a.manager_customer_id}, login=#{a.login_customer_id}"
end
```

## ✅ Verificação de Logs

- [ ] Verificar se não há erros 403
```bash
grep "403" log/development.log
# Não deve retornar nada
```

- [ ] Verificar se requisições retornam 200
```bash
grep "Response status: 200" log/development.log
# Deve retornar múltiplas linhas
```

- [ ] Verificar se não há exceções
```bash
grep "ERROR" log/development.log
# Não deve retornar nada relacionado a Google Ads
```

## ✅ Preparação para Deploy

### Staging
- [ ] Fazer deploy em staging
- [ ] Executar testes em staging
- [ ] Verificar logs em staging
- [ ] Pedir para QA testar em staging

### Produção
- [ ] Fazer backup do banco de dados
- [ ] Fazer deploy em produção
- [ ] Executar migração em produção
- [ ] Executar rake task em produção
- [ ] Verificar logs em produção
- [ ] Monitorar por 24 horas

## ✅ Pós-Deploy

### Imediato (Primeira Hora)
- [ ] Verificar se não há erros 403
- [ ] Verificar se campanhas carregam
- [ ] Verificar se trocar de account funciona
- [ ] Monitorar logs de erro

### Curto Prazo (Primeiras 24 Horas)
- [ ] Monitorar performance
- [ ] Verificar se usuários conseguem usar
- [ ] Coletar feedback
- [ ] Corrigir qualquer problema

### Longo Prazo (Próximas Semanas)
- [ ] Documentar no wiki
- [ ] Treinar time
- [ ] Monitorar performance
- [ ] Fazer retrospectiva

## ✅ Rollback (Se Necessário)

Se algo der errado:

1. [ ] Reverter código: `git revert <commit>`
2. [ ] Reverter migração: `rails db:rollback`
3. [ ] Verificar se tudo volta ao normal
4. [ ] Investigar o problema
5. [ ] Corrigir e tentar novamente

**Comando:**
```bash
git revert <commit>
rails db:rollback
```

## ✅ Documentação

- [ ] Atualizar README.md
- [ ] Atualizar wiki
- [ ] Documentar mudanças no CHANGELOG
- [ ] Compartilhar com o time

## ✅ Comunicação

- [ ] Informar o time sobre a mudança
- [ ] Compartilhar documentação
- [ ] Oferecer treinamento
- [ ] Coletar feedback

## 📊 Resumo

| Etapa | Status | Tempo |
|-------|--------|-------|
| Pré-Implementação | ⏳ | 10 min |
| Implementação | ⏳ | 5 min |
| Testes Locais | ⏳ | 30 min |
| Testes de Integração | ⏳ | 20 min |
| Verificação | ⏳ | 10 min |
| Deploy | ⏳ | 10 min |
| Monitoramento | ⏳ | 24h |
| **Total** | ⏳ | ~1.5h |

## 🎯 Critérios de Sucesso

- ✅ Sem erro 403 ao trocar de account
- ✅ Campanhas carregam corretamente
- ✅ `manager_customer_id` nunca muda
- ✅ `login_customer_id` permanece igual
- ✅ Sem impacto em performance
- ✅ Sem impacto em outros recursos
- ✅ Usuários conseguem usar normalmente

## 🚨 Pontos de Atenção

- ⚠️ Fazer backup antes de migração
- ⚠️ Testar em staging antes de produção
- ⚠️ Monitorar logs após deploy
- ⚠️ Ter plano de rollback pronto
- ⚠️ Comunicar com o time
- ⚠️ Coletar feedback dos usuários

## 📝 Notas

```
Data de Implementação: _______________
Responsável: _______________
Versão: _______________
Observações: _______________
```

---

**Checklist Completo:** ✅ Pronto para Implementação
