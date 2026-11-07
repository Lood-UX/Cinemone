require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'

module Util
  class ErroreDefinitivo < StandardError; end

  UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' \
       '(KHTML, like Gecko) Chrome/130.0 Safari/537.36'

  MESI = %w[gennaio febbraio marzo aprile maggio giugno luglio agosto
            settembre ottobre novembre dicembre].freeze

  ENTITA = {
    'nbsp' => ' ', 'agrave' => 'à', 'egrave' => 'è', 'eacute' => 'é',
    'igrave' => 'ì', 'ograve' => 'ò', 'ugrave' => 'ù', 'Agrave' => 'À',
    'Egrave' => 'È', 'Eacute' => 'É', 'rsquo' => '’', 'lsquo' => '‘',
    'ldquo' => '“', 'rdquo' => '”', 'ndash' => '–', 'mdash' => '—',
    'hellip' => '…', 'amp' => '&', 'quot' => '"', 'apos' => "'",
    'lt' => '<', 'gt' => '>'
  }.freeze

  module_function

  # GET con redirect, timeout e un paio di tentativi.
  def get(url, headers = {}, tentativi: 3)
    uri = URI(url)
    tentativi.times do |n|
      begin
        5.times do
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 15
          http.read_timeout = 30
          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = UA
          req['Accept-Language'] = 'it-IT,it;q=0.9'
          headers.each { |k, v| req[k] = v }
          res = http.request(req)
          if res.is_a?(Net::HTTPRedirection)
            uri = URI.join(uri.to_s, res['location'])
            next
          end
          if res.is_a?(Net::HTTPClientError)
            # 4xx: inutile riprovare
            raise ErroreDefinitivo, "HTTP #{res.code} da #{uri.host}"
          end
          raise "HTTP #{res.code} da #{uri.host}" unless res.is_a?(Net::HTTPSuccess)
          return res.body.to_s.dup.force_encoding('UTF-8').scrub('')
        end
        raise "Troppi redirect da #{uri.host}"
      rescue StandardError => e
        raise e if e.is_a?(ErroreDefinitivo) || n == tentativi - 1
        sleep(2 * (n + 1))
      end
    end
  end

  def get_json(url, headers = {})
    JSON.parse(get(url, headers.merge('Accept' => 'application/json')))
  end

  # Decodifica le entità HTML più comuni.
  def decodifica(testo)
    t = testo.to_s.gsub(/&([a-zA-Z]+);/) { ENTITA[Regexp.last_match(1)] || Regexp.last_match(0) }
    CGI.unescapeHTML(t)
  end

  # Rimuove i tag e normalizza gli spazi.
  def testo(html)
    decodifica(html.to_s.gsub(/<br\s*\/?>/i, "\n").gsub(/<[^>]+>/, ' '))
      .gsub(/[ \t ]+/, ' ').gsub(/ *\n */, "\n").strip
  end

  # Normalizza un titolo per confrontarlo tra fonti diverse.
  def normalizza(titolo)
    t = titolo.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase
    t = t.gsub(/[’'`]/, ' ')
    t = t.gsub(/\b(lingua originale|versione originale|v\.?o\.?s?|sottotitolato|in 3d|3d|imax)\b/, ' ')
    t.gsub(/[^a-z0-9]+/, ' ').strip.squeeze(' ')
  end

  def minuti(ora)
    h, m = ora.split(':').map(&:to_i)
    h * 60 + m
  end

  def ora(minuti)
    format('%02d:%02d', (minuti / 60) % 24, minuti % 60)
  end

  def mese(nome)
    i = MESI.index(nome.to_s.downcase)
    i && i + 1
  end
end
