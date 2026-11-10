require_relative 'util'

# Ricerca dei film su TMDB per ottenere generi, durata, locandina e trama.
class Tmdb
  API = 'https://api.themoviedb.org/3'
  IMG = 'https://image.tmdb.org/t/p/w500'

  attr_reader :errori

  def initialize(token)
    @token = token.to_s.strip
    @cache = {}
    @errori = []
  end

  def attivo?
    !@token.empty?
  end

  # Restituisce { id:, titolo:, generi:, durata:, locandina:, trama:, voto:, url: } o nil.
  def cerca(titolo, titolo_originale: nil, oggi: Date.today)
    return nil unless attivo?

    chiave = Util.normalizza(titolo)
    return @cache[chiave] if @cache.key?(chiave)

    @cache[chiave] = begin
      candidati = [titolo, titolo_originale].compact.uniq.flat_map { |q| ricerca(q) }.uniq { |r| r['id'] }
      migliore = scegli(candidati, [titolo, titolo_originale].compact, oggi)
      migliore && dettagli(migliore['id'])
    rescue StandardError => e
      @errori << "TMDB (#{titolo}): #{e.message}"
      nil
    end
  end

  def dettagli(id)
    d = chiama("/movie/#{id}", language: 'it-IT')
    {
      id: d['id'],
      titolo: d['title'],
      generi: (d['genres'] || []).map { |g| g['name'] },
      durata: d['runtime'].to_i > 0 ? d['runtime'].to_i : nil,
      locandina: d['poster_path'] ? IMG + d['poster_path'] : nil,
      trama: d['overview'].to_s,
      voto: d['vote_count'].to_i >= 20 ? d['vote_average'].to_f.round(1) : nil,
      paesi: (Array(d['origin_country']) + (d['production_countries'] || []).map { |p| p['iso_3166_1'] }).uniq,
      paese_principale: Array(d['origin_country']).first || (d['production_countries'] || []).map { |p| p['iso_3166_1'] }.first,
      lingua: d['original_language'],
      url: "https://www.themoviedb.org/movie/#{d['id']}"
    }
  end

  private

  def ricerca(query)
    q = query.to_s.sub(/\s*[-–]\s*(lingua originale|evento).*\z/i, '').strip
    return [] if q.empty?

    chiama('/search/movie', query: q, language: 'it-IT', region: 'IT', include_adult: 'false')['results'] || []
  end

  # Punteggio: somiglianza del titolo + uscita recente + popolarità.
  def scegli(candidati, titoli, oggi)
    obiettivi = titoli.map { |t| Util.normalizza(t) }
    valutati = candidati.map do |c|
      nomi = [c['title'], c['original_title']].compact.map { |t| Util.normalizza(t) }
      somiglianza = nomi.product(obiettivi).map { |a, b| somiglianza(a, b) }.max || 0
      uscita = (Date.parse(c['release_date']) rescue nil)
      recente = if uscita.nil? then 0
                elsif uscita > oggi + 120 then 0.1
                elsif uscita >= oggi - 540 then 0.5
                elsif uscita >= oggi - 1500 then 0.15
                else 0
                end
      popolarita = [Math.log10(c['popularity'].to_f + 1) / 10, 0.2].min
      [somiglianza + recente + popolarita, somiglianza, c]
    end
    migliore = valutati.max_by(&:first)
    migliore && migliore[1] >= 0.6 ? migliore[2] : nil
  end

  # Somiglianza tra 0 e 1 basata sulle parole in comune.
  def somiglianza(a, b)
    return 1.0 if a == b
    return 0.0 if a.empty? || b.empty?

    pa = a.split
    pb = b.split
    comuni = (pa & pb).size.to_f
    base = comuni / [pa.size, pb.size].max
    base = [base, 0.85].max if a.start_with?("#{b} ") || b.start_with?("#{a} ")
    base
  end

  def chiama(percorso, parametri = {})
    headers = {}
    if @token.length > 40
      headers['Authorization'] = "Bearer #{@token}"
    else
      parametri = parametri.merge(api_key: @token)
    end
    Util.get_json("#{API}#{percorso}?#{URI.encode_www_form(parametri)}", headers)
  end
end
