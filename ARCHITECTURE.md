# Arquitetura do Backend - Google Ads Local Services Leads

## 1. Visão Geral da Arquitetura

### Princípios
- **Uma conta ativa por vez**: Cada usuário trabalha com uma `ActiveCustomerSelection` que define o `customer_id` ativo
- **Separação de responsabilidades**: Serviços especializados para cada funcionalidade
- **Segurança**: Refresh tokens armazenados em texto plano (pode ser criptografado depois)
- **API RESTful**: Endpoints claros e consistentes

## 2. Estrutura de Serviços

### 2.1 GoogleAds::OauthClient
**Responsabilidade**: Gerenciar fluxo OAuth 2.0
- Gerar URL de autorização
- Trocar código por tokens (access + refresh)
- Validar refresh tokens

**Localização**: `app/services/google_ads/oauth_client.rb`

### 2.2 GoogleAds::CustomerService
**Responsabilidade**: Listar contas acessíveis
- Usa REST API (v22 não expõe via gRPC)
- Retorna lista de customer_ids acessíveis

**Localização**: `app/services/google_ads/customer_service.rb`

### 2.3 GoogleAds::ClientBuilder
**Responsabilidade**: Construir cliente Google Ads API
- Configura credenciais
- Cria instância do GoogleAdsClient

**Localização**: `app/services/google_ads/client_builder.rb`

### 2.4 GoogleAds::LeadService
**Responsabilidade**: Buscar e gerenciar leads
- Lista leads com filtros
- Usa REST API como fallback (gRPC pode não estar disponível)
- Suporta paginação

**Localização**: `app/services/google_ads/lead_service.rb`

### 2.5 GoogleAds::LeadQueryBuilder
**Responsabilidade**: Construir queries GAQL dinamicamente
- SELECT base fixo
- Adiciona filtros WHERE dinamicamente
- Formata datas corretamente: "YYYY MM DD HH,MM,SS"

**Localização**: `app/services/google_ads/lead_query_builder.rb`

### 2.6 GoogleAds::ConversationService (Futuro)
**Responsabilidade**: Buscar conversas de um lead
- Query: `local_services_lead_conversation`
- Filtro por `lead` resource_name

**Localização**: `app/services/google_ads/conversation_service.rb` (a criar)

### 2.7 GoogleAds::LeadFeedbackService
**Responsabilidade**: Enviar feedback de leads
- Usa REST API: `POST /v22/customers/{customer_id}/localServicesLeads/{lead_id}:provideLeadFeedback`
- Valida survey_answer, reasons e comments
- Suporta: VERY_DISSATISFIED, DISSATISFIED, SATISFIED, VERY_SATISFIED

**Localização**: `app/services/google_ads/lead_feedback_service.rb`

## 3. Modelos de Dados

### 3.1 User
- Autenticação via Devise
- `has_many :google_accounts`
- `has_one :active_customer_selection`

### 3.2 GoogleAccount
- `belongs_to :user`
- Armazena `refresh_token` (texto plano)
- `login_customer_id`: ID da conta MCC ou principal
- `has_many :accessible_customers`
- `has_one :active_customer_selection`

### 3.3 ActiveCustomerSelection
- `belongs_to :user` (unique)
- `belongs_to :google_account`
- `customer_id`: ID da conta ativa para trabalhar
- Define qual conta está sendo usada no momento

### 3.4 AccessibleCustomer (Opcional)
- `belongs_to :google_account`
- Armazena lista de contas acessíveis
- Pode ser usado para cache

## 4. Rotas da API

### 4.1 Autenticação e Conexão
```
GET  /google_ads/auth/start              # Iniciar OAuth
GET  /google_ads/auth/callback           # Callback OAuth
GET  /google_ads/auth/select             # Selecionar conta
POST /google_ads/auth/select              # Salvar seleção
DELETE /google_ads/auth/disconnect/:id    # Desconectar
```

### 4.2 Gerenciamento de Contas
```
GET  /api/google_ads/customers           # Listar contas acessíveis
POST /api/google_ads/customers/select    # Selecionar conta ativa
```

### 4.3 Leads (MVP)
```
GET  /api/leads                          # Listar leads com filtros
```

**Parâmetros**:
- `period`: this_week, last_week, this_month, last_month, last_30_days, all_time, custom
- `start_date`: Para período custom (YYYY-MM-DD)
- `end_date`: Para período custom (YYYY-MM-DD)
- `charge_status`: charged, credited, in_review, rejected, not_charged
- `feedback_status`: with_feedback, without_feedback
- `page_size`: Número de resultados (padrão: 25)
- `page_token`: Token para próxima página

**Resposta**:
```json
{
  "leads": [...],
  "next_page_token": "...",
  "gaql": "SELECT ..."
}
```

### 4.4 Conversas (Futuro)
```
GET  /api/leads/:lead_id/conversations   # Listar conversas de um lead
```

