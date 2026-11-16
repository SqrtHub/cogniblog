# frozen_string_literal: true

# Verificações estruturais do site gerado.
# Uso: bundle exec jekyll build && bundle exec ruby tests/check_site.rb [_site]

require "date"
require "json"
require "nokogiri"
require "pathname"
require "yaml"

SITE = Pathname.new(ARGV[0] || "_site").expand_path
ROOT = Pathname.new(__dir__).join("..").expand_path
BASE_URL = "https://blog.cogniscion.com"
PRODUCT_URL = "https://cogniscion.com/"

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
posts = Dir[ROOT.join("_posts/*.md")].sort.map do |f|
  path = Pathname.new(f)
  fm = front_matter(path)
  y, m, d, slug = path.basename(".md").to_s.match(/\A(\d{4})-(\d{2})-(\d{2})-(.+)\z/).captures
  date = fm["date"].respond_to?(:to_time) ? fm["date"].to_time : Time.new(y.to_i, m.to_i, d.to_i)
  fm.merge("url" => "/#{y}/#{m}/#{d}/#{slug}/", "file" => "#{y}/#{m}/#{d}/#{slug}/index.html",
           "time" => date, "day" => fm["date"].respond_to?(:strftime) ? fm["date"].strftime("%Y-%m-%d") : "#{y}-#{m}-#{d}",
           "topic" => topic_of(fm))
end
posts.reject! { |p| p["published"] == false || (!future && p["time"] > Time.now) }
posts.sort_by! { |p| p["time"] }.reverse!
guides = posts.select { |p| p["format"] == "guide" }
regular = posts.reject { |p| p["format"] == "guide" }
topics = posts.map { |p| p["topic"] }.compact.uniq.sort

# Destaques esperados, como em _layouts/home.html: o mais recente com `featured: true`
# (mesmo que seja mais antigo que os demais) ou, sem nenhum, o mais recente do conjunto.
def pick(list)
  list.find { |p| p["featured"].to_s == "true" } || list.first
end
guide_pick = pick(guides)
post_pick = pick(regular)

pages = Dir[SITE.join("**/*.html")].map { |f| Pathname.new(f).relative_path_from(SITE).to_s }.sort

# Rotas preservadas
%w[index.html sobre/index.html 404.html guias/index.html feed.xml sitemap.xml robots.txt CNAME].each do |f|
  check("existe #{f}") { SITE.join(f).file? }
end
check("CNAME é blog.cogniscion.com") { SITE.join("CNAME").read.strip == "blog.cogniscion.com" }
posts.each do |p|
  check("post no permalink antigo #{p['url']}") { SITE.join(p["file"]).file? }
end

# Indexação
check("robots.txt não bloqueia e aponta o sitemap") do
  r = SITE.join("robots.txt").read
  r !~ /^\s*Disallow:\s*\S/i && r.include?("Sitemap: #{BASE_URL}/sitemap.xml")
end
sitemap = Nokogiri::XML(SITE.join("sitemap.xml").read)
sitemap.remove_namespaces!
locs = sitemap.xpath("//loc").map(&:text)
check("sitemap inclui home, sobre, guias e todos os posts") do
  (["#{BASE_URL}/", "#{BASE_URL}/sobre/", "#{BASE_URL}/guias/"] + posts.map { |p| BASE_URL + p["url"] }).all? { |u| locs.include?(u) }
end
check("sitemap não inclui 404") { locs.none? { |u| u.include?("404") } }
feed = Nokogiri::XML(SITE.join("feed.xml").read) { |c| c.strict }
feed.remove_namespaces!
check("feed.xml é XML válido com todos os posts") { feed.xpath("//entry").size == posts.size }

