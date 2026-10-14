# Roadmap — Tiny Kingdom

## Fase 1 — MVP de combate

- [x] Projeto Godot 4 / GDScript, 1280 × 720 e Compatibility.
- [x] Cenas de mundo, jogador, inimigo, HUD e cena principal.
- [x] Movimento em 8 direções, teclado, câmera e limites físicos.
- [x] Detecção, perseguição, dano periódico e morte de inimigos.
- [x] Ataque automático ao alvo mais próximo com cooldown e feedback visual.
- [x] Vida, experiência, níveis e aumento de atributos.
- [x] Madeira, pedra e ouro com drops diretos no estoque.
- [x] HUD atualizado por sinais, objetivo, vitória e derrota (agora integrados ao retorno à vila).
- [x] Mapa explorável com placeholders e terreno reservado à vila.
- [x] Adaptador de input preparado para receber joystick virtual.
- [x] Testes de integração do fluxo jogável.

## Fase 2 — Vila

- [x] Cena própria de vila com praça, depósito, portal e espaços visuais para construções futuras.
- [x] GameState central com estoque permanente, carga temporária e progressão.
- [x] Save JSON v1 em user://, criação/leitura automáticas e validação contra corrupção.
- [x] Depósito transacional com salvamento automático e feedback de falha/sucesso.
- [x] Interação reutilizável por E, pronta para botão mobile.
- [x] Ciclo vila → expedição → combate → retorno → depósito → nova expedição.
- [x] Morte com perda da carga, manutenção da progressão e retorno curado à vila.
- [x] HUD distinguindo Carregando/Armazenado e contador de expedições concluídas.
- [x] Spawn e câmera por mapa sem duplicar jogador.
- [x] Reset F9 exclusivo de desenvolvimento, com confirmação.
- [x] Testes de persistência, depósito, morte, transições e reabertura do jogo.

O save v1 da Fase 2 é migrado automaticamente para v2 na Fase 3.

## Fase 3 — Construções

- [x] Três terrenos fixos com arquitetura reutilizável e visuais distintos.
- [x] Painel de construção/melhoria por E, confirmação por Enter/botão e cancelamento por Esc.
- [x] Economia central, custos e transações seguras diante de falha de save.
- [x] Prefeitura nível 1, HUD de nível da vila e desbloqueio de Ferreiro/Torre.
- [x] Ferreiro com três melhorias permanentes de arma (+3, +4, +5).
- [x] Torre com alvo mais próximo, alcance, dano, cooldown e efeito de ataque.
- [x] Persistência v2 de construções/posições/arma e migração v1 preservando progresso.
- [x] 134 verificações anteriores preservadas e 85 novas aprovadas.

Escopo desta fase concluído. Posicionamento livre, casas, muralhas, vida das estruturas e ondas completas foram adiados; não fazem parte desta entrega.

## Fase 4 — Inventário e equipamentos

- [x] Contadores básicos de madeira, pedra e ouro.
- [ ] Coleta física, inventário de itens e interface.
- [ ] Armas, armaduras, atributos e raridades.
- [ ] Persistência dos itens e equipamentos.

## Fase 5 — Skills

- [ ] Habilidades ativas/passivas e seus cooldowns.
- [ ] Escolhas de evolução ao subir de nível.
- [ ] Ações de input e botões para habilidades.

## Fase 6 — Novos mapas

- [ ] Biomas, transições e distribuição de recursos.
- [ ] Novos tipos de inimigo e navegação por obstáculos.
- [ ] Progressão de dificuldade e encontros.

## Fase 7 — Bosses

- [ ] Padrões de ataque legíveis e fases de combate.
- [ ] Arenas, recompensas e progressão.

## Fase 8 — Mobile e polimento

- [x] Resolução base em paisagem e layout ancorado.
- [x] Separação entre fonte de input e movimento/física.
- [ ] Joystick virtual, botões de habilidade e tratamento multitouch.
- [ ] Safe areas, diferentes proporções de tela e testes em dispositivos.
- [ ] Pixel art, animações, áudio e acessibilidade.
- [ ] Profiling, otimização e balanceamento.

## Fase 9 — APK Beta

- [ ] Templates de exportação, SDK/JDK e preset Android.
- [ ] Identificador do aplicativo, versões e assinatura segura.
- [ ] APK de teste, validação em aparelhos e distribuição beta.
- [ ] Correções de estabilidade com feedback dos jogadores.
