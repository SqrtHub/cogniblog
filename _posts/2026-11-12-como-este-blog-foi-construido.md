---
layout: post
title: "Como este blog foi construído com Jekyll e GitHub Pages"
date: 2026-11-12 09:00:00 -0300
categories: [tecnologia]
tags: [jekyll, github-pages, markdown]
---

Este blog é um site estático gerado pelo [Jekyll](https://jekyllrb.com/) e
hospedado gratuitamente no [GitHub Pages](https://pages.github.com/).

## Por que um site estático?

- **Rápido**: as páginas são HTML puro, servidas direto por CDN;
- **Seguro**: não há banco de dados nem servidor de aplicação para atacar;
- **Simples**: cada post é um arquivo Markdown versionado no Git.

## Como publicar um novo post

1. Crie um arquivo em `_posts/` no formato `AAAA-MM-DD-titulo-do-post.md`;
2. Adicione o cabeçalho (*front matter*):

   ```yaml
   ---
   layout: post
   title: "Título do post"
   date: 2026-11-12 09:00:00 -0300
   categories: [tecnologia]
   ---
   ```

3. Escreva o conteúdo em Markdown;
4. Faça `git commit` e `git push`. O GitHub Pages gera e publica o site
   automaticamente.

## Testando localmente

```bash
bundle install
bundle exec jekyll serve
```

Depois é só abrir `http://localhost:4000` no navegador.
