# Tiny Kingdom

Tiny Kingdom é um RPG 2D mobile em pixel art que mistura exploração, combate, coleta de recursos, evolução de personagem, construção de vila e defesa contra ondas de inimigos.

**Explore → Fight → Loot → Upgrade → Defend → Expand**

**Status: Fases 1 a 3 implementadas — combate, progressão persistente e três construções funcionais.** A versão atual usa formas desenhadas pelo Godot, sem sprites externos. Defesa por ondas permanece fora desta etapa.

## Tecnologias e requisitos

- **Godot 4.6.3 Standard**, GDScript e renderizador **Compatibility** (OpenGL).
- Jogo 2D, resolução base **1280 × 720**, janela redimensionável e orientação paisagem.
- Git/GitHub. Sem plugins, backend, banco de dados ou dependências de terceiros.
- Desenvolvimento e execução em desktop. Android/APK ainda não foi validado.

## Abrir e rodar

1. Clone: `git clone https://github.com/jvrov/Tiny-Kingdom.git`.
2. No Godot 4.6.3, escolha **Importar** e selecione `Tiny-Kingdom/project.godot`.
3. Pressione **F5**. O jogo começa na vila, carregando o progresso salvo.

Pelo terminal, com `godot` no PATH:

```sh
cd Tiny-Kingdom
godot --editor --path .   # abrir o editor
godot --path .           # executar o jogo
```

No Windows, use o caminho do executável se necessário. No macOS, ele fica em `Godot.app/Contents/MacOS/Godot`. A cena principal continua sendo `scenes/main/Main.tscn`.

## Controles

| Ação | Controle |
| --- | --- |
| Movimento em 8 direções | **WASD / setas** |
| Depósito, saída, retorno e construções | **E**, próximo ao objeto indicado |
| Confirmar construção/melhoria | **Enter** ou botão do painel |
| Fechar painel | **Esc** ou Cancelar/Fechar |
| Ataque | Automático contra o inimigo mais próximo dentro do alcance |
| Reset de desenvolvimento | **F9**, seguido de confirmação explícita |

F9 funciona no editor/binário de desenvolvimento e em exportações debug. É ignorado em exportações release. A confirmação pausa o jogo; cancelar não altera o progresso. **R não reinicia mais a partida**, para evitar apagar ou abandonar o progresso acidentalmente. O input continua preparado para joystick e botão de interação mobile.

## Loop jogável

**Vila → Expedição → Combate → Recursos → Retorno → Depósito → Nova expedição**

1. Na vila, veja o estoque **Armazenado**, seu nível e as expedições concluídas.
2. Aproxime-se do portal à direita e pressione **E** para iniciar uma expedição.
3. Explore a clareira e enfrente os 12 errantes. A HUD mostra os recursos **Carregando**.
4. Volte ao marco **VOLTAR À VILA**, no posto inicial da exploração, e pressione **E**. Você pode retornar antes de derrotar todos os inimigos.
5. Na vila, vá ao **DEPÓSITO**, à esquerda da praça, e pressione **E**. O estoque é atualizado e salvo automaticamente.
6. Inicie outra expedição. Os inimigos reaparecem; nível, XP, vida máxima e dano são mantidos.

Retornar vivo conta uma expedição concluída, mesmo sem limpar o mapa inteiro. A conclusão é contada somente uma vez por saída. O retorno restaura a vida, mas **não deposita os recursos automaticamente**. Enquanto houver recursos carregados, a próxima saída é bloqueada com uma mensagem para depositá-los primeiro.

Ao morrer, o jogo informa a falha e volta à vila após aproximadamente **2 segundos**, com vida restaurada. Você perde apenas os recursos carregados; estoque permanente, nível, XP, vida máxima e dano permanecem. Uma expedição perdida não aumenta o contador.

## Construções e evolução da vila

Os três terrenos têm posições fixas. Aproxime-se e pressione **E** para consultar descrição, custo e estoque. **Enter** ou o botão confirma; **Esc** cancela. O painel pausa o jogo.

| Construção | Madeira | Pedra | Ouro | Função |
| --- | --- | --- | --- | --- |
| Prefeitura | 20 | 15 | 5 | Eleva a vila de 0 para 1 e libera Ferreiro/Torre |
| Ferreiro | 15 | 20 | 8 | Libera três melhorias permanentes da arma |
| Torre de Arqueiros | 25 | 15 | 10 | Ataca automaticamente o inimigo mais próximo |

As estruturas têm nível máximo 1 nesta fase. No Ferreiro, a **arma** pode chegar ao nível 3:

| Melhoria da arma | Madeira | Pedra | Ouro | Dano adicional |
| --- | --- | --- | --- | --- |
| 1 | 10 | 15 | 5 | +3 |
| 2 | 20 | 30 | 10 | +4 |
| 3 | 30 | 45 | 15 | +5 |

O bônus acumulado máximo é **+12**, além dos aumentos por nível do personagem. Construir o Ferreiro não aplica uma melhoria automaticamente.

Somente recursos **Armazenados** são gastos. A compra salva um snapshot completo antes de atualizar o estado vivo: se a gravação falhar, estoque, construção e dano permanecem intactos. Compras repetidas de uma oferta já consumida são rejeitadas.

A Torre tem **300 px de alcance**, **10 de dano** e **1 segundo de cooldown**, configuráveis no Inspector, com uma linha de ataque. Ainda não há ondas na vila; a defesa é validada colocando inimigos próximos nos testes. Abates da Torre não concedem XP ou carga ao jogador.

## Salvamento local

O save **JSON versão 2** é criado automaticamente em **`user://save.json`**. Ele armazena madeira/pedra/ouro depositados, nível, XP, vida máxima, dano total, expedições concluídas, níveis/posições das construções e nível da arma.

