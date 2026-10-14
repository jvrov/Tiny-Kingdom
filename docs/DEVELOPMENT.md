# Desenvolvimento

## Responsabilidades

- `Main.tscn` mantém um único `Player` e `HUD`. Seu nó `Map` recebe `Village.tscn` ou `World.tscn`; os inimigos ficam em `Actors`. A troca remove o mapa/inimigos anteriores e reposiciona o jogador, com limites de câmera correspondentes.
- `GameState` é um Autoload. `village_resources` e `progression` são permanentes; `expedition_resources` e `expedition_active` só existem na memória. A inicialização ocorre quando `Main` chama `initialize()`, antes de aplicar os atributos ao jogador.
- `SaveSystem` é uma classe `RefCounted` com caminho injetável. Valida versão, tipos, inteiros finitos, faixas e XP coerente com o nível. Isso permite testes de arquivos sem tocar no slot real.
- `Player` mantém a mecânica do MVP. `apply_progress()` restaura atributos/carga, vida, cooldowns e input na chegada a cada mapa. Mudanças de estatísticas são sincronizadas pelo controlador `Main`; o jogador continua utilizável isoladamente nos testes de combate.
- `InteractionController`, filho do jogador, escolhe o objeto interagível válido mais próximo. O input **E** fica nesse único componente. `KingdomInteractable` valida distância/vida e emite `interacted`; os objetos não leem teclas.
- `Village` desenha praça, depósito e portal; as três cenas de construções desenham os terrenos/prédios. O mapa de exploração preserva combate, paredes e cenário, com um novo ponto de retorno.
- `HUD` acompanha sinais do jogador/estado, distingue estoque/carga, mostra interação e falhas de save. O reset exige confirmação e pausa o jogo enquanto o diálogo está aberto.

Grupos: `player`, `enemies`, `interactables`, `buildings`. Camadas físicas: **1 mundo**, **2 jogador**, **3 inimigos**. Só os limites dos mapas e os personagens têm colisão; os objetos de interação e a decoração não bloqueiam o movimento.

## Construções e economia

- `BuildingData` centraliza IDs, nomes, descrições, posições fixas, custos e bônus. Nível 0 representa terreno disponível; nível 1 representa construção pronta.
- `VillageBuilding` reutiliza `KingdomInteractable`, observa `GameState.changed` e atualiza posição, desenho, nível e prompt. Prefeitura e Ferreiro compartilham a cena genérica; `ArcherTower` a especializa com alvo mais próximo, cooldown e efeito visual.
- `BuildingPanel` exibe a oferta central calculada pelo estado, pausa a árvore e emite a intenção de compra. Não movimenta recursos. Botões, Enter e Esc permitem uso desktop e futura ligação com touch.
- `Main` valida mapa, vida e distância antes de encaminhar a compra. `GameState` concentra `can_afford`, `spend_resources`, `building_offer`, `purchase_building` e a transação privada `_commit_economy`. Uma oferta inclui o nível esperado, impedindo cobrança duplicada de uma confirmação antiga.
- A transação desconta recursos e aplica a evolução em uma cópia. Somente após salvar com sucesso essa cópia substitui o estado permanente e emite sinais. Na falha, nada é aplicado ao estoque, prédio ou jogador.
- O save guarda dano total e nível da arma separadamente. Cada compra soma somente a diferença entre bônus acumulados; `weapon_upgraded` faz o jogador receber o total atualizado. Carregamentos nunca somam o bônus outra vez.
- A Torre só funciona construída e com HP positivo. Reutiliza a mesma seleção de alvo e ataque na defesa; abates sem fonte não concedem XP/carga.

## Defesa e WaveManager

`Main` mantém um `WaveManager` junto ao jogador/HUD. `GameState.defense` aponta para esse coordenador em memória; `defense_busy()` consulta sua máquina de estados, sem duplicar booleanos no save.

