require_relative 'comingsoon'
require_relative 'mymovies'
require_relative '../util'

# UCI Megalò Chieti. Il sito ufficiale ha una protezione anti-bot, quindi:
# - orari di tutti i giorni da ComingSoon (pagine "vedi tutte le date")
# - generi, paese, durata e trama da MyMovies (solo oggi), come informazioni di riserva
# - se ComingSoon non risponde, orari di oggi da MyMovies
module Fonti
  module Uci
    ID = 'uci'
    NOME = 'UCI Megalò Chieti'
    COMINGSOON = 'https://www.comingsoon.it/cinema/chieti/uci-megalo/4739/'
    MYMOVIES = 'https://www.mymovies.it/cinema/chieti/21416/'
    BIGLIETTI = 'https://www.ucicinemas.it/cinema/abruzzo/chieti/uci-cinemas-megalo/'

    module_function

    def spettacoli(oggi, giorni)
      schede = begin
        MyMovies.spettacoli(pagina: MYMOVIES, cinema: ID, link: BIGLIETTI, oggi: oggi)
      rescue StandardError => e
        warn "  UCI MyMovies: #{e.message}"
        []
      end

      orari = begin
        ComingSoon.spettacoli(pagina: COMINGSOON, cinema: ID, link: BIGLIETTI, oggi: oggi, giorni: giorni)
      rescue StandardError => e
        warn "  UCI ComingSoon: #{e.message}"
        []
      end
      return schede if orari.empty?

      # Aggiunge agli orari di ComingSoon le informazioni di MyMovies (generi, trama...)
      info = schede.group_by { |s| Util.normalizza(s[:titolo]) }
      orari.map do |s|
        extra = info[Util.normalizza(s[:titolo])]&.first
        next s unless extra

        s.merge(durata: extra[:durata], generi_fonte: extra[:generi_fonte], paesi_fonte: extra[:paesi_fonte],
                trama_fonte: extra[:trama_fonte], locandina: extra[:locandina])
      end
    end
  end
end
