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

Depois de gerar o site, rode as verificações estruturais (rotas, canonical, robots, feed,
sitemap, JSON-LD, links internos, destaques da home):

```bash
JEKYLL_ENV=production bundle exec jekyll build
bundle exec ruby tests/check_site.rb _site
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
- Rótulos de temas ficam em `_data/categories.yml`. Os formatos (Guia/Post) ficam em `_data/formats.yml`.
- **Destaques da home:** à esquerda aparece o guia mais recente (`format: guide`). À direita, o post comum mais recente. Nos dois casos, um item com `featured: true` tem preferência. Enquanto não houver guia publicado, o espaço do guia mostra "Guias em preparação".
- A página `/guias/` lista apenas os posts com `format: guide`.
- O site está só em português. A opção EN aparece desativada até existirem traduções.

## Créditos

Veja [`docs/CREDITS.md`](docs/CREDITS.md).