Estados: `IDLE → PREPARING → ACTIVE ↔ BETWEEN_WAVES → VICTORY/DEFEAT`. A bandeira reutiliza `KingdomInteractable`; a confirmação pausa a árvore, e cancelar volta para IDLE. PREPARING, ACTIVE e BETWEEN_WAVES bloqueiam ações econômicas/expedição tanto no controlador quanto no estado central. Terminal permite uma nova preparação; vitória com recompensa pendente exige resolver a gravação primeiro.

`COUNTS` define 5/7/9/12/15 inimigos. O coordenador mantém número da onda, orçamento de spawns, dicionário de inimigos vivos, relógios de spawn/intervalo/respawn e dificuldade capturada no início. Um sinal `defeated` só remove um ID conhecido; a onda termina apenas com orçamento inteiro criado e nenhum vivo. O intervalo usa delta da física e pausa junto com o jogo. Não há corrotinas de respawn que possam sobreviver ao reset.

`enemy_scene` é exportado para permitir outra cena compatível com `KingdomEnemy`. As quatro posições ficam dentro das bordas físicas; `choose_spawn` pula entradas próximas ao jogador. `enemy_stats` combina base da onda com no máximo dez defesas concluídas. O tipo de inimigo atual permanece único.

`KingdomEnemy` preserva a IA de expedição. No modo `invading`, `select_defense_target` escolhe jogador vivo a até 160 px, prédio vivo mais próximo a até 180 px ou Prefeitura. Alvos compartilham posição, `is_alive()` e `take_damage()`. Invasores perseguem a vila além do alcance normal de detecção, concedem XP somente a abates do jogador e nunca fazem drops de recursos.

`VillageBuilding` mantém HP apenas em memória: Prefeitura 300; demais prédios 150. `set_defending` restaura HP no início/fim; `take_damage` só funciona durante a batalha. Zero HP desativa o prédio, sem alterar nível persistente. O sinal da Prefeitura provoca derrota. Barras de HP e cor indicam dano/desativação.

A morte do jogador durante defesa inicia um relógio de cinco segundos no coordenador. Os invasores continuam agindo. O respawn reutiliza `apply_progress`, mantendo dano total, XP e carga. Fim da batalha limpa invasores, cancela respawn e restaura jogador/prédios. Reset cancela o coordenador e recria o mapa pelo fluxo existente.

A vitória solicita `GameState.commit_defense_reward()`: soma recursos e contador em uma cópia, grava e só então aplica. A elegibilidade é consumida antes de emitir sinais, impedindo recompensa duplicada por chamadas reentrantes. Falha mantém pendência na sessão e oferece nova tentativa na bandeira, bloqueando partida/nova defesa. Fechar o processo abandona batalha ou recompensa ainda não gravada. Derrota não faz transação de recompensa.

## Contrato de persistência

O formato v3 contém `version`, `resources`, `player` (nível, XP, vida máxima, dano) e `expeditions_completed`, além de `buildings` (nível e posição por ID) `weapon_level` e `defenses_completed`. As posições fixas, limites e dependências entre prédios/arma também são validados. Não contém vida atual, posição, inimigos, mapa ativo ou recursos carregados. Um novo processo sempre inicia na vila, com vida cheia e carga vazia.

A progressão salva imediatamente quando XP/atributos mudam. Cada retorno vivo incrementa o contador uma vez; uma morte não incrementa. Limpar todos os inimigos só conclui o objetivo de combate: o jogador ainda precisa voltar ao marco e interagir.

O depósito soma os recursos ao estoque e tenta gravar o snapshot permanente. Só depois de uma gravação bem-sucedida ele limpa a carga; na falha, restaura o estoque anterior e permite nova tentativa. Gravações usam `save.json.tmp`, flush e renomeação para preservar o arquivo anterior em falhas comuns. Isso não é uma garantia contra toda falha física de armazenamento, nem um sistema de múltiplos escritores.

Saves v1 e v2 válidos migram para v3: a etapa v1 adiciona prédios/arma padrão; a etapa v2 adiciona defesas concluídas em zero. Os demais campos são preservados integralmente, incluindo o dano total. O original é copiado para `.v1-*.bak` ou `.v2-*.bak` antes de gravar v3. Falha no backup bloqueia gravações; falha ao salvar mantém o original para tentar novamente na próxima inicialização.

