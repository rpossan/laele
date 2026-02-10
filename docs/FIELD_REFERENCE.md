# Referência de Campos - Local Services Lead (v22)

## Campos Utilizados

### Campos Selecionados (SELECT)
Todos os campos abaixo são `Selectable: True` conforme documentação oficial:

1. **local_services_lead.resource_name** (RESOURCE_NAME)
   - Formato: `customers/{customer_id}/localServicesLeads/{local_services_lead_id}`
   - Usado para identificar o lead e fazer chamadas de feedback

2. **local_services_lead.id** (INT64)
   - ID único do lead

3. **local_services_lead.category_id** (STRING)
   - Categoria do serviço (ex: `xcat:service_area_business_hvac`)

4. **local_services_lead.service_id** (STRING)
   - ID do serviço específico (ex: `buyer_agent`, `seller_agent`)

5. **local_services_lead.contact_details** (MESSAGE)
   - Detalhes de contato do lead
   - Tipo: `google.ads.googleads.v22.resources.ContactDetails`

6. **local_services_lead.lead_type** (ENUM)
   - Valores: `BOOKING`, `MESSAGE`, `PHONE_CALL`, `UNKNOWN`, `UNSPECIFIED`

7. **local_services_lead.lead_status** (ENUM)
   - Valores: `ACTIVE`, `BOOKED`, `CONSUMER_DECLINED`, `DECLINED`, `DISABLED`, `EXPIRED`, `NEW`, `UNKNOWN`, `UNSPECIFIED`, `WIPED_OUT`

8. **local_services_lead.creation_date_time** (DATE)
   - **Formato**: `"YYYY-MM-DD HH:MM:SS"` no timezone da conta
   - Exemplos: `"2018-03-05 09:15:00"`, `"2018-02-01 14:34:30"`
   - **IMPORTANTE**: Para WHERE clauses, usar exatamente este formato

9. **local_services_lead.locale** (STRING)
   - Idioma usado pelo provedor de Local Services

10. **local_services_lead.lead_charged** (BOOLEAN)
    - `TRUE` se o anunciante foi cobrado pelo lead

11. **local_services_lead.lead_feedback_submitted** (BOOLEAN)
    - `TRUE` se o anunciante enviou feedback para o lead
    - **Nota**: Quando `FALSE`, o campo pode não aparecer no JSON

12. **local_services_lead.credit_details.credit_state** (ENUM)
    - **Valores corretos da API**:
      - `CREDIT_GRANTED`: Lead foi creditado (refunded)
      - `UNDER_REVIEW`: Solicitação de crédito em processamento
      - `CREDIT_INELIGIBLE`: Solicitação rejeitada (lead não qualificou)
      - `UNKNOWN` ou `NULL`: Sem informação de crédito disponível
    - **Lógica completa**:
      - Lead foi creditado: `credit_state = "CREDIT_GRANTED"`
      - Em revisão: `credit_state = "UNDER_REVIEW"`
      - Rejeitado: `credit_state = "CREDIT_INELIGIBLE"`
      - Não cobrado e sem crédito: `lead_charged = FALSE AND credit_state IS NULL`
      - Cobrado mas sem crédito solicitado: `lead_charged = TRUE AND credit_state IS NULL`

13. **local_services_lead.credit_details.credit_state_last_update_date_time** (DATE)
    - Formato: `"YYYY-MM-DD HH:MM:SS"` no timezone da conta

## Campos Filtrados (WHERE)

### Filtros de Período
```sql
local_services_lead.creation_date_time >= "2025-11-20 00:00:00"
local_services_lead.creation_date_time <= "2025-11-20 23:59:59"
```

### Filtros de Charge Status
- **Charged**: `local_services_lead.lead_charged = TRUE`
- **Credited**: `local_services_lead.credit_details.credit_state = "CREDIT_GRANTED"` (Lead foi creditado/refunded)
- **In Review**: `local_services_lead.credit_details.credit_state = "UNDER_REVIEW"` (Solicitação de crédito em processamento)
- **Rejected**: `local_services_lead.credit_details.credit_state = "CREDIT_INELIGIBLE"` (Solicitação rejeitada - lead não qualificou)
- **Not Charged**: `(local_services_lead.lead_charged = FALSE AND local_services_lead.credit_details.credit_state IS NULL)` (Nunca foi cobrado, sem crédito aplicável)

### Filtros de Feedback
- **With Feedback**: `local_services_lead.lead_feedback_submitted = TRUE`
- **Without Feedback**: `(local_services_lead.lead_feedback_submitted = FALSE OR local_services_lead.lead_feedback_submitted IS NULL)`

## Campos Adicionais Disponíveis (Não Utilizados no MVP)

### local_services_lead.note.description (STRING)
- Conteúdo de nota do lead
- Pode ser útil para adicionar no futuro

### local_services_lead.note.edit_date_time (DATE)
- Data/hora de edição da nota
- Formato: `"YYYY-MM-DD HH:MM:SS"`

## Observações Importantes

1. **Formato de Data**: Sempre usar `"YYYY-MM-DD HH:MM:SS"` (sem timezone, sem "T")
2. **lead_feedback_submitted**: Quando `false`, o campo pode não existir no JSON
3. **credit_state**: Valores podem variar entre documentação (`CREDITED`, `PENDING`) e uso real (`CREDIT_GRANTED`, `UNDER_REVIEW`)
4. **contact_details**: É um objeto MESSAGE, não uma string simples

