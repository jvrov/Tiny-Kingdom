# Desenvolvimento

## Cenas e responsabilidades

- `Main.tscn` compõe o mundo, o jogador e o HUD. `main.gd` cria os 12 inimigos, acompanha as mortes e recarrega a cena ao reiniciar.
- `Player.tscn` contém `CharacterBody2D`, collider, `Camera2D` e `MovementInput`. `player.gd` administra atributos, combate, recompensas e sinais.
- `Enemy.tscn` contém o corpo e collider do inimigo. `enemy.gd` administra a IA, cooldown, dano e recompensa única por morte.
- `World.tscn` usa `world.gd` para desenhar cenário determinístico e criar quatro paredes estáticas. A geometria decorativa não possui colisão.
- `HUD.tscn` possui controles editáveis no editor. `hud.gd` conecta os sinais do jogador e atualiza os indicadores, sem alterar suas regras.

Os grupos `player` e `enemies` permitem localizar participantes. As camadas físicas são **1: mundo**, **2: jogador**, **3: inimigos**. O jogador colide com mundo/inimigos; inimigos colidem com todas as três camadas.

## Ajustar o balanceamento

As propriedades `@export` dos scripts de jogador e inimigo aparecem no Inspector. Velocidade, vida, dano, alcance, cooldown, XP e chance de drop podem ser alterados por instância. As posições iniciais estão em `ENEMY_POSITIONS`, em `main.gd`.

Velocidade é dada em pixels por segundo. `move_and_slide()` aplica o delta da física; não multiplique `velocity` por delta novamente. Cooldowns e efeitos visuais descontam o delta recebido em `_physics_process`.

## Futuro input mobile

O jogador consulta apenas `MovementInput.get_direction()`. Um joystick futuro deve enviar:

```gdscript
player.movement_input.set_virtual_direction(joystick_vector)
# Ao soltar ou cancelar o toque:
player.movement_input.clear_virtual_direction()
```

O vetor é limitado a comprimento 1 e preserva intensidade analógica. Input virtual ativo tem prioridade sobre o teclado; ao liberar, o teclado volta a funcionar. A perda de foco limpa o estado virtual. As habilidades futuras podem usar novas ações no Input Map, sem acoplar toque ao combate ou à física.

## Ambiente na nuvem

Use o checkout existente em `/workspace/Tiny-Kingdom`. Cada tarefa já possui ambiente isolado: não crie outro worktree a menos que o usuário peça.

Godot 4.6.3 está disponível como `godot`. Não existem serviços, bancos de dados, plugins ou pacotes de terceiros a instalar para executar o MVP. Em um shell cujo diretório pessoal seja somente leitura, use diretórios XDG graváveis fora do repositório:

```sh
export XDG_CACHE_HOME=/workspace/.tiny-kingdom/cache
export XDG_DATA_HOME=/workspace/.tiny-kingdom/data
export XDG_CONFIG_HOME=/workspace/.tiny-kingdom/config
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
cd /workspace/Tiny-Kingdom
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd --fixed-fps 60
godot --headless --path . --quit-after 180 --fixed-fps 60
```

Para desenvolvimento interativo, execute `godot --editor --path .` ou `godot --path .` em um desktop com display disponível. Não há servidor web a iniciar. Processos de editor/jogo precisam ser iniciados novamente em uma nova sessão.

O diretório `.godot/` é gerado e ignorado. Arquivos `.gd.uid` pertencem ao versionamento, pois identificam scripts de forma estável. Não versione exportações, credenciais ou chaves de assinatura.
