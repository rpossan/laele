# Diagrama de Fluxo: Account Switching Corrigido

## 1. Fluxo de Conexão Inicial

```
┌─────────────────────────────────────────────────────────────┐
│ USUÁRIO CONECTA GOOGLE ADS PELA PRIMEIRA VEZ               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ GET /google_ads/auth/start            │
        │ Inicia OAuth flow                     │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Google OAuth Authorization            │
        │ Usuário faz login no Google           │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ GET /google_ads/auth/callback         │
        │ Recebe authorization code             │
        │ Troca por refresh_token               │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Busca contas acessíveis               │
        │ list_accessible_customers()           │
        │ Retorna: [7986774301, 9876543210]    │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ GET /google_ads/auth/select           │
        │ Mostra formulário de seleção          │
        │ Usuário escolhe uma conta             │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ POST /google_ads/auth/select          │
        │ save_account_selection()              │
        │ Parâmetro: login_customer_id=7986... │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ SALVA NO BANCO:                    │
        │                                       │
        │ GoogleAccount:                        │
        │  - manager_customer_id: 7986774301   │
        │  - login_customer_id: 7986774301     │
        │  - refresh_token: xyz...             │
        │                                       │
        │ ActiveCustomerSelection:              │
        │  - customer_id: 7986774301           │
        │  - google_account_id: 1              │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ SUCESSO!                           │
        │ Redireciona para /leads               │
        └───────────────────────────────────────┘
```

## 2. Fluxo de Trocar de Account (Novo)

```
┌─────────────────────────────────────────────────────────────┐
│ USUÁRIO TROCA DE ACCOUNT                                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ POST /google_ads/auth/switch_customer │
        │ Parâmetros:                           │
        │  - google_account_id: 1               │
        │  - customer_id: 9876543210            │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Valida parâmetros                     │
        │ Verifica se customer_id é acessível  │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ ATUALIZA APENAS:                   │
        │                                       │
        │ ActiveCustomerSelection:              │
        │  - customer_id: 9876543210 ← NOVO    │
        │  - google_account_id: 1 (sem mudança)│
        │                                       │
        │ GoogleAccount (SEM MUDANÇA):          │
        │  - manager_customer_id: 7986774301   │
        │  - login_customer_id: 7986774301     │
        │  - refresh_token: xyz...             │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Retorna JSON:                         │
        │ {                                     │
        │   "success": true,                    │
        │   "customer_id": "9876543210",        │
        │   "display_name": "Outro Negócio"     │
        │ }                                     │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ SUCESSO!                           │
        │ Próximas requisições usam novo ID    │
        └───────────────────────────────────────┘
```

## 3. Fluxo de Requisição para Google Ads API

### Antes (❌ Erro 403)

```
┌─────────────────────────────────────────────────────────────┐
│ GET /api/google_ads/campaigns                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ CampaignService.new(                  │
        │   google_account: account,            │
        │   customer_id: 7986774301             │
        │ )                                     │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Busca access_token                    │
        │ Constrói requisição REST              │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ❌ REQUISIÇÃO INCORRETA:              │
        │                                       │
        │ POST /v22/customers/7986774301/...   │
        │ Headers:                              │
        │  Authorization: Bearer {token}        │
        │  developer-token: {token}             │
        │  login-customer-id: 6766097246 ❌    │
        │                                       │
        │ Problema: login-customer-id está     │
        │ diferente do customer_id na URL      │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ❌ RESPOSTA: 403 PERMISSION_DENIED    │
        │ "User doesn't have permission to      │
        │  access customer"                     │
        └───────────────────────────────────────┘
```

### Depois (✅ Sucesso 200)

```
┌─────────────────────────────────────────────────────────────┐
│ GET /api/google_ads/campaigns                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ CampaignService.new(                  │
        │   google_account: account,            │
        │   customer_id: 7986774301             │
        │ )                                     │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ Busca access_token                    │
        │ Constrói requisição REST              │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ REQUISIÇÃO CORRETA:                │
        │                                       │
        │ POST /v22/customers/7986774301/...   │
        │ Headers:                              │
        │  Authorization: Bearer {token}        │
        │  developer-token: {token}             │
        │  login-customer-id: 7986774301 ✅    │
        │                                       │
        │ Correto: login-customer-id =          │
        │ customer_id na URL                    │
        └───────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │ ✅ RESPOSTA: 200 OK                   │
        │ Retorna campanhas LSA                 │
        │ [                                     │
        │   { id: "123", name: "Campaign 1" }, │
        │   { id: "456", name: "Campaign 2" }  │
        │ ]                                     │
        └───────────────────────────────────────┘
```

## 4. Estrutura de Dados

### Antes (❌ Incorreto)

```
┌─────────────────────────────────────────────────────────────┐
│ BANCO DE DADOS                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ users                                                       │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ email: user@example.com                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ google_accounts                                             │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ user_id: 1                                                  │
│ login_customer_id: 7986774301 ❌ MUDA QUANDO TROCA         │
│ refresh_token: xyz...                                       │
│ manager_customer_id: NULL ❌ NÃO EXISTE                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ active_customer_selections                                  │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ user_id: 1                                                  │
│ google_account_id: 1                                        │
│ customer_id: 7986774301                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ accessible_customers                                        │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ google_account_id: 1                                        │
│ customer_id: 7986774301                                     │
│ display_name: "Meu Negócio"                                 │
├─────────────────────────────────────────────────────────────┤
│ id: 2                                                       │
│ google_account_id: 1                                        │
│ customer_id: 9876543210                                     │
│ display_name: "Outro Negócio"                               │
└─────────────────────────────────────────────────────────────┘
```

