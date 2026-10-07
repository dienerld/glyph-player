# Glyph Player

Player de IPTV para desktop (Linux e Windows) que lê a **sua própria lista M3U_plus**, mesmo com 50 MB ou mais, sem travar quando a lista é atualizada. Um produto da Glyph.

Tudo fica na sua máquina: sem conta, sem API remota, sem EPG. O app só se conecta ao que a sua lista aponta: a própria lista, as miniaturas e os streams.

## O que faz

- **Ao vivo:** canais por categoria, busca, recentes, favoritos, troca de canal com ↑/↓ e painel lateral de canais. Entradas "ao vivo" que na verdade são vídeos permitem avançar e voltar 10 s com ← e →.
- **Filmes:** escolha a categoria e veja a grade de filmes (título, ano e etiquetas como 4K), busca, favoritos, "Continuar assistindo" e retomada de onde parou.
- **Séries:** agrupadas por distribuidora (Netflix, Disney+, Globoplay…) e depois série → temporada → episódio. Favoritos, "Continuar assistindo", episódio anterior/próximo e auto-avançar ("A seguir" no último minuto).
- **Listas que você controla:** remova itens de "Recentes" e "Continuar assistindo" (em filmes e séries o ponto de retomada é preservado e o item volta se você assistir de novo); conteúdo adulto fica oculto por padrão.
- **Atualização sem travar:** o download e a leitura da lista rodam fora da interface e gravam num banco local (SQLite com busca FTS5).

## Rodando

Requisitos: Flutter estável (3.41+), `libmpv` do sistema (no Arch, o pacote `mpv`) e, no Linux, `libsecret` para guardar a URL com segurança.

```bash
flutter pub get
flutter run -d linux      # ou: -d windows
```

Na primeira abertura, vá em **Configurações**, cole a URL da sua lista M3U_plus e toque em **Salvar e atualizar**. A URL contém credenciais e fica no cofre de senhas do sistema, nunca em arquivo do projeto.

### Atalhos

| Onde | Tecla | Ação |
| --- | --- | --- |
| Ao vivo | ↑ / ↓ | canal anterior / próximo |
| Ao vivo | `L` | abrir/fechar a lista de canais |
| Filmes, séries e vídeos no Ao vivo | ← / → | voltar / avançar 10 s |
| Filmes e séries | ↑ / ↓ | volume |
| Séries | `P` / `N` | episódio anterior / próximo |
| Todos | espaço, `M`, `Esc` | pausar, mudo, voltar |

## Build

```bash
flutter build linux --release
linux/install_desktop.sh      # ícone e atalho no menu (usuário atual, sem sudo)

flutter build windows --release
```

Instaladores (rodam depois do build):

```bash
tool/package_deb.sh X.Y.Z                                   # Linux: build/glyph-player_X.Y.Z_amd64.deb (/opt, /usr/bin, menu)
(cd linux/arch && makepkg -si)                              # Arch: pacote a partir do .tar.gz da release (pkgver no PKGBUILD)
iscc /DAppVersion=X.Y.Z windows\installer\glyph_player.iss  # Windows: build\installer\*-setup.exe (Arquivos de Programas)
```

O `install_desktop.sh` é o que faz o desktop Linux (principalmente no Wayland) mostrar o nome e o ícone do app na barra de tarefas.

## Releases

Cada tag `vX.Y.Z` dispara o workflow `.github/workflows/release.yml`: analisa, testa, gera os pacotes de Linux (`.deb` e `.tar.gz`) e Windows (instalador `-setup.exe` e `.zip`) e publica tudo numa release do GitHub, com as notas tiradas do `CHANGELOG.md`. A versão da tag precisa ser igual à do `pubspec.yaml`.

```bash
# 1. suba a versão em pubspec.yaml e acrescente a seção "## X.Y.Z" no CHANGELOG.md
# 2. depois do commit na main:
git tag -a vX.Y.Z -m "Glyph Player X.Y.Z"
git push origin main vX.Y.Z
```

Pelo botão "Run workflow" do GitHub (`workflow_dispatch`) dá para gerar os pacotes sem publicar release.

## Testes

```bash
flutter analyze
flutter test
```

Para medir a importação com uma lista real (ela não faz parte do repositório):

```bash
GLYPH_REAL_LIST=/caminho/da/lista.m3u flutter test test/data/import_responsiveness_test.dart
```

## Estrutura

```
lib/data/        parser M3U, banco SQLite, importador (Isolate), cache de miniaturas
lib/state/       providers (Riverpod)
lib/features/    live, movies, series, settings, shell
lib/ui/          tema e tokens
docs/            especificações, planos e direção visual
assets/icon/     ícone (SVG-fonte); tool/build_icons.sh gera PNG e .ico
```

## Privacidade

- A URL da lista fica no cofre do sistema (libsecret no Linux, Credential Manager no Windows).
- O banco (`glyph.db`) e as miniaturas ficam nas pastas de dados e de cache do usuário. O banco guarda as URLs de stream da sua lista, que podem conter credenciais: não o compartilhe nem o versione.
- Listas `*.m3u` e `*.m3u8` estão no `.gitignore`.

## Ícone e marca

O ícone usa a gema da identidade Glyph, sem alterações, sobre o fundo `#17131C`. Os SVGs-fonte estão em `assets/icon/`; para regenerar os tamanhos, rode `tool/build_icons.sh`.
