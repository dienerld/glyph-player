# Glyph Player

App desktop (Flutter, Linux e Windows) que lê a lista M3U_plus do próprio usuário: Ao vivo, Filmes e Séries. Dados só locais (SQLite). Interface, README, changelog e site em pt-BR; commits em inglês (Conventional Commits).

Produto e direção visual: `PRODUCT.md`, `docs/design/DIRECTION.md` (tokens Glyph, Fraunces + Manrope, um único destaque roxo, sem gradiente em texto/botão). Specs e planos em `docs/superpowers/`.

## Comandos

```bash
flutter pub get
flutter analyze && flutter test        # rodar os dois antes de todo commit
flutter run -d linux                   # ou -d windows
flutter build linux --release          # depois: linux/install_desktop.sh
```

## Arquitetura

- `lib/data/`: parser M3U, `database.dart` (SQLite + FTS5; `Db.setting/setSetting` guarda as preferências), importador em Isolate, `updater.dart` (verifica e aplica atualização), `natural_compare.dart`.
- `lib/state/providers.dart`: todos os providers Riverpod. Lista nova que depende da importação precisa entrar na lista de `invalidate` do `ImportController`.
- `lib/features/`: `live`, `movies`, `series`, `settings`, `shell`, `shared`. Player ao vivo em `lib/player/player_page.dart`; filmes/séries em `features/movies/vod_player_page.dart`. Atalhos de teclado ficam nos dois (controles do media_kit e `CallbackShortcuts`).
- Regras que não são óbvias: canais saem em ordem natural por nome, com as variantes de qualidade juntas (`channelCompare` em `Db.channels`); recentes guardam só os 20 últimos por tipo (`recentsLimit`); a lista lateral do player abre pela borda direita após 300 ms.
- O player usa `media_kit` (nativo): não há teste de widget do `PlayerPage`. Mudança de player só se confirma abrindo o app.

## Fluxo de trabalho

- Nunca commitar direto na `main`: criar branch (`feat/…`, `fix/…`, `chore/…`), commitar e fazer merge `--no-ff` na `main`.
- Não versionar `duplicados-series.csv` (arquivo solto do usuário), listas `*.m3u*`, nem `.playwright-mcp/` (capturas de teste).
- O repositório é **público**: nada de credenciais, URLs de lista ou dados do usuário em código, testes, docs ou commits.
- Texto público (README, site, changelog) não cita outros projetos ou produtos como referência.

## Mudou algo visível ao usuário? Atualize o site

Ao entregar funcionalidade, atalho, fluxo de instalação ou de atualização, mexa no **mesmo commit/branch** em: `README.md` (tabela de atalhos, instalação), `CHANGELOG.md` e `site/` (`index.html`, e `app.js` se o fluxo da demonstração mudou). A demonstração do hero tem de espelhar o app (Categorias → grade de canais → player). O Pages (`.github/workflows/pages.yml`) publica sozinho a cada push na `main` que toque `site/**`; o número da versão no site vem da API do GitHub, não é editado à mão.

Site em https://dienerld.github.io/glyph-player/ (HTML/CSS/JS puros, sem build). Para testar: `cd site && python3 -m http.server 8765`. Ao encerrar o servidor use `fuser -k 8765/tcp` (não `pkill -f`, que mata o próprio shell).

## Release

1. Branch `chore/release-X.Y.Z`: subir `version` no `pubspec.yaml` (`X.Y.Z+N`, incrementar N), `pkgver` em `linux/arch/PKGBUILD` e a seção `## X.Y.Z - AAAA-MM-DD` no `CHANGELOG.md` (o workflow falha sem ela).
2. Merge na `main`, `git tag vX.Y.Z`, `git push origin main vX.Y.Z`. A tag tem de bater com o `pubspec.yaml`.
3. `release.yml` analisa, testa, gera `.tar.gz`, `.deb`, `setup.exe` e `.zip` e publica (~12 min). `FLUTTER_VERSION` no workflow deve acompanhar o Flutter local.
4. Atualização automática: o app consulta `releases/latest`. Linux em pasta do usuário (`linux/install.sh`) troca os próprios arquivos; Windows instalado roda o `setup.exe` em modo silencioso; `.deb`, Arch e `.zip` só abrem a página. O caminho do Windows nunca foi testado.

## Ferramentas

- `.impeccable/config.json` guarda os ignores do detector de design (compartilhado); registrar novos com `impeccable hooks ignore-value` e explicar o motivo.
- `.agents/skills/` e `skills-lock.json` são de terceiros: não editar.
