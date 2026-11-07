require_relative 'mymovies'

# UCI Megalò Chieti. Il sito ufficiale ha una protezione anti-bot, quindi
# gli orari vengono letti da MyMovies, che pubblica la programmazione di oggi.
module Fonti
  module Uci
    ID = 'uci'
    NOME = 'UCI Megalò Chieti'
    PAGINA = 'https://www.mymovies.it/cinema/chieti/21416/'
    BIGLIETTI = 'https://www.ucicinemas.it/cinema/abruzzo/chieti/uci-cinemas-megalo/'

    module_function

    def spettacoli(oggi, _giorni)
      MyMovies.spettacoli(pagina: PAGINA, cinema: ID, link: BIGLIETTI, oggi: oggi)
    end
  end
end
