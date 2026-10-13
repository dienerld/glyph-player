# Changelog

## 0.4.1 - 2026-10-13

- **Tela cheia com `F`:** a tecla `F` entra e sai da tela cheia no Ao vivo e em filmes e séries, igual ao botão.

## 0.4.0 - 2026-10-13

Atualização automática.

- **Atualização automática:** ao abrir, o app verifica se há versão nova e mostra um aviso com **Atualizar e reiniciar**. Em **Configurações → Atualizações** você vê a versão atual e verifica na hora.
  - Instalado na sua pasta (script do Linux ou `.tar.gz` extraído): baixa, troca os arquivos e reabre.
  - Windows instalado pelo `setup.exe`: baixa e executa o instalador em modo silencioso.
  - `.deb`, Arch e `.zip` portátil: o botão abre a página da release.
- **Linux:** `linux/install.sh` instala na pasta do usuário, sem `sudo`, para o app poder se atualizar.
- **Player:** a lista de canais lateral só abre quando o mouse fica 300 ms na borda direita, sem cobrir o botão de tela cheia.
- **Recentes:** guarda só os 20 últimos canais; remover um não traz de volta os mais antigos.

## 0.3.0 - 2026-10-13

Ao vivo mais fácil de navegar.

- **Ao vivo:** seletor **Linhas | Categorias** (a escolha fica salva). Em Categorias, você escolhe a categoria/emissora primeiro e só então vê os canais.
- **Ordem dos canais:** ordem natural pelo nome (10, 11, 20, 100 em vez de 10, 100, 101, 20).
- **Mouse:** as linhas horizontais agora rolam arrastando com o mouse, não só no touchpad.
- **Player:** a lista lateral abre centralizada no canal que está tocando e acompanha a troca de canal.

## 0.2.0 - 2026-10-07

Instaladores.

- **Windows:** instalador `-setup.exe` (Arquivos de Programas, atalho no Menu Iniciar, desinstalador). O `.zip` continua como versão portátil.
- **Debian/Ubuntu:** pacote `.deb` (`/opt/glyph-player`, comando `glyph_player` e entrada no menu).
- **Arch Linux:** `PKGBUILD` em `linux/arch/`.

## 0.1.0 - 2026-10-06

Primeira versão.

- **Ao vivo:** canais por categoria, busca, recentes, favoritos, troca de canal com ↑/↓ e painel lateral. Entradas "ao vivo" que são vídeos permitem avançar e voltar 10 s.
- **Filmes:** categorias, grade por gênero, busca, favoritos, "Continuar assistindo" e retomada de onde parou.
- **Séries:** por distribuidora, depois série → temporada → episódio. Favoritos, "Continuar assistindo", episódio anterior/próximo e auto-avançar.
- **Listas:** remover itens de "Recentes" e "Continuar assistindo"; conteúdo adulto oculto por padrão.
- **Lista grande sem travar:** importação em segundo plano de listas M3U_plus de 50 MB ou mais, num banco local com busca.
- **Miniaturas salvas em disco** (limite de 400 MB).
- **Identidade Glyph:** ícone, paleta e fontes da marca.
- Linux e Windows. Dados só locais; a URL da lista fica no cofre de senhas do sistema.
