# frozen_string_literal: true

# Verificações estruturais do site gerado (inglês, o idioma padrão, na raiz; português em /pt/).
# Uso: bundle exec jekyll build && bundle exec ruby tests/check_site.rb [_site]
# Com posts em inglês de teste (tests/fixtures/en, nunca publicados): veja o README.

require "cgi"
require "date"
require "json"
require "nokogiri"
require "pathname"
require "yaml"

SITE = Pathname.new(ARGV[0] || "_site").expand_path
ROOT = Pathname.new(__dir__).join("..").expand_path
BASE_URL = "https://blog.cogniscion.com"
PRODUCT_URL = "https://cogniscion.com/"
SIGNUP_URL = "https://cogniscion.com/educator/signup"
CTA_LABEL = { "pt-BR" => "Teste o CogniScion", "en" => "Try CogniScion" }.freeze
I18N = YAML.safe_load(ROOT.join("_data/i18n.yml").read)
PT = "pt-BR"
EN = "en"

$failures = []
$checks = 0

def check(desc)
  $checks += 1
  ok = yield
  $failures << desc unless ok
  puts "#{ok ? 'ok  ' : 'FAIL'} #{desc}"
rescue StandardError => e
  $failures << desc
  puts "FAIL #{desc} (#{e.class}: #{e.message})"
end

def html(rel)
  Nokogiri::HTML(SITE.join(rel).read)
end

def front_matter(path)
  YAML.safe_load(path.read.split(/^---\s*$/, 3)[1], permitted_classes: [Date, Time]) || {}
end

def file_of(url)
  "#{url.delete_prefix('/')}index.html"
end

# Primeiro tema do post, como `post.categories | first` no Jekyll 3: os itens de `categories`
# (uma string é separada por espaços) vêm antes de `category`.
def topic_of(fm)
  cats = fm["categories"]
  cats = cats.split if cats.is_a?(String)
  (Array(cats) + Array(fm["category"])).compact.map(&:to_s).reject(&:empty?).first
end

# Posts publicados (a partir do repositório). Como o Jekyll, ignora `published: false` e,
# sem `future: true` no _config.yml, posts com data futura (agendados).
future = YAML.safe_load(ROOT.join("_config.yml").read)["future"] == true
all_posts = Dir[ROOT.join("_posts/*.md")].sort.map do |f|
  path = Pathname.new(f)
  fm = front_matter(path)
  y, m, d, slug = path.basename(".md").to_s.match(/\A(\d{4})-(\d{2})-(\d{2})-(.+)\z/).captures
  date = fm["date"].respond_to?(:to_time) ? fm["date"].to_time : Time.new(y.to_i, m.to_i, d.to_i)
  lang = fm["lang"] || PT
  url = lang == EN ? fm["permalink"].to_s : "/pt/#{slug}/"
  fm.merge("slug" => slug, "lang" => lang, "url" => url, "file" => file_of(url), "time" => date,
           "day" => fm["date"].respond_to?(:strftime) ? fm["date"].strftime("%Y-%m-%d") : "#{y}-#{m}-#{d}",
           "topic" => topic_of(fm))
end
all_posts.reject! { |p| p["published"] == false || (!future && p["time"] > Time.now) }
all_posts.sort_by! { |p| p["time"] }.reverse!
by_lang = { PT => all_posts.select { |p| p["lang"] == PT }, EN => all_posts.select { |p| p["lang"] == EN } }

# Equivalentes: um post em inglês aponta para o post em português pelo slug (translation_key).
peer_of = {}
by_lang[EN].each do |e|
  pt = by_lang[PT].find { |p| p["slug"] == e["translation_key"] }
  next unless pt

  peer_of[e["url"]] = pt["url"]
  peer_of[pt["url"]] = e["url"]
