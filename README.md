# Blog Cogniscion

Blog em Jekyll publicado via GitHub Pages em <https://blog.cogniscion.com>.

## Rodar localmente

Requer Ruby 3.3 (o `github-pages` não suporta Ruby 4). Com mise: `mise exec ruby@3.3 -- bundle install`.

```bash
bundle install
bundle exec jekyll serve
```

Acesse http://localhost:4000.

## Novo post

Crie `_posts/AAAA-MM-DD-titulo.md` com o front matter `layout: post`, `title` e `date`.
