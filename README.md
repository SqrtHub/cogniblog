# Blog CogniScion

Blog em Jekyll publicado via GitHub Pages em <https://blog.cogniscion.com>.

O tema é próprio (layouts, includes, CSS e JS neste repositório), sem dependências além do
`github-pages`. Não há scripts externos nem analytics. As fontes são servidas localmente.

## Rodar localmente

Requer Ruby 3.3 (o `github-pages` não suporta Ruby 4). Com mise: `mise exec ruby@3.3 -- bundle install`.

```bash
bundle install
bundle exec jekyll serve
```

Acesse http://localhost:4000.

## Testes

Depois de gerar o site, rode as verificações estruturais (rotas sem data, idioma, canonical, hreflang,
seletor de idioma, robots, feeds, sitemap, JSON-LD, links internos, destaques e listas de cada idioma):

```bash
JEKYLL_ENV=production bundle exec jekyll build
bundle exec ruby tests/check_site.rb _site
```

Para testar também a parte em inglês com posts de teste (sintéticos, em `tests/fixtures/en`, nunca publicados):

```bash
tests/with_en_fixtures.sh /tmp/blog-en && cd /tmp/blog-en
JEKYLL_ENV=production bundle exec jekyll build && bundle exec ruby tests/check_site.rb _site
```

## Novo post

Crie `_posts/AAAA-MM-DD-titulo.md` com este front matter:

```yaml
---
title: "Título do post"
date: 2026-11-12 09:00:00 -0300
categories: [tecnologia]   # a primeira categoria vira o tema exibido e o filtro da home
# opcionais:
format: guide              # marca o post como guia passo a passo (padrão: post comum)
featured: true             # prefere este item no destaque da home
description: "Resumo curto para cards e mecanismos de busca."
---
```

- O `layout: post` é aplicado automaticamente.
- As URLs não têm data: o post fica em `/<slug>/` (o slug vem do nome do arquivo). A data continua no
  front matter, no nome do arquivo e nos metadados.
- Textos da interface, rótulos de temas e formatos (Guia/Post), por idioma, ficam em `_data/i18n.yml`.
- **Destaques da home:** à esquerda aparece o guia mais recente (`format: guide`). À direita, o post comum mais recente. Nos dois casos, um item com `featured: true` tem preferência. Enquanto não houver guia publicado, o espaço do guia mostra "Guias em preparação".
- A página `/guias/` lista apenas os posts com `format: guide`.
- **Inglês:** as páginas em inglês ficam em `en/` (`/en/`, `/en/guides/`, `/en/about/`, `/en/feed.xml`). Um post
  em inglês é a tradução de um post em português e traz no front matter:

  ```yaml
  lang: "en"
  locale: "en_US"
  permalink: "/en/<slug-em-ingles>/"
  translation_key: "<slug do post em português>"
  ```

  Cada página liga para o seu equivalente no outro idioma (seletor PT/EN e `hreflang`, com `x-default` na versão
  em português). Sem equivalente, a outra opção aparece desativada e explicada. As listas, os destaques, o
  "Leia também" e o feed de cada idioma mostram só os posts desse idioma. Os posts são publicados pelo
  CogniManager (que gera esse front matter); não edite os arquivos dele à mão.

## Créditos

Veja [`docs/CREDITS.md`](docs/CREDITS.md).