end
PAGE_PAIRS = { "/pt/" => "/", "/pt/guias/" => "/guides/", "/pt/sobre/" => "/about/" }.freeze
# Endereços da raiz que pertencem a páginas do site (um post em inglês com esse slug colidiria com elas).
RESERVED_ROOT = %w[pt en guides about feed assets 404 sitemap robots].freeze
PAGE_PAIRS.each { |a, b| peer_of[a] = b; peer_of[b] = a }

def lang_of_url(url)
  url.start_with?("/pt/") ? PT : EN
end

pages = Dir[SITE.join("**/*.html")].map { |f| Pathname.new(f).relative_path_from(SITE).to_s }.sort

# Rotas
%w[index.html about/index.html 404.html guides/index.html feed.xml sitemap.xml robots.txt CNAME
   pt/index.html pt/guias/index.html pt/sobre/index.html pt/feed.xml].each do |f|
  check("existe #{f}") { SITE.join(f).file? }
end
check("CNAME é blog.cogniscion.com") { SITE.join("CNAME").read.strip == "blog.cogniscion.com" }
all_posts.each do |p|
  check("post sem data na URL: #{p['url']}") { SITE.join(p["file"]).file? }
end
check("nenhuma rota com data (/AAAA/...)") do
  [SITE, SITE.join("pt")].all? { |dir| dir.children.none? { |c| c.directory? && c.basename.to_s =~ /\A\d{4}\z/ } }
