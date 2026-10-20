# Metadados do TMDB (poster, nota e resumo)

## Intenção

A lista M3U do usuário quase não traz poster de filme (na lista de quem pediu, 35 de 17.367). Séries trazem, filmes não. O usuário quer poster, nota e resumo nos filmes e, nas séries, nota e resumo, buscando no TMDB com a **chave de API do próprio usuário**.

## Metas

- Filmes: poster no card, nota no card, e uma **tela de detalhes** (poster, título, ano, nota, resumo, botão "Assistir") entre o card e o player.
- Séries: nota e resumo na página da série (`series_page.dart`). O poster do card continua o da lista; se a lista não trouxer, usa o do TMDB.
- Sem chave configurada, o app se comporta exatamente como hoje (card tipográfico, toque abre o player).
- Dados só locais por padrão: nada sai da máquina sem a chave. Com a chave, só **título e ano** são enviados ao TMDB.

## Não-metas / anti-metas

- Nada de busca em lote da biblioteca inteira (17 mil filmes): só o que aparece na tela ou é aberto.
- Sem chave embutida no app ou no repositório (público). Sem conta, login ou servidor nosso.
- Sem elenco, trailer, recomendações ou outros campos do TMDB.
- Não alterar o comportamento de Ao vivo.

## Decisões já tomadas pelo usuário

- Cada pessoa configura a própria chave nas Configurações.
- Busca sob demanda, cache local no SQLite, consulta uma vez por filme.
- Tela de detalhes com botão "Assistir" para filmes (o toque no card abre os detalhes, não o player).
- Esta tarefa é separada da busca/ordenação, já entregues na `develop`.

## Decisões minhas (o usuário pode trocar)

- Aceita a chave v3 (`api_key`) e o token v4 (`Bearer`, reconhecido por ser longo e começar com `eyJ`); o usuário cola qualquer um.
- A chave fica em `Db.setting`, em texto simples no banco local (mesmo nível de proteção da URL da lista).
- Consulta: `search/movie` com `query` = título limpo (`parseMovieTitle`), `year` quando houver, `language=pt-BR`. Séries: `search/tv`. Primeiro resultado vale; sem resultado, guarda "não encontrado" para não repetir a consulta (reexpira em 30 dias).
- Imagens: `w342` nos cards, `w500` nos detalhes, pelo `CachedThumb` já existente.
- Falha de rede ou chave inválida: nada quebra, o card cai no visual tipográfico e a falha **não** é gravada no cache. Chave inválida (401) mostra aviso nas Configurações ao testar.
- Botão "Testar chave" nas Configurações valida com uma chamada leve.
- Limite de concorrência: no máximo 4 consultas simultâneas; consulta só quando o card fica visível.
- Cache: tabela nova `tmdb_cache` (`kind`, `title_key`, `year`, `tmdb_id`, `poster`, `rating`, `overview`, `fetched_at`), criada na migração; limpar o cache vai no botão das Configurações.

## Restrições do projeto

Flutter Linux/Windows, UI em pt-BR, tokens Glyph (docs/design/DIRECTION.md), dependência `http` já existe. Providers em `lib/state/providers.dart`; preferências via `Db.setting`. Repositório público: nenhuma chave ou dado do usuário em código, testes ou docs. Atualizar README, CHANGELOG e `site/` no mesmo branch: o README e o site precisam avisar que, **com a chave**, os títulos vão ao TMDB e que o app usa a API do TMDB e exibe a atribuição exigida pelos termos deles ("This product uses the TMDB API but is not endorsed or certified by TMDB.", com logo se for exigido).

## Deixado ao implementador

- Estrutura dos módulos (cliente HTTP, repositório de cache, providers), nomes e layout fino da tela de detalhes dentro dos tokens Glyph.
- Como casar o primeiro resultado com o ano quando o ano não existe.
- Testes: cliente com `http` simulado, cache, e widget tests do fluxo com e sem chave. O player (media_kit) não tem teste de widget; não mudar o player.

## Esclarecimentos (após revisão do design)

Decisões minhas, marcadas para o usuário conferir:

- **Séries:** a chave da consulta é o `series_name` já extraído pelo app (`series_title.dart`), sem ano; o cache de série serve só a página da série, não temporadas nem episódios.
- **Quando consultar:** o cache é a fonte única. O card consulta ao ficar visível; a tela de detalhes lê o mesmo provider (e consulta se ainda não houver dado). Fila com no máximo 4 simultâneas; card que sai da tela antes de a consulta começar é descartado da fila.
- **Quais toques abrem os detalhes (com chave):** o card de filme na grade de categoria, nos resultados da busca e em Favoritos. "Continuar assistindo" e "Recentes" continuam abrindo o player direto, porque são retomadas. "Voltar" no player retorna aos detalhes. Sem chave, todos abrem o player como hoje.
- **Poster:** o da lista vence, o do TMDB entra quando a lista não traz. A nota aparece no card só depois de existir dado.
- **Cache:** `title_key` = título limpo passado por `foldTitle` (minúsculas, sem acento). Achado: nunca expira (o botão de limpar cache apaga). Não achado: linha com `tmdb_id` nulo, reexpira em 30 dias. Empate: o primeiro resultado, preferindo o de mesmo ano quando houver ano.
- **Banco:** `CREATE TABLE IF NOT EXISTS` no `_schema`, como as outras. A importação só mexe em `streams`, então o cache sobrevive a atualizações da lista.
- **Chave:** campo oculto com botão de mostrar, texto aparado antes de salvar; o reconhecimento do token v4 é uma heurística; "Testar chave" usa o endpoint `authentication`.
- **Aviso na tela:** ao lado do campo da chave, texto dizendo que, com a chave, os títulos são enviados ao TMDB. A atribuição ("This product uses the TMDB API…") aparece em Configurações e na tela de detalhes, como texto; o logo só entra se os termos do TMDB exigirem, e isso o implementador verifica antes de adicionar qualquer arquivo.