### Depois (✅ Correto)

```
┌─────────────────────────────────────────────────────────────┐
│ BANCO DE DADOS                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ users                                                       │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ email: user@example.com                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ google_accounts                                             │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ user_id: 1                                                  │
│ manager_customer_id: 7986774301 ✅ NUNCA MUDA              │
│ login_customer_id: 7986774301 ✅ PODE MUDAR SE NECESSÁRIO  │
│ refresh_token: xyz...                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ active_customer_selections                                  │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ user_id: 1                                                  │
│ google_account_id: 1                                        │
│ customer_id: 7986774301 ✅ MUDA QUANDO TROCA               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ accessible_customers                                        │
├─────────────────────────────────────────────────────────────┤
│ id: 1                                                       │
│ google_account_id: 1                                        │
│ customer_id: 7986774301                                     │
│ display_name: "Meu Negócio"                                 │
├─────────────────────────────────────────────────────────────┤
│ id: 2                                                       │
│ google_account_id: 1                                        │
│ customer_id: 9876543210                                     │
│ display_name: "Outro Negócio"                               │
└─────────────────────────────────────────────────────────────┘
```

## 5. Comparação: Antes vs Depois

| Aspecto | Antes (❌) | Depois (✅) |
|---------|-----------|-----------|
| **manager_customer_id** | Não existe | Definido UMA VEZ |
| **login_customer_id** | Muda quando troca | Permanece igual |
| **customer_id** | Muda quando troca | Muda quando troca |
| **Erro ao trocar** | 403 PERMISSION_DENIED | Nenhum |
| **Header enviado** | Incorreto | Correto |
| **Endpoint** | save_account_selection | switch_customer |
| **Fluxo** | Reconecta tudo | Apenas atualiza seleção |

## 6. Sequência de Eventos: Trocar de Account

```
ANTES (❌ Incorreto):
┌──────────────────────────────────────────────────────────┐
│ 1. Usuário seleciona nova conta                          │
│ 2. POST /google_ads/auth/select                          │
│ 3. save_account_selection() atualiza login_customer_id   │
│ 4. GoogleAccount.login_customer_id = 9876543210 ❌       │
│ 5. GET /api/google_ads/campaigns                         │
│ 6. CampaignService usa novo login_customer_id            │
│ 7. Requisição: login-customer-id: 9876543210             │
│ 8. Mas customer_id na URL é 9876543210                   │
│ 9. Google Ads API: "Você não tem permissão" ❌           │
│ 10. Erro 403 PERMISSION_DENIED                           │
└──────────────────────────────────────────────────────────┘

DEPOIS (✅ Correto):
┌──────────────────────────────────────────────────────────┐
│ 1. Usuário seleciona nova conta                          │
│ 2. POST /google_ads/auth/switch_customer                 │
│ 3. switch_customer() atualiza APENAS customer_id         │
│ 4. ActiveCustomerSelection.customer_id = 9876543210 ✅   │
│ 5. GoogleAccount.login_customer_id = 7986774301 (igual)  │
│ 6. GET /api/google_ads/campaigns                         │
│ 7. CampaignService usa login_customer_id original        │
│ 8. Requisição: login-customer-id: 7986774301             │
│ 9. URL: /customers/9876543210/googleAds:search           │
│ 10. Google Ads API: "OK, você tem permissão" ✅          │
│ 11. Retorna campanhas com status 200                     │
└──────────────────────────────────────────────────────────┘
```

## 7. Resumo Visual

```
┌─────────────────────────────────────────────────────────────┐
│ SOLUÇÃO EM UMA IMAGEM                                       │
└─────────────────────────────────────────────────────────────┘

ANTES:                          DEPOIS:
┌──────────────────┐           ┌──────────────────┐
│ GoogleAccount    │           │ GoogleAccount    │
├──────────────────┤           ├──────────────────┤
│ login_customer   │           │ manager_customer │
│ _id: 7986... ❌  │           │ _id: 7986... ✅  │
│ (muda)           │           │ (nunca muda)     │
│                  │           │                  │
│ refresh_token    │           │ login_customer   │
│ xyz...           │           │ _id: 7986... ✅  │
└──────────────────┘           │ (pode mudar)     │
         │                      │                  │
         │                      │ refresh_token    │
         │                      │ xyz...           │
         │                      └──────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────────┐      ┌──────────────────────┐
│ ActiveCustomer       │      │ ActiveCustomer       │
│ Selection            │      │ Selection            │
├──────────────────────┤      ├──────────────────────┤
│ customer_id:         │      │ customer_id:         │
│ 7986... ❌ (muda)    │      │ 7986... ✅ (muda)    │
│                      │      │                      │
│ google_account_id: 1 │      │ google_account_id: 1 │
└──────────────────────┘      └──────────────────────┘
         │                              │
         ▼                              ▼
    Requisição:                    Requisição:
    login-customer-id:             login-customer-id:
    7986... ❌                      7986... ✅
    (incorreto)                     (correto)
         │                              │
         ▼                              ▼
    403 ❌                          200 ✅
```
