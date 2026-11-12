source "https://rubygems.org"

# Mantém o mesmo ambiente usado pelo GitHub Pages
gem "github-pages", "~> 232", group: :jekyll_plugins

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
end

# Necessário para `jekyll serve` em Ruby 3+
gem "webrick", "~> 1.8"

platforms :windows, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end
gem "wdm", "~> 0.1", platforms: [:windows]
