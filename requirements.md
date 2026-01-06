You are an expert senior Python engineer.
Your task is to implement complete, production ready Python code for the Google Ads API Local Services Ads method ProvideLeadFeedback.
Follow ALL instructions exactly.

GOAL
Generate a full Python implementation that allows me to call:

provide_lead_feedback(
    customer_id,
    lead_id,
    survey_answer,
    satisfied_reason=None,
    dissatisfied_reason=None,
    comment=None,
    access_token="ya29..."
)

This function must construct the correct JSON depending on the input and send the HTTP request.

REQUIRED BEHAVIOR
Implement a fully working Python module that:

1) Provides a class LocalServicesLeadFeedbackClient
2) The class constructor accepts:
   base_url (default "https://googleads.googleapis.com"),
   api_version (default "v22"),
   access_token string

3) Exposes a public method provide_lead_feedback that:
   parameters:
     customer_id str
     lead_id str
     survey_answer str
     satisfied_reason str optional
     dissatisfied_reason str optional
     comment str optional
   behavior:
     builds the correct JSON payload based on survey_answer and reasons
     sends a POST request with the proper URL and headers
     parses and returns the JSON response object
     raises a clear Python exception when the response is not successful (status code >= 400)

4) Uses the requests library

5) Handles the logic:
   If survey_answer in ["VERY_SATISFIED", "SATISFIED"]:
       include "surveySatisfied" object
       "surveyDissatisfied" must NOT be present
   If survey_answer in ["DISSATISFIED", "VERY_DISSATISFIED"]:
       include "surveyDissatisfied" object
       "surveySatisfied" must NOT be present
   If survey_answer == "NEUTRAL":
       do NOT include "surveySatisfied" or "surveyDissatisfied"
   If satisfied_reason == "OTHER_SATISFIED_REASON":
       require comment and map it to "otherReasonComment" inside surveySatisfied
   If dissatisfied_reason == "OTHER_DISSATISFIED_REASON":
       require comment and map it to "otherReasonComment" inside surveyDissatisfied

6) Validates inputs:
   survey_answer must be one of:
     "VERY_SATISFIED", "SATISFIED", "NEUTRAL", "DISSATISFIED", "VERY_DISSATISFIED"
   satisfied_reason must be one of:
     "BOOKED_CUSTOMER",
     "LIKELY_BOOKED_CUSTOMER",
     "SERVICE_RELATED",
     "HIGH_VALUE_SERVICE",
     "OTHER_SATISFIED_REASON"
     or None
   dissatisfied_reason must be one of:
     "GEO_MISMATCH",
     "JOB_TYPE_MISMATCH",
     "NOT_READY_TO_BOOK",
     "SPAM",
     "DUPLICATE",
     "SOLICITATION",
     "OTHER_DISSATISFIED_REASON"
     or None
   Raise ValueError with a helpful message for invalid combinations.

7) Builds the URL in this format:
   f"{base_url}/{api_version}/customers/{customer_id}/localServicesLeads/{lead_id}:provideLeadFeedback"

8) Uses these HTTP headers:
   "Authorization": f"Bearer {self.access_token}"
   "Content-Type": "application/json"

9) Uses the official documentation structure below as the source of truth for fields and enums.

DOCUMENTATION FOR PROVIDELEADFEEDBACK

Endpoint:
POST https://googleads.googleapis.com/v22/{resourceName=customers/*/localServicesLeads/*}:provideLeadFeedback

resourceName format:
customers/{customer_id}/localServicesLeads/{lead_id}

Request body JSON:
{
  "surveyAnswer": "ENUM",
  "surveySatisfied": {
    "surveySatisfiedReason": "ENUM",
    "otherReasonComment": "string"
  },
  "surveyDissatisfied": {
    "surveyDissatisfiedReason": "ENUM",
    "otherReasonComment": "string"
  }
}

surveyAnswer enum:
VERY_SATISFIED
SATISFIED
NEUTRAL
DISSATISFIED
VERY_DISSATISFIED

SurveySatisfiedReason enum:
BOOKED_CUSTOMER
LIKELY_BOOKED_CUSTOMER
SERVICE_RELATED
HIGH_VALUE_SERVICE
OTHER_SATISFIED_REASON

SurveyDissatisfiedReason enum:
GEO_MISMATCH
JOB_TYPE_MISMATCH
NOT_READY_TO_BOOK
SPAM
DUPLICATE
SOLICITATION
OTHER_DISSATISFIED_REASON

Response JSON:
{
  "creditIssuanceDecision": "ENUM"
}