### 4.5 Feedback
```
POST /api/leads/:lead_id/feedback        # Enviar feedback de um lead
```

**Body**:
```json
{
  "survey_answer": "VERY_DISSATISFIED" | "DISSATISFIED" | "SATISFIED" | "VERY_SATISFIED",
  "reason": "SPAM" | "JOB_TYPE_MISMATCH" | "DUPLICATE" | "SERVICE_RELATED" | "BOOKED_CUSTOMER" | etc,
  "other_reason_comment": "Texto opcional"
}
```

**Exemplos**:

1. Lead Insatisfeito:
```json
{
  "survey_answer": "DISSATISFIED",
  "reason": "JOB_TYPE_MISMATCH",
  "other_reason_comment": "Serviço solicitado não corresponde ao oferecido"
}
```

2. Lead Satisfeito:
```json
{
  "survey_answer": "SATISFIED",
  "reason": "BOOKED_CUSTOMER",
  "other_reason_comment": "Lead convertido em agendamento"
}
```

## 5. Fluxo de Trabalho

### 5.1 Conectar Conta Google Ads
1. Usuário clica em "Conectar Google Ads"
2. `GET /google_ads/auth/start` → Redireciona para Google OAuth
3. Usuário autoriza
4. `GET /google_ads/auth/callback` → Recebe código
5. Troca código por refresh_token
6. Busca contas acessíveis
7. Redireciona para seleção de conta
8. Usuário seleciona conta
9. `POST /google_ads/auth/select` → Salva `ActiveCustomerSelection`

### 5.2 Listar Leads
1. Frontend chama `GET /api/leads?period=last_30_days&charge_status=charged`
2. Controller verifica `ActiveCustomerSelection`
3. `LeadService` constrói query GAQL
4. Tenta gRPC, fallback para REST
5. Processa resultados
6. Retorna JSON com leads

## 6. Tratamento de Campos Opcionais

### 6.1 lead_feedback_submitted
- Se campo existe e é `true` → `true`
- Se campo não existe ou é `false` → `false`
- Implementado em `LocalServicesLeadPresenter`

### 6.2 credit_details
- Pode ser `nil`
- Usar safe navigation: `lead.credit_details&.credit_state`

## 7. Formato de Datas

### 7.1 Na Query GAQL (WHERE clauses)
**IMPORTANTE**: Para condições WHERE com `creation_date_time`, a API requer o formato `"YYYY-MM-DD HH:MM:SS"`.

Formato: `"YYYY-MM-DD HH:MM:SS"`
Exemplos válidos:
- `"2025-11-20 00:00:00"`
- `"2025-11-19 23:59:59"`
- `"2023-05-31 09:47:08"`

**Regras**:
- Não pode ter timezone
- Não pode ter "T" entre data e hora
- Deve usar espaço entre data e hora

### 7.2 No JSON de Resposta
Formato ISO 8601 (como vem da API)
Exemplo: `"2025-11-05T00:00:00Z"` ou `"2025 11 05 00,00,00"` (dependendo da API)

## 8. Segurança

### 8.1 Refresh Tokens
- Atualmente: texto plano no banco
- Futuro: criptografar usando Rails encryption

### 8.2 Access Tokens
- Gerados sob demanda
- Não armazenados
- Expiração automática

### 8.3 Validação
- Verificar `ActiveCustomerSelection` antes de qualquer operação
- Validar permissões do usuário

## 9. Exemplos de Código

### 9.1 Query GAQL Dinâmica
```ruby
# app/services/google_ads/lead_query_builder.rb
builder = GoogleAds::LeadQueryBuilder.new(
  period: "last_30_days",
  charge_status: "charged",
  feedback_status: "without_feedback"
)
query = builder.to_gaql
# => "SELECT ... FROM local_services_lead WHERE ..."
```

### 9.2 Buscar Leads
```ruby
# app/services/google_ads/lead_service.rb
service = GoogleAds::LeadService.new(
  google_account: google_account,
  customer_id: "9604421505"
)

result = service.list_leads(
  filters: {
    period: "last_30_days",
    charge_status: "charged"
  },
  page_size: 25,
  page_token: nil
)
```

### 9.3 Processar Resposta REST
```ruby
# A resposta REST vem como:
{
  "results": [
    {
      "localServicesLead": {
        "id": "123",
        "lead_type": "PHONE_CALL",
        "lead_feedback_submitted": true  # ou não vem
      }
    }
  ],
  "nextPageToken": "..."
}
```

## 10. Próximos Passos (Futuro)

1. **Conversas**: Implementar `ConversationService` e endpoint completo
2. **Criptografia**: Criptografar refresh tokens
3. **Cache**: Cachear contas acessíveis
4. **Webhooks**: Notificações de novos leads (se disponível)
5. **Validação de feedback**: Verificar se lead já tem feedback antes de permitir novo envio

