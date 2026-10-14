# Tiny Kingdom

Tiny Kingdom é um RPG 2D mobile em pixel art que mistura exploração, combate, coleta de recursos, evolução de personagem, construção de vila e defesa contra ondas de inimigos.

**Explore → Fight → Loot → Upgrade → Defend → Expand**

Esta é a primeira versão jogável do combate, desenvolvida para desktop. A direção visual final será pixel art; por enquanto, todos os elementos são formas desenhadas pelo Godot, sem sprites, plugins ou downloads adicionais.

## Tecnologias e requisitos

- **Godot 4.6.3 Standard**, com GDScript; não requer a edição .NET.
- Jogo 2D com renderizador **Compatibility** (OpenGL), adequado a hardware modesto.
- Resolução base de **1280 × 720**, janela redimensionável e orientação paisagem preparada para mobile.
- Git e GitHub para versionamento. Nenhuma dependência npm, Python ou serviço externo é necessária para jogar.
- Desktop com suporte ao renderizador Compatibility. Android ainda não é um alvo validado.

## Abrir e rodar

1. Clone este repositório: `git clone https://github.com/jvrov/Tiny-Kingdom.git`.
2. Abra o Godot 4.6.3, escolha **Importar** e selecione `Tiny-Kingdom/project.godot`.
3. Abra o projeto e pressione **F6** com `Main.tscn` aberta, ou **F5** para executar a cena principal configurada.

Pelo terminal, com o executável `godot` no PATH:

```sh
cd Tiny-Kingdom
godot --editor --path .   # abrir o editor
godot --path .           # executar diretamente
```

No Windows, use o caminho do executável do Godot no lugar de `godot`, se necessário. No macOS, o executável fica dentro de `Godot.app/Contents/MacOS/Godot`.

## Controles e objetivo

| Ação | Controle |
| --- | --- |
| Movimentar em 8 direções | **W / A / S / D** ou **setas** |
| Atacar | Automático contra o inimigo mais próximo, dentro do círculo de alcance |
| Recomeçar a expedição | **R**, ou botão após vitória/derrota |

Você começa no terreno reservado à futura vila. Explore a leste e derrote os **12 errantes** da clareira. Eles perseguem o jogador ao se aproximar e atacam periodicamente: mova-se para evitar cercos. O objetivo termina ao eliminar todos os inimigos; morrer permite reiniciar.

## Implementado

- Jogador `CharacterBody2D` azul com câmera, colisão, movimento normalizado e velocidade configurável.
- Inimigos vermelhos com detecção, perseguição, distância de parada, vida e cooldown de ataque.
- Combate automático com seleção do alvo mais próximo e efeito visual de golpe.
- XP, níveis, aumento de vida máxima/dano e cura ao subir de nível.
- Estoque de madeira, pedra e ouro; inimigos podem conceder recursos diretamente ao morrer.
- HUD reativo com vida, XP, nível, dano, recursos e objetivo.
- Mapa de 2600 × 1800 com limites físicos, árvores, pedras, trilha e demarcação da futura vila.
- Telas de vitória/derrota e reinício completo da partida.
- Input desacoplado, com API para um futuro joystick virtual.
- Testes de integração executáveis no próprio Godot, sem dependências externas.

### Regras iniciais

O jogador começa com **100 de vida**, **18 de dano**, **115 px de alcance**, **230 px/s** e **0,65 s** entre ataques. Cada inimigo possui **36 de vida**, concede **15 XP**, causa **8 de dano** a cada **1,1 s** e tem **65%** de chance de conceder de **1 a 3** unidades de um recurso aleatório.

XP para o próximo nível: `30 + (nível - 1) × 20`. Cada nível adiciona **15 de vida máxima**, **4 de dano** e cura até **25 de vida**, limitada ao máximo. XP excedente é preservado e pode conceder vários níveis. Recursos e progressão duram apenas a partida atual.

## Estrutura

```text
Tiny-Kingdom/
├── assets/                 # pastas reservadas para futura arte
│   ├── characters/
│   ├── enemies/
│   ├── environment/
│   └── ui/
├── scenes/
│   ├── main/Main.tscn
│   ├── player/Player.tscn
│   ├── enemies/Enemy.tscn
│   ├── world/World.tscn
│   └── ui/HUD.tscn
├── scripts/
│   ├── player/             # jogador e fonte de input
│   ├── enemies/            # IA, dano e recompensas
│   ├── systems/            # mapa e ciclo da expedição
│   └── ui/                 # HUD e resultados
├── tests/smoke_test.gd
├── docs/
│   ├── DEVELOPMENT.md
│   └── ROADMAP.md
├── project.godot
├── README.md
└── .gitignore
```

## Validação

Execute a importação antes dos testes para registrar as classes GDScript:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd --fixed-fps 60
godot --headless --path . --quit-after 180 --fixed-fps 60
```

A suíte exercita cenas reais, movimento/física, limites do mapa, alvos e cooldowns, morte, XP, recursos, HUD, vitória e reinício. Imprime o total de verificações e encerra com código diferente de zero se houver falhas. O último comando inicia a cena principal por 180 frames; testes headless não substituem uma revisão visual nem testes em dispositivo Android.

## Status e limitações

**MVP de combate implementado.** Não há salvamento, coleta física, mineração/corte de árvores, construções funcionais, ondas recorrentes, equipamentos, skills, áudio ou pixel art final. Árvores e pedras são decorativas e não bloqueiam o movimento. Os inimigos usam perseguição direta, sem navegação por obstáculos.

O mapa contém um grupo fixo de inimigos, sem respawn. A área da vila é somente uma marcação visual, sem proteção contra ataques. Joystick e botões mobile ainda não têm interface; o adaptador de input já aceita vetores analógicos. Exportação APK exige uma etapa futura com templates, SDK/JDK, assinatura e testes em aparelho.

## Roadmap resumido

Combate → vila → construções → inventário/equipamentos → skills → novos mapas → bosses → mobile/polimento → APK beta.

Veja [o roadmap completo](docs/ROADMAP.md) e [as notas de desenvolvimento](docs/DEVELOPMENT.md).