Arquivos corrompidos são copiados para `.corrupt-*` antes de substituir por valores padrão. Saves de versões desconhecidas são preservados e não recebem gravações. Falhas ficam visíveis na HUD. O reset explícito de desenvolvimento pode remover o slot e criar valores padrão; backups de corrupção e migração não são apagados.

O slot padrão é `user://save.json`; caminhos por sistema e regras de perda de carga estão no README. Não altere a pasta XDG entre execuções se quiser continuar usando o mesmo save.

## Transições e morte

O controlador usa uma trava de transição para impedir interações duplicadas. A remoção/criação de corpos ocorre de forma diferida. Na morte em expedição, a carga é zerada e o feedback aparece por dois segundos; depois o jogador retorna curado à vila. Um contador de geração invalida retornos atrasados caso o progresso seja resetado durante esse intervalo.

Uma nova saída exige carga vazia para não descartá-la silenciosamente. Ao voltar, não há depósito automático. Trocas de mapa mantêm um só jogador e não recarregam o Autoload.

## Futuro input mobile

```gdscript
player.movement_input.set_virtual_direction(joystick_vector)
# Ao soltar/cancelar o toque:
player.movement_input.clear_virtual_direction()
# Botão de interação:
player.interaction.interact()
```

A intensidade analógica é preservada e o comprimento limitado a 1. Input virtual ativo tem prioridade; perder foco limpa esse estado. Interações futuras com NPCs, baús e construções podem reutilizar o sinal/alcance do objeto interagível, acrescentando suas ações no controlador apropriado.

## Ajustes e testes

Atributos do jogador e inimigos continuam expostos por `@export`. `ENEMY_POSITIONS` em `main.gd` define a população fixa. `move_and_slide()` já aplica delta à velocidade em pixels/segundo; cooldowns usam o delta da física.

Os testes de regressão foram mantidos e adaptados ao novo contrato: morte retorna à vila com progresso, em vez de reiniciar tudo; vitória orienta o retorno em vez de encerrar a cena. `progression_test.gd` cobre arquivos reais, transações, corrupção, transições, reset e reabertura em processo separado. `building_test.gd` acrescenta 85 verificações de construções, economia, UI, migração e defesa, totalizando 219 com as 134 anteriores. `defense_test.gd` acrescenta 111 verificações, totalizando 330. Usa relógios controlados para percorrer as 48 instâncias das cinco ondas e física real para IA/dano, além de falhas de arquivo reais. O auxiliar `persistence_probe.gd` verifica também prédios, posições, nível da arma, dano e defesas concluídas em processos novos, sem restaurar batalhas ou duplicar recompensas. Cada suíte seleciona um caminho exclusivo `user://tests/` antes de instanciar `Main` e apaga somente seus próprios arquivos ao terminar. Uma execução interrompida pode deixar fixtures nessa pasta, sem afetar `save.json`.

## Ambiente na nuvem

Use o checkout existente em `/workspace/Tiny-Kingdom`. Cada tarefa já possui ambiente isolado; não crie worktrees sem solicitação do usuário. Godot 4.6.3 está disponível como `godot`. Não há serviços ou dependências adicionais.

```sh
export XDG_CACHE_HOME=/workspace/.tiny-kingdom/cache
export XDG_DATA_HOME=/workspace/.tiny-kingdom/data
export XDG_CONFIG_HOME=/workspace/.tiny-kingdom/config
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
cd /workspace/Tiny-Kingdom
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd --fixed-fps 60
godot --headless --path . --script res://tests/progression_test.gd --fixed-fps 60
godot --headless --path . --script res://tests/building_test.gd --fixed-fps 60
godot --headless --path . --script res://tests/defense_test.gd --fixed-fps 60
godot --headless --path . --quit-after 180 --fixed-fps 60
```

Para interação visual, use `godot --editor --path .` ou `godot --path .` em um desktop com display. Não há servidor web. Processos precisam ser reiniciados em cada sessão. `.godot/` é gerado e ignorado; arquivos `.gd.uid` são versionados. Não versione saves, exportações, segredos ou chaves Android.
