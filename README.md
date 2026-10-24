# Glyph Player

Player de IPTV para desktop (Linux e Windows) que lê a **sua própria lista M3U_plus**, mesmo com 50 MB ou mais, sem travar quando a lista é atualizada. Um produto da Glyph. Página do produto: https://dienerld.github.io/glyph-player/

Tudo fica na sua máquina por padrão: sem conta, sem API remota, sem EPG. O app só se conecta ao que a sua lista aponta (a própria lista, as miniaturas e os streams) e ao GitHub, para verificar se há versão nova. Só se você colar uma chave do TMDB, ele também se conecta ao TMDB, como descrito em [Metadados do TMDB](#metadados-do-tmdb-opcional).

## O que faz

- **Ao vivo:** canais por categoria (as versões de um canal ficam juntas: SD, HD, FHD, 4K, H265), busca, recentes, favoritos, troca de canal com ↑/↓ e painel lateral de canais. Entradas "ao vivo" que na verdade são vídeos permitem avançar e voltar 10 s com ← e →.
- **Filmes:** escolha a categoria e veja a grade de filmes (título, ano e etiquetas como 4K), busca por qualquer trecho do título (em todas as categorias ou só na aberta), ordenação (recentes, A → Z, Z → A), favoritos, "Continuar assistindo" e retomada de onde parou. Com a chave do TMDB (opcional), mostra pôster e nota, e um clique no filme abre os detalhes com sinopse na própria grade, logo abaixo da linha dele.
- **Séries:** agrupadas por distribuidora (Netflix, Disney+, Globoplay…) e depois série → temporada → episódio. Busca e ordenação como nos filmes, favoritos, "Continuar assistindo", episódio anterior/próximo e auto-avançar ("A seguir" no último minuto). Com a chave do TMDB (opcional), mostra nota e sinopse.
- **Listas que você controla:** remova itens de "Recentes" e "Continuar assistindo" (em filmes e séries o ponto de retomada é preservado e o item volta se você assistir de novo); conteúdo adulto fica oculto por padrão.
- **Atualização sem travar:** o download e a leitura da lista rodam fora da interface e gravam num banco local (SQLite com busca FTS5).

## Instalação

Baixe a versão mais recente na página de [releases](https://github.com/dienerld/glyph-player/releases).

- **Linux (recomendado):** instala na sua pasta de usuário, sem `sudo`, e o app se atualiza sozinho (veja [Atualizações](#atualizações)).

  ```bash
  curl -fsSL https://raw.githubusercontent.com/dienerld/glyph-player/main/linux/install.sh | sh
  ```

  O script instala em `~/.local/share/glyph-player`, cria o comando `glyph_player` em `~/.local/bin` e o atalho no menu de aplicativos. Precisa de `libmpv` (no Arch, o pacote `mpv`) e `libsecret`.
- **Windows:** rode `glyph-player-X.Y.Z-windows-x64-setup.exe`. Instala em Arquivos de Programas, com atalho no Menu Iniciar e desinstalador. A versão portátil é o `.zip`: extraia e rode `glyph_player.exe`.
- **Debian/Ubuntu:** `sudo apt install ./glyph-player_X.Y.Z_amd64.deb` (instala em `/opt/glyph-player`).
- **Arch Linux:** baixe o `PKGBUILD` de `linux/arch/` e rode `makepkg -si` na pasta dele (instala em `/opt/glyph-player`).
- **Outras distros:** extraia o `.tar.gz`, rode `./glyph_player` e, para ter ícone e atalho no menu, `./linux/install_desktop.sh`.

Na primeira abertura, vá em **Configurações** e cole a URL da sua lista (veja [Rodando](#rodando)).

### Atualizações

Ao abrir, o app consulta o GitHub e, havendo versão nova, mostra um aviso no topo com **Atualizar e reiniciar**. Em **Configurações → Atualizações** você vê a versão atual e pode verificar na hora. Se não houver rede, nada é mostrado.

O que o botão faz depende de como o app foi instalado:

- **Instalado pelo script do Linux ou extraído numa pasta sua:** baixa a versão nova, troca os arquivos e reabre o app.
- **Windows instalado pelo `setup.exe`:** baixa o instalador e o executa em modo silencioso (o Windows pede a confirmação de administrador).
- **`.deb`, Arch ou `.zip` portátil:** o botão vira **Baixar** e abre a página da release; a atualização fica por sua conta ou do gerenciador de pacotes.

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
| Todos | espaço, `M`, `F`, `Esc` | pausar, mudo, tela cheia, voltar |

## Formatos de lista aceitos

O app reconhece dois padrões de M3U_plus. O tipo de cada entrada (Ao vivo, Filmes ou Séries) vem da URL do stream:

| Padrão | Exemplo de URL | Tipo |
|---|---|---|
| Com tipo no caminho | `http://host/live/usuario/senha/123.ts` | `/live/` ao vivo, `/movie/` filme, `/series/` série |
| Com token em `/play/` | `http://host/play/TOKEN/ts` | termina em `/ts`: ao vivo |
| Com token em `/play/` | `http://host/play/TOKEN` | sem `SxxExx` no nome: filme |
| Com token em `/play/` | `http://host/play/TOKEN` | com `SxxExx` no nome (ex.: `S02E27`): série |

No padrão `/play/`, o token da URL identifica a entrada. Como o caminho não informa o tipo de filmes e séries, o app usa o nome: um filme com `SxxExx` no título seria tratado como série, e uma série sem esse marcador aparece em Filmes. Entradas com outro formato de URL são ignoradas.

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

### Metadados do TMDB (opcional)

Sem chave, o app não envia nada ao TMDB. Para ver pôsteres, notas e sinopses, crie uma conta gratuita em [themoviedb.org](https://www.themoviedb.org/settings/api), gere uma chave de API e cole-a em **Configurações**. Com a chave:

- só os títulos e anos dos filmes e séries que você navega (grade, busca e Favoritos) são enviados ao TMDB;
- as respostas ficam em cache no banco local, e **Configurações → Limpar cache de metadados** apaga esse cache;
- Continuar assistindo e Recentes continuam abrindo o player direto.

This product uses the TMDB API but is not endorsed or certified by TMDB.

## Ícone e marca

O ícone usa a gema da identidade Glyph, sem alterações, sobre o fundo `#17131C`. Os SVGs-fonte estão em `assets/icon/`; para regenerar os tamanhos, rode `tool/build_icons.sh`.
