# Lantern assistant

## First layer: built-in offline guide

The desktop and mobile interfaces offer local guidance and a staff request template. Search stays on the device, does not read conversations, does not send messages and does not call a model. This is a guide, not ChatGPT or an autonomous AI agent. It remains useful without internet or a model download.

## Conversational copilot: integration requirements

Online and offline AI are separate capabilities, not currently configured or bundled in the preview.

- Online: an authenticated backend can call the OpenAI Responses API. Keep provider keys on the server, never inside an APK, browser bundle or distributed desktop binary. Require explicit consent for the text submitted, avoid automatic access to conversations or coordinates, set limits and handle timeouts without disrupting nearby messages.
- Offline: a separate local model and inference engine must be selected, licensed, downloaded and tested for each supported device class. Do not claim that this ChatGPT session or its capabilities are embedded. Check memory, storage, heat, battery use, latency and multilingual quality before choosing a model. Desktop support does not establish phone compatibility.
- Shared UX: show the active mode and whether information leaves the device. Never silently switch a private offline request to a cloud provider. Model output is advice or a draft; users review it before sending. Reading third-party text must not grant permission to execute its instructions.
- Workplace knowledge: approved organization procedures should have visible source, owner and revision date. Do not invent emergency procedures or claim generated advice replaces an organization's established response plan.
- Tools: initially read-only help and drafts. Sending, alerts, permissions and location changes continue to require deliberate confirmation by the person using the app.

Potential uses include explaining controls, drafting a maintenance request, searching approved operating procedures and summarizing user-selected handover notes. Translation and voice assistance need separate quality and accessibility testing.

## Primary references

- https://developers.openai.com/api/reference/overview — authentication and keeping API keys out of client applications.
- https://developers.openai.com/learn/gpt-oss — open-weight/local model resources; local deployment is distinct from embedding ChatGPT.

No provider credential, deployed AI backend or bundled inference model is supplied by this preview.

## Optional telephone assistant (planned)

A future opt-in call service may connect a verified user number to a voice AI through a telephony provider. The user can request a callback, converse and approve supported actions. This requires a configured backend, provider credentials, an authorized calling number and an available telephone connection; it is not an offline radio feature. The backend must verify signed provider webhooks, enforce recipient consent and rate/cost limits, disclose the AI at call start, and require confirmation for consequential actions. A number or caller ID alone is not sufficient authentication for access to staff information. Recording should be off by default with a visible choice and appropriate deployment review.

The official OpenAI telephony guide describes connecting incoming SIP calls through a provider: https://developers.openai.com/api/docs/guides/voice-sip . Outbound callbacks also need provider-side dialing and must be separately implemented and tested. No telephone call has been made and no calling service is active in this preview.