end
check("nenhuma saída nem link no antigo prefixo /en/") do
  old = %r{(href="|<loc>|<id>|"url":"|"@id":"|"item": "|"url": ")(#{Regexp.escape(BASE_URL)})?/en/}
  !SITE.join("en").exist? && Dir[SITE.join("**/*.{html,xml}")].none? { |f| File.read(f) =~ old }
end
check("posts em português não têm mais endereço na raiz (sem alias nem redirecionamento)") do
  by_lang_pt = all_posts.select { |p| p["lang"] == PT }
  by_lang_pt.none? { |p| SITE.join(p["slug"]).exist? }
end
check("post em inglês: permalink do front matter é /<slug>/, na raiz") do
  all_posts.select { |p| p["lang"] == EN }.all? { |p| p["permalink"] == "/#{p['slug']}/" }
end
check("slug de post em inglês não colide com páginas da raiz") do
  all_posts.select { |p| p["lang"] == EN }.none? { |p| RESERVED_ROOT.include?(p["slug"]) }
end
check("nenhum link para URL com data") do
  dated = %r{(href="|<loc>|<id>|"url":"|"@id":"|"item": ")(#{Regexp.escape(BASE_URL)})?/(en/|pt/)?\d{4}/\d{2}/\d{2}/}
  Dir[SITE.join("**/*.{html,xml}")].none? { |f| File.read(f) =~ dated }
end
check("todos os posts no idioma certo (pt-BR ou en)") { all_posts.all? { |p| [PT, EN].include?(p["lang"]) } }
check("post em inglês sempre aponta para um post em português existente") { by_lang[EN].all? { |e| peer_of[e["url"]] } }
check("slugs únicos entre os idiomas") { all_posts.map { |p| p["slug"] }.uniq.size == all_posts.size }

# Indexação
check("robots.txt não bloqueia e aponta o sitemap") do
  r = SITE.join("robots.txt").read
  r !~ /^\s*Disallow:\s*\S/i && r.include?("Sitemap: #{BASE_URL}/sitemap.xml")
end
sitemap = Nokogiri::XML(SITE.join("sitemap.xml").read)
sitemap.remove_namespaces!
locs = sitemap.xpath("//loc").map(&:text)
check("sitemap inclui as páginas dos dois idiomas e todos os posts") do
  (PAGE_PAIRS.to_a.flatten + all_posts.map { |p| p["url"] }).all? { |u| locs.include?(BASE_URL + u) }
end
check("sitemap não inclui 404 nem feeds") { locs.none? { |u| u.include?("404") || u.end_with?(".xml") } }
{ PT => "pt/feed.xml", EN => "feed.xml" }.each do |lang, f|
  feed = nil
  check("#{f}: XML bem formado") { feed = Nokogiri::XML(SITE.join(f).read) { |c| c.strict } }
  next unless feed

  feed.remove_namespaces!
  entries = by_lang[lang].first(10)
  check("#{f}: em #{lang}, só com os posts desse idioma, do mais novo ao mais antigo, ids = URLs sem data") do
    feed.root["lang"] == lang &&
      feed.xpath("//entry/link/@href").map(&:text) == entries.map { |p| BASE_URL + p["url"] } &&
      feed.xpath("//entry/id").map(&:text) == entries.map { |p| BASE_URL + p["url"] } &&
      feed.xpath("//entry").all? { |e| e["lang"] == lang }
  end
  check("#{f}: título e resumo decodificados iguais ao texto do post (descrição ou primeiro parágrafo)") do
    feed.xpath("//entry").zip(entries).all? do |e, p|
      summary = CGI.unescapeHTML(e.at("summary").text)
      src = ROOT.join("_posts").children.find { |c| c.basename.to_s.end_with?("-#{p['slug']}.md") }.read
      first = src.split("{% raw %}\n", 2)[1].to_s.split("\n\n").first.to_s
      want = (p["description"] || first).split.join(" ")
      typo = ->(t) { CGI.unescapeHTML(t).tr("“”‘’", "\"\"''").gsub("–", "--").gsub("—", "---") }
      typo.call(e.at("title").text) == typo.call(p["title"]) && e.at("title")["type"] == "html" &&
        typo.call(summary) == typo.call(want) &&
        e.at("summary")["type"] == "html"
    end
  end
  check("#{f}: conteúdo decodificado contém a sequência ]]> quando o post a tem") do
    feed.xpath("//entry").zip(entries).all? do |e, p|
      body = ROOT.join("_posts").children.find { |c| c.basename.to_s.end_with?("-#{p['slug']}.md") }.read
      !body.include?("]]>") || CGI.unescapeHTML(e.at("content").text).include?("]]>")
    end
  end
end

# Por página
pages.each do |rel|
  doc = html(rel)
  url = rel == "404.html" ? "/404.html" : "/#{rel.delete_suffix('index.html')}"
  lang = lang_of_url(url)
  t = I18N[lang]
  peer = peer_of[url]
  check("#{rel}: sem noindex") { doc.css('meta[name="robots"], meta[name="googlebot"]').none? { |m| m["content"].to_s =~ /noindex|nofollow/i } }
  check("#{rel}: lang #{lang} e og:locale") do
    doc.at("html")["lang"] == lang && doc.at('meta[property="og:locale"]')["content"] == (lang == EN ? "en_US" : "pt_BR")
  end
  check("#{rel}: um canonical absoluto, igual a og:url e à URL da página") do
    c = doc.css('link[rel="canonical"]')
    c.size == 1 && (rel == "404.html" ||
                    (c.first["href"] == BASE_URL + url && doc.at('meta[property="og:url"]')["content"] == BASE_URL + url))
  end
  if peer
    check("#{rel}: hreflang recíproco (#{lang} ↔ #{lang_of_url(peer)}) e x-default em inglês") do
      alts = doc.css('link[rel="alternate"][hreflang]').to_h { |l| [l["hreflang"], l["href"]] }
      en_url = lang == EN ? url : peer
      other = html(file_of(peer)).css('link[rel="alternate"][hreflang]').to_h { |l| [l["hreflang"], l["href"]] }
      alts == { lang => BASE_URL + url, lang_of_url(peer) => BASE_URL + peer, "x-default" => BASE_URL + en_url } &&
        other == alts
    end
  else
    check("#{rel}: sem hreflang (não há equivalente)") { doc.css("link[hreflang]").empty? }
  end
  check("#{rel}: seletor de idioma com o atual marcado e o outro como link para o equivalente (ou desativado)") do
    cur = doc.at(".lang .is-current")
    other = doc.css(".lang .lang-opt").reject { |n| n == cur }
    cur && cur["lang"] == lang && cur.name == "span" && other.size == 1 &&
      (if peer
         other[0].name == "a" && other[0]["href"] == peer && other[0]["hreflang"] == lang_of_url(peer)
       else
         other[0].name == "span" && other[0]["href"].nil? && other[0]["class"].include?("is-disabled") && other[0].at(".sr-only")
       end)
  end
  check("#{rel}: sem 'em breve' falso no seletor") { doc.css(".lang").text !~ /em breve|coming soon/i }
  check("#{rel}: og:image absoluta") { doc.at('meta[property="og:image"]')&.[]("content").to_s.start_with?("#{BASE_URL}/") }
  check("#{rel}: um único h1") { doc.css("h1").size == 1 }
  check("#{rel}: títulos sem pular níveis") do
    levels = doc.css("h1, h2, h3, h4, h5, h6").map { |h| h.name[1].to_i }
    levels.first == 1 && levels.each_cons(2).all? { |a, b| b <= a + 1 }
  end
  check("#{rel}: navbar sem 'Sobre'/'About'") { doc.css(".site-nav a").none? { |a| a.text.strip =~ /sobre|about/i } }
  check("#{rel}: navbar no idioma da página (Blog, Guias/Guides, CTA)") do
    links = doc.css(".site-nav a").reject { |a| a["class"].to_s.include?("lang-opt") }.map { |a| [a.text.strip, a["href"]] }
    links == [[t["nav_blog"], t["home_url"]], [t["nav_guides"], t["guides_url"]], [CTA_LABEL[lang], SIGNUP_URL]] &&
      doc.at(".site-nav")["aria-label"] == t["nav_label"] && doc.at(".skip-link").text == t["skip_link"]
  end
  check("#{rel}: rodapé no idioma da página") do
    doc.css(".footer-links a").map { |a| a["href"] } == [t["about_url"], t["guides_url"], t["feed_url"], PRODUCT_URL] &&
      doc.at(".site-footer p").text == t["site_description"]
  end
  check("#{rel}: botões de ação com o texto exato e a criação de conta como destino") do
    nav = doc.css(".site-nav a.nav-cta")
    soft = doc.css(".soft-cta a")
    chrome = doc.css(".site-header, .soft-cta").text
    nav.map { |a| [a.text.strip, a["href"]] } == [[CTA_LABEL[lang], SIGNUP_URL]] &&
      (soft.empty? || (soft.map { |a| [a.text.strip, a["href"]] } == [[CTA_LABEL[lang], SIGNUP_URL]] &&
                       doc.at(".soft-cta")["aria-label"] == CTA_LABEL[lang])) &&
      chrome !~ /Conhe(c|ç)(er|a) a CogniScion|Discover CogniScion/
  end
  check("#{rel}: identidade da marca continua no site (rodapé e metadados), não no cadastro") do
    doc.css(".footer-links a").last["href"] == PRODUCT_URL &&
      doc.css('script[type="application/ld+json"]').none? { |s| s.text.include?("/educator/signup") }
  end
  check("#{rel}: feed do idioma no <head>") do
    doc.css('link[type="application/atom+xml"]').map { |l| l["href"] } == [BASE_URL + t["feed_url"]]
  end
  check("#{rel}: menu mobile com rótulos do idioma") do
    b = doc.at(".menu-btn")
    b["aria-label"] == t["menu_open"] && b["data-label-open"] == t["menu_open"] && b["data-label-close"] == t["menu_close"]
  end
  check("#{rel}: sem scripts ou CSS externos") do
    doc.css("script[src], link[rel=stylesheet]").all? { |n| (n["src"] || n["href"]).start_with?("/") }
  end
  check("#{rel}: sem links vazios ou '#'") { doc.css("a").all? { |a| a["href"].to_s.strip !~ /\A#?\z/ } }
  check("#{rel}: links internos existem") do
    doc.css("a[href^='/'], img[src^='/'], link[href^='/'], script[src^='/']").all? do |n|
      target = (n["href"] || n["src"]).sub(/[#?].*\z/, "")
      target += "index.html" if target.end_with?("/")
      SITE.join(target.delete_prefix("/")).file?
    end
  end
  check("#{rel}: sem marcas de mockup fora do texto dos artigos") do
    d = doc.dup
    d.css(".prose").each(&:remove)
    d.to_html !~ /proposta|ilustrativ|data-inert|toast|mockup|lorem/i
  end
  ld = doc.css('script[type="application/ld+json"]').map { |s| JSON.parse(s.text) }
  check("#{rel}: JSON-LD válido e sem Person") { ld.none? { |o| o.to_json.include?('"Person"') } }
  check("#{rel}: um único JSON-LD principal (WebSite/WebPage/BlogPosting)") do
    ld.count { |o| %w[WebSite WebPage BlogPosting].include?(o["@type"]) } == 1
  end
  crumbs = ld.find { |o| o["@type"] == "BreadcrumbList" }
  if crumbs
    check("#{rel}: BreadcrumbList começa no início do idioma") { crumbs["itemListElement"][0]["item"] == BASE_URL + t["home_url"] }
  end
end

# Início e guias de cada idioma
[PT, EN].each do |lang|
  t = I18N[lang]
  posts = by_lang[lang]
  guides = posts.select { |p| p["format"] == "guide" }
  regular = posts.reject { |p| p["format"] == "guide" }
  topics = posts.map { |p| p["topic"] }.compact.uniq.sort
  pick = ->(list) { list.find { |p| p["featured"].to_s == "true" } || list.first }
  home = html(file_of(t["home_url"]))
  h = "início #{lang}"
  fguide = home.at('[aria-labelledby="feat-guide-h"]')
  fpost = home.at('[aria-labelledby="feat-post-h"]')
  check("#{h}: textos no idioma") { home.at("#intro-h").text == t["home"]["title"] && home.at("#posts-h").text == t["home"]["posts"] }
  check("#{h}: espaço do guia em destaque sempre presente") { fguide }
  if guides.empty?
    check("#{h}: sem guia publicado, mostra 'em preparação' sem link de artigo") do
      fguide.at("h2").text.strip == t["home"]["guides_soon"] && fguide.css("a").map { |a| a["href"] } == [t["guides_url"]]
    end
  else
    check("#{h}: guia em destaque é o do idioma (featured: true ou o mais recente)") do
      fguide.at("h2 a")["href"] == pick.call(guides)["url"]
    end
  end
  if regular.empty?
    check("#{h}: sem post comum, não há destaque de post") { fpost.nil? }
  else
    check("#{h}: destaque de guia antes do destaque de post") { fguide.path < fpost.path }
    check("#{h}: post em destaque é o do idioma") { fpost.at("h2 a")["href"] == pick.call(regular)["url"] }
  end
  cards = home.css("[data-grid] .card")
  if posts.empty?
    check("#{h}: sem posts, mostra aviso e nenhuma grade, filtro ou mensagem de filtro") do
      home.at("#posts").text.include?(t["home"]["no_posts"]) &&
        home.at("[data-grid]").nil? && home.at("[data-filters]").nil? && home.at("[data-empty]").nil?
    end
  else
    check("#{h}: grade só com os posts do idioma, do mais novo ao mais antigo") do
      cards.map { |c| c.at("h3 a")["href"] } == posts.map { |p| p["url"] }
    end
    check("#{h}: títulos da grade iguais aos do front matter") { cards.map { |c| c.at("h3 a").text } == posts.map { |p| p["title"] } }
    check("#{h}: contagem e mensagem de filtro no idioma") do
      c = home.at("[data-count]")
      n = posts.size
      c.text == "#{n} #{n == 1 ? t['home']['count_one'] : t['home']['count_many']}" &&
        c["data-one"] == t["home"]["count_one"] && c["data-many"] == t["home"]["count_many"] && home.at("[data-empty]")
    end
    check("#{h}: datas e rótulos dos cards no idioma") do
      cards.zip(posts).all? do |c, p|
        m = p["time"].month - 1
        txt = if lang == EN
                "#{t['months_short'][m]} #{p['time'].day}, #{p['time'].year}"
              else
                "#{p['time'].day} #{t['months_short'][m]} #{p['time'].year}"
              end
        c.at("time").text == txt && c.at(".fmt").text == t["formats"][p["format"] == "guide" ? "guide" : "post"]["label"]
      end
    end
  end
  if topics.size > 1
    check("#{h}: filtros só com temas do idioma e ocultos sem JS") do
      chips = home.css("[data-filters] [data-filter]").map { |c| c["data-filter"] } - ["all"]
      home.at("[data-filters]").key?("hidden") && chips == topics
    end
  else
    check("#{h}: sem filtros com #{topics.size} tema(s)") { home.at("[data-filters]").nil? }
  end

  gdoc = html(file_of(t["guides_url"]))
  if guides.empty?
    check("guias #{lang}: estado vazio honesto, no idioma") do
      gdoc.text.include?(t["guides"]["empty_title"]) && gdoc.css(".card").empty?
    end
  else
    check("guias #{lang}: lista só os guias do idioma") do
      gdoc.css(".card").map { |c| c.at("h3 a")["href"] } == guides.map { |g| g["url"] }
    end
  end
end

# Posts
all_posts.each do |p|
  t = I18N[p["lang"]]
  doc = html(p["file"])
  check("#{p['url']}: título e data preservados") do
    doc.at("h1").text == p["title"] && doc.at(".byline time")["datetime"].start_with?(p["day"])
  end
  check("#{p['url']}: byline, data, tempo de leitura e trilha no idioma do post") do
    m = p["time"].month - 1
    date = if p["lang"] == EN
             "#{t['months'][m]} #{p['time'].day}, #{p['time'].year}"
           else
             "#{p['time'].day} de #{t['months'][m]} de #{p['time'].year}"
           end
    crumbs = doc.at("nav.crumbs")
    second = p["format"] == "guide" ? t["nav_guides"] : (t["categories"][p["topic"]] || p["topic"])
    doc.at(".byline time").text == date && doc.at(".byline").text.include?("#{t['by']} CogniScion") &&
      doc.at(".byline").text.include?(t["reading_time"]) && crumbs["aria-label"] == t["crumbs_label"] &&
      crumbs.css("li").map { |li| li.text.strip } == [t["nav_blog"], second] && crumbs.at("a")["href"] == t["home_url"]
  end
  related = doc.css(".related .card h3 a").map { |a| a["href"] }
  check("#{p['url']}: 'leia também' só com posts do mesmo idioma") do
    related == (by_lang[p["lang"]].map { |q| q["url"] } - [p["url"]]).first(3) &&
      (related.empty? || doc.at("#related-h").text == t["related"])
  end
  ld = doc.css('script[type="application/ld+json"]').map { |s| JSON.parse(s.text) }
  check("#{p['url']}: BlogPosting com autor Organization, URL sem data e BreadcrumbList") do
    post = ld.find { |o| o["@type"] == "BlogPosting" }
    post && post["author"]["@type"] == "Organization" && post["publisher"]["logo"] &&
      post["url"] == BASE_URL + p["url"] && post["mainEntityOfPage"]["@id"] == BASE_URL + p["url"] &&
      ld.any? { |o| o["@type"] == "BreadcrumbList" }
  end
end

puts
puts "#{$checks - $failures.size}/#{$checks} verificações passaram"
exit($failures.empty? ? 0 : 1)
