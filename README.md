# Tiny Kingdom

Tiny Kingdom é um RPG 2D mobile em pixel art que mistura exploração, combate, coleta de recursos, evolução de personagem, construção de vila e defesa contra ondas de inimigos.

**Explore → Fight → Loot → Upgrade → Defend → Expand**

**Status: Fases 1 e 2 implementadas — combate e vila com progressão persistente.** A versão atual usa formas desenhadas pelo Godot, sem sprites externos. Construções funcionais e defesa por ondas ainda pertencem às próximas etapas.

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
| Depósito, saída e retorno | **E**, próximo ao objeto indicado |
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

## Salvamento local

O save **JSON versão 1** é criado automaticamente em **`user://save.json`**. Ele armazena madeira/pedra/ouro depositados, nível, XP, vida máxima, dano e expedições concluídas.

- XP e atributos são salvos quando a progressão muda; depósitos e retornos também salvam.
- Recursos carregados existem somente na memória. **Fechar o jogo antes de depositar também perde a carga**, mesmo se você já tiver retornado à vila. Ao reabrir, você sempre começa na vila.
- A gravação usa um arquivo temporário seguido de renomeação. Se o depósito não puder ser salvo, a transferência é desfeita e a carga permanece com o jogador. A HUD informa a falha.
- JSON inválido ou dados fora do formato geram um backup `save.json.corrupt-*` e um novo save padrão. Se o backup não puder ser criado, a gravação fica bloqueada para preservar o arquivo.
- Uma versão de save desconhecida é preservada, com aviso e gravação bloqueada. Não há migrações antigas nesta primeira versão.
- **F9 + confirmação** apaga o save atual, restaura os valores padrão e cria um novo save. Backups de arquivos corrompidos são mantidos.

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
│   └── ui/HUD.tscn
├── scripts/
│   ├── player/{player,movement_input,interaction_controller}.gd
│   ├── enemies/enemy.gd
│   ├── systems/{main,world,village,interactable,game_state,save_system}.gd
│   └── ui/hud.gd
├── tests/{smoke_test,progression_test,persistence_probe}.gd
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
godot --headless --path . --quit-after 180 --fixed-fps 60
```

- `smoke_test.gd`: regressão de input, física, combate, progressão, HUD e retorno após morte.
- `progression_test.gd`: arquivos reais, validação/corrupção, falha de gravação, depósito, transições, morte e reset. Também inicia **outro processo do Godot** para verificar a reabertura do progresso.
- Ambos usam arquivos exclusivos em `user://tests/`, sem tocar no save do jogador. `persistence_probe.gd` é um auxiliar chamado pela suíte, não um comando separado de teste.
- Os testes imprimem os totais e retornam código diferente de zero em caso de falha. O comando final é uma inicialização real da vila e pode criar o save padrão se ele não existir.

## Limitações e próximos passos

A vila possui praça, depósito, portal e espaços visuais reservados. Ainda não há construção funcional, crafting, equipamentos, NPCs complexos, quests, ondas, multiplayer ou backend. Árvores e pedras são decorativas; inimigos usam perseguição direta. O mapa de exploração é fixo e renova os inimigos a cada saída.

O save tem um único slot local, sem nuvem ou sincronização entre dispositivos. O progresso temporário da expedição não é retomado após fechar. Joystick visual, áudio, pixel art final e exportação Android permanecem pendentes.

Próxima etapa: **Fase 3 — Construções**, começando por posicionamento e custos usando o estoque da vila. Consulte [ROADMAP.md](docs/ROADMAP.md).