# Por página
pages.each do |rel|
  doc = html(rel)
  check("#{rel}: sem noindex") { doc.css('meta[name="robots"], meta[name="googlebot"]').none? { |m| m["content"].to_s =~ /noindex|nofollow/i } }
  check("#{rel}: lang pt-BR") { doc.at("html")["lang"] == "pt-BR" }
  check("#{rel}: sem hreflang") { doc.css("link[hreflang]").empty? }
  check("#{rel}: um canonical absoluto") do
    c = doc.css('link[rel="canonical"]')
    c.size == 1 && c.first["href"].start_with?("#{BASE_URL}/")
  end
  check("#{rel}: og:image absoluta") { doc.at('meta[property="og:image"]')&.[]("content").to_s.start_with?("#{BASE_URL}/") }
  check("#{rel}: um único h1") { doc.css("h1").size == 1 }
  check("#{rel}: títulos sem pular níveis") do
    levels = doc.css("h1, h2, h3, h4, h5, h6").map { |h| h.name[1].to_i }
    levels.first == 1 && levels.each_cons(2).all? { |a, b| b <= a + 1 }
  end
  check("#{rel}: navbar sem 'Sobre'") { doc.css(".site-nav a").none? { |a| a.text.strip =~ /sobre/i } }
  check("#{rel}: navbar com Blog, Guias e CTA do produto") do
    links = doc.css(".site-nav a").map { |a| [a.text.strip, a["href"]] }
    links.include?(["Blog", "/"]) && links.include?(["Guias", "/guias/"]) && links.include?(["Conhecer a CogniScion", PRODUCT_URL])
  end
  check("#{rel}: EN desativado e explicado") do
    en = doc.at('.lang [lang="en"]')
    en && en.name == "span" && en["href"].nil? && en.at(".sr-only")
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
  check("#{rel}: sem marcas de mockup") do
    t = doc.to_html
    t !~ /proposta|ilustrativ|data-inert|toast|mockup|lorem/i
  end
  ld = doc.css('script[type="application/ld+json"]').map { |s| JSON.parse(s.text) }
  check("#{rel}: JSON-LD válido e sem Person") { ld.none? { |o| o.to_json.include?('"Person"') } }
  check("#{rel}: um único JSON-LD principal (WebSite/WebPage/BlogPosting)") do
    ld.count { |o| %w[WebSite WebPage BlogPosting].include?(o["@type"]) } == 1
  end
end

# Home
home = html("index.html")
fguide = home.at('[aria-labelledby="feat-guide-h"]')
fpost = home.at('[aria-labelledby="feat-post-h"]')
check("home: espaço do guia em destaque sempre presente") { fguide }
if guides.empty?
  check("home: sem guia publicado, mostra 'Guias em preparação' sem link de artigo") do
    fguide.at("h2").text.strip == "Guias em preparação" && fguide.css("a").map { |a| a["href"] } == ["/guias/"]
  end
else
  check("home: guia em destaque é o mais recente com featured: true ou, sem nenhum, o mais recente") do
    fguide.at("h2 a")["href"] == guide_pick["url"]
  end
end
if regular.empty?
  check("home: sem post comum, não há destaque de post") { fpost.nil? }
else
  check("home: destaque de guia antes do destaque de post") { fguide.path < fpost.path }
  check("home: post em destaque é o post comum mais recente com featured: true ou, sem nenhum, o mais recente") do
    fpost.at("h2 a")["href"] == post_pick["url"]
  end
  check("home: destaques são itens diferentes") { fguide.at("h2 a")&.[]("href") != fpost.at("h2 a")["href"] }
end
cards = home.css("[data-grid] .card")
if posts.empty?
  check("home: sem posts, mostra aviso e nenhuma grade, filtro ou mensagem de filtro") do
    home.at("#posts").text.include?("Ainda não há posts publicados.") &&
      home.at("[data-grid]").nil? && home.at("[data-filters]").nil? && home.at("[data-empty]").nil?
  end
else
  check("home: grade lista todos os posts publicados, do mais novo ao mais antigo") do
    cards.map { |c| c.at("h3 a")["href"] } == posts.map { |p| p["url"] }
  end
  check("home: títulos da grade iguais aos do front matter") do
    cards.map { |c| c.at("h3 a").text } == posts.map { |p| p["title"] }
  end
  check("home: mensagem para filtro sem resultados") { home.at("[data-empty]") }
end
if topics.size > 1
  check("home: filtros só com temas existentes e ocultos sem JS") do
    chips = home.css("[data-filters] [data-filter]").map { |c| c["data-filter"] } - ["all"]
    home.at("[data-filters]").key?("hidden") && chips == topics
  end
else
  check("home: sem filtros com #{topics.size} tema(s)") { home.at("[data-filters]").nil? }
end

# Guias
gdoc = html("guias/index.html")
if guides.empty?
  check("guias: estado vazio honesto") { gdoc.text.include?("Guias em preparação") && gdoc.css(".card").empty? }
else
  check("guias: lista só guias") { gdoc.css(".card").map { |c| c.at("h3 a")["href"] } == guides.map { |g| g["url"] } }
end

# Posts
posts.each do |p|
  doc = html(p["file"])
  check("#{p['url']}: título e data preservados") do
    doc.at("h1").text == p["title"] && doc.at(".byline time")["datetime"].start_with?(p["day"])
  end
  ld = doc.css('script[type="application/ld+json"]').map { |s| JSON.parse(s.text) }
  check("#{p['url']}: BlogPosting com autor Organization e BreadcrumbList") do
    post = ld.find { |o| o["@type"] == "BlogPosting" }
    post && post["author"]["@type"] == "Organization" && post["publisher"]["logo"] &&
      ld.any? { |o| o["@type"] == "BreadcrumbList" }
  end
end

puts
puts "#{$checks - $failures.size}/#{$checks} verificações passaram"
exit($failures.empty? ? 0 : 1)
