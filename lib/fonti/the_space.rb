require_relative '../util'
require_relative 'mymovies'

# The Space Cinema Montesilvano: API JSON usata dal sito ufficiale.
# L'API non sempre risponde (a volte rifiuta le richieste con 401):
# i giorni non disponibili vengono saltati e, se manca oggi, si usa MyMovies.
module Fonti
  module TheSpace
    ID = 'space'
    NOME = 'The Space Montesilvano'
    CINEMA_ID = '1026'
    BASE = 'https://www.thespacecinema.it'
    PAGINA_CINEMA = "#{BASE}/cinema/montesilvano/al-cinema".freeze
    MYMOVIES = 'https://www.mymovies.it/cinema/pescara/montesilvano/5680/'

    module_function

    def spettacoli(oggi, giorni)
      risultati = []
      (0...giorni).each do |i|
        giorno = oggi + i
        url = "#{BASE}/api/microservice/showings/cinemas/#{CINEMA_ID}/films" \
              "?showingDate=#{giorno.iso8601}T00:00:00&minEmbargoLevel=3" \
              '&includesSession=true&includeSessionAttributes=true'
        dati = begin
          Util.get_json(url)
        rescue StandardError => e
          warn "  The Space #{giorno}: #{e.message}"
          next
        end
        (dati['result'] || []).each do |film|
          titolo, tag_titolo = pulisci_titolo(film['filmTitle'])
          durata = film['isDurationUnknown'] ? nil : film['runningTime']
          (film['showingGroups'] || []).each do |gruppo|
            (gruppo['sessions'] || []).each do |s|
              inizio = s['startTime'].to_s
              next unless inizio =~ /\A(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/

              risultati << {
                cinema: ID,
                titolo: titolo,
                titolo_originale: film['originalTitle'],
                data: Date.parse(Regexp.last_match(1)),
                ora: Regexp.last_match(2),
                durata: durata && durata.to_i > 0 ? durata.to_i : nil,
                link: s['bookingUrl'].to_s.empty? ? PAGINA_CINEMA : BASE + s['bookingUrl'],
                tag: (tag_titolo + tag_sessione(s)).uniq,
                esaurito: s['isSoldOut'] == true,
                locandina: film['posterImageSrc']
              }
            end
          end
        end
      end
      if risultati.none? { |r| r[:data] == oggi }
        warn '  The Space: uso MyMovies per oggi'
        risultati.concat(MyMovies.spettacoli(pagina: MYMOVIES, cinema: ID, link: PAGINA_CINEMA, oggi: oggi))
      end
      risultati.uniq { |r| [Util.normalizza(r[:titolo]), r[:data], r[:ora]] }
    end

    def pulisci_titolo(titolo)
      tag = []
      t = titolo.to_s.strip
      if t =~ /\s*[-–]\s*lingua originale\s*\z/i
        tag << 'Lingua originale'
        t = t.sub(/\s*[-–]\s*lingua originale\s*\z/i, '')
      end
      [t.gsub(/\s+:\s+/, ': '), tag]
    end

    def tag_sessione(sessione)
      (sessione['attributes'] || []).map do |a|
        nome = a['name'].to_s.strip
        next if nome.empty? || nome.casecmp('2D').zero? || nome.casecmp('ITALIANO').zero?

        nome =~ /originale|english|inglese/i ? 'Lingua originale' : nome
      end.compact
    end
  end
end