RESPONSE ENUM creditIssuanceDecision (for reference only, you do not need special handling per value):
SUCCESS_NOT_REACHED_THRESHOLD
SUCCESS_REACHED_THRESHOLD
FAIL_OVER_THRESHOLD
FAIL_NOT_ELIGIBLE

OAUTH SCOPE (for reference):
https://www.googleapis.com/auth/adwords

REQUIRED OUTPUT FORMAT

Return ONLY Python code in a single code block, containing:

1) All imports needed (for example import requests, from typing import Optional)
2) A LocalServicesLeadFeedbackClient class
3) Validation helpers for enums
4) A method to build the request payload
5) A public method provide_lead_feedback implementing the full behavior
6) A small usage example inside an if __name__ == "__main__": block that demonstrates:
   creating the client
   calling provide_lead_feedback with a VERY_SATISFIED and BOOKED_CUSTOMER example
   printing the response

Do NOT return explanations or markdown.
Return just Python code.









Deploy e linkar no domain

Colocar um privacy policy 

------

Ao conectar primeira vez load tem sido de ate 1 minuto, ele esta puxando  Request body: {"query":"SELECT\n  customer.id,\n  customer.descriptive_name\nFROM customer\n"}

------

Remover recomendado da seleçao inicial 

Na selecçao de contas o nome ja deve vir, selecionar o nome da conta local services

Ids de conta devem estar no modelo 

5860831044

ou 

586-083-1044 atualmente esta 586-083-104-4

-----

tambem na parte Escolha uma conta administrada

esta o id - sem nome


----

nao ter cache na primeira seleçao de conta

----


Na visalizaçao inicial deve conter lead id : e onumero, pra nao gerar consfusao quanto ao telefone

-----

filtros 

----

Lead filter custom nao abre datepicker pra selecionar data 


Survey Satisfied - Very Satisfied

https://developers.google.com/google-ads/api/reference/rpc/v22/LocalServicesLeadSurveySatisfiedReasonEnum.SurveySatisfiedReason

Which of the following best describes why you are satisfied with this lead? Select all that apply.

It converted into a booked customer or client > enum BOOKED_CUSTOMER

It could convert into a booked customer or client soon > enum LIKELY_BOOKED_CUSTOMER

It is relevant to the services the business provides > enum SERVICE_RELATED

It is for a service that generates high value for the business > enum HIGH_VALUE_SERVICE

Satisfied > nao passa nada, nem seleciona razao 


Dissasfitied > nao passa nada, nem seleciona razao 


Other (please specify) > Enum OTHER_SATISFIED_REASON - passa um string com other_reason_comment

SurveyDissatisfiedReason > Very Dissastifies

It is not located in the service area(s) for the business > ENUM GEO_MISMATCH

It is for a service the business does not provide > ENUM JOB_TYPE_MISMATCH

The person calling was not ready to book services > ENUM NOT_READY_TO_BOOK

It is spam (e.g., unwanted robocall or message, silent caller, scam) > ENUM SPAM

It is a duplicate lead (i.e., a person contacted the business more than once) > ENUM DUPLICATE

It is a person seeking employment or trying to sell a product or service > ENUM SOLICITATION

Other (please specify) > Enum OTHER_DISSATISFIED_REASON - passa um string com other_reason_comment


Apos envio do feedback retornar a response, e registrar isso no painel do lead, e identificar rate submiteed tanto por 

Enums
UNSPECIFIED
Not specified.
UNKNOWN
Used for return value only. Represents value unknown in this version.
SUCCESS_NOT_REACHED_THRESHOLD
Bonus credit is issued successfully and bonus credit cap has not reached the threshold after issuing this bonus credit.
SUCCESS_REACHED_THRESHOLD
Bonus credit is issued successfully and bonus credit cap has reached the threshold after issuing this bonus credit.
FAIL_OVER_THRESHOLD
Bonus credit is not issued because the provider has reached the bonus credit cap.
FAIL_NOT_ELIGIBLE
Bonus credit is not issued because this lead is not eligible for bonus credit.


Na pesquisa > 

Leads sem feedback enviado
lead_feedback_submitted = FALSE
Na prática, se o campo não vier ou vier false, considerar “sem feedback”

Leads com feedback enviado
lead_feedback_submitted = TRUE

-------------

Na pagina de adicionar zip codes dar um direiconamento para buscar os zip codes nesse website

https://www.unitedstateszipcodes.org/zip-code-radius-map.php

---------

Seletor de Estado ou nao selecionar um estado antes de colar as regioes, e valida se esta dentro do estado antes de enviar 

colocar em Endereços não encontrados e Fora da area de cobertura 

-----

abrir um widget de suporte para envio de bugs (assim que deployado)

-----

beta tester 

pros 5-10 primeiros usuarios, nao limitar conta e cobrar 1000 reais