# Roteiro de teste — portão da Fase 1 (Infraestrutura dos agentes)

Portão do PE-PA-002: **um fluxo de teste vai e volta pela fila sem erro.**

Os testes automáticos de banco estão em `supabase/testes/fase1_fila.sql` (segredo, liga/desliga, reserva sem
duplicar, 3 tentativas com erro e aviso, Caixa de aprovação).

## Preparação (uma vez)

1. **Importar o fluxo de teste no n8n.** Abra https://srv2043014.hstgr.cloud → **Workflows** → **Create
   workflow** → no menu **⋯** (canto superior direito) → **Import from file** → escolha
   `n8n/fluxos/00-sistema-teste-fila.json` (baixe do GitHub: botão "Download raw file").
2. **Ativar o fluxo** no interruptor **Inactive/Active** no topo do editor.
3. **Importar e ativar** também `05-sistema-tratamento-erros.json` e `04-sistema-monitor-fila.json`; em cada um dos
   outros fluxos, em **Settings → Error workflow**, escolha "APRIMORA | Sistema | Tratamento de erros".
   **Não ative** os fluxos 01, 02 e 03 (dependem das Fases 2 e 3).

## Roteiro

- [ ] No portal, **Config. do funil → Agentes e fila**: ligar **Teste da fila**.
- [ ] Clicar **Enviar trabalho de teste**: aparece em "Últimos trabalhos" como **Na fila**.
- [ ] Em até 2 minutos, atualizando a página, ele aparece como **Concluído** e "Concluídos em 24 h" sobe para 1.
- [ ] No n8n, **Executions** do fluxo "Teste da fila" mostra a execução sem erro.
- [ ] Desligar **Teste da fila** e clicar em Enviar: o portal recusa ("Ligue o agente…").
- [ ] A **Caixa de aprovação** aparece no menu e mostra "Nada para aprovar".
- [ ] Um assessor não consegue ligar agentes nem enviar o teste.

## Depois do roteiro

- [ ] Deixar **Teste da fila** desligado.
- [ ] Registrar aqui a data da validação e liberar a Fase 2.