- XP e atributos são salvos quando a progressão muda; depósitos e retornos também salvam.
- Recursos carregados existem somente na memória. **Fechar o jogo antes de depositar também perde a carga**, mesmo se você já tiver retornado à vila. Ao reabrir, você sempre começa na vila.
- A gravação usa um arquivo temporário seguido de renomeação. Se o depósito não puder ser salvo, a transferência é desfeita e a carga permanece com o jogador. A HUD informa a falha.
- JSON inválido ou dados fora do formato geram um backup `save.json.corrupt-*` e um novo save padrão. Se o backup não puder ser criado, a gravação fica bloqueada para preservar o arquivo.
- Saves v1 válidos são migrados automaticamente: todos os recursos, atributos e expedições são preservados; construções e arma começam no nível 0. O original é copiado para `save.json.v1-*.bak` antes da gravação. Falhas de backup/gravação preservam o original.
- O dano salvo já inclui o bônus da arma. Carregar o save atribui esse total, sem somar o bônus novamente.
- Uma versão de save desconhecida é preservada, com aviso e gravação bloqueada.
- **F9 + confirmação** apaga o save atual, restaura os valores padrão e cria um novo save. Construções e melhorias também são resetadas; backups de migração e corrupção são mantidos.

Localização padrão:

| Sistema | Caminho |
| --- | --- |
| Linux | `~/.local/share/godot/app_userdata/Tiny Kingdom/save.json` |
| Windows | `%APPDATA%\Godot\app_userdata\Tiny Kingdom\save.json` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Tiny Kingdom/save.json` |
| Ambiente cloud configurado | `/workspace/.tiny-kingdom/data/godot/app_userdata/Tiny Kingdom/save.json` |

No editor, **Projeto → Abrir pasta de dados do usuário** permite localizar a pasta real. O caminho pode variar com as configurações XDG do sistema.

## Estrutura e arquitetura

```text
Tiny-Kingdom/
├── assets/{characters,enemies,environment,ui}/
├── scenes/
│   ├── main/Main.tscn
│   ├── player/Player.tscn
│   ├── enemies/Enemy.tscn
│   ├── world/{World,Village}.tscn
│   ├── buildings/{Building,ArcherTower}.tscn
│   └── ui/{HUD,BuildingPanel}.tscn
├── scripts/
│   ├── player/{player,movement_input,interaction_controller}.gd
│   ├── enemies/enemy.gd
│   ├── systems/{main,world,village,interactable,game_state,save_system}.gd
│   ├── buildings/{building_data,building,archer_tower}.gd
│   └── ui/{hud,building_panel}.gd
├── tests/{smoke_test,progression_test,building_test,persistence_probe}.gd
├── docs/{DEVELOPMENT,ROADMAP}.md
├── project.godot
└── .gitignore
```

`GameState` é o Autoload central. `SaveSystem` cuida de arquivos/validação. `Main` troca os mapas mantendo um único jogador e HUD. Os objetos interagíveis emitem ações; `InteractionController` escolhe o mais próximo e recebe o input. Mais detalhes em [DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Combate preservado

Movimento normalizado, câmera, colisão, perseguição e ataque com cooldown continuam ativos. O jogador começa com **100 de vida**, **18 de dano**, **115 px de alcance**, **230 px/s** e **0,65 s** entre ataques. Cada inimigo tem **36 de vida**, concede **15 XP**, causa **8 de dano** a cada **1,1 s** e tem **65%** de chance de conceder **1 a 3** unidades de um recurso aleatório.

XP necessário: `30 + (nível - 1) × 20`. Cada nível adiciona **15 de vida máxima**, **4 de dano** e cura até **25 de vida**, limitada ao máximo. XP excedente é preservado.

## Testes

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd --fixed-fps 60
godot --headless --path . --script res://tests/progression_test.gd --fixed-fps 60
godot --headless --path . --script res://tests/building_test.gd --fixed-fps 60
godot --headless --path . --quit-after 180 --fixed-fps 60
```

- `smoke_test.gd`: regressão de input, física, combate, progressão, HUD e retorno após morte.
- `progression_test.gd`: arquivos reais, validação/corrupção, falha de gravação, depósito, transições, morte e reset. Também inicia **outro processo do Godot** para verificar a reabertura do progresso.
- `building_test.gd`: migração v1 → v2, custos, pré-requisitos, UI, falhas de gravação, melhorias, Torre e reabertura em processos separados.
- **219 verificações: 57 de combate + 77 de progressão + 85 de construções.**
- As três suítes usam arquivos exclusivos em `user://tests/`, sem tocar no save do jogador. `persistence_probe.gd` é um auxiliar chamado pela suíte, não um comando separado de teste.
- Os testes imprimem os totais e retornam código diferente de zero em caso de falha. O comando final é uma inicialização real da vila e pode criar o save padrão se ele não existir.

## Limitações e próximos passos

A vila possui praça, depósito, portal e três construções fixas. Ainda não há posicionamento livre, casas, muralhas, vida das estruturas, crafting, equipamentos, NPCs complexos, quests, ondas, multiplayer ou backend. Árvores e pedras são decorativas; inimigos usam perseguição direta. O mapa de exploração é fixo e renova os inimigos a cada saída.

O save tem um único slot local, sem nuvem ou sincronização entre dispositivos. O progresso temporário da expedição não é retomado após fechar. Joystick visual, áudio, pixel art final e exportação Android permanecem pendentes.

Próxima etapa recomendada: **Fase 4 — Inventário e equipamentos**, começando por um inventário simples com persistência. Consulte [ROADMAP.md](docs/ROADMAP.md).
