require_relative '../util'

# Multiplex Arca Spoltore: pagine di programmazione di multicinema.it
# (una pagina per giorno, giornoSettimana=0 è oggi).
module Fonti
  module Arca
    ID = 'arca'
    NOME = 'Multiplex Arca Spoltore'
    BASE = 'https://www.multicinema.it'
    BIGLIETTI = 'https://arca.multicinema.18tickets.it'

    module_function

    def spettacoli(oggi, giorni)
      risultati = []
      [giorni, 7].min.times do |i|
        html = Util.get("#{BASE}/Programmazione?cinema=arca&giornoSettimana=#{i}")
        giorno = data_scheda(html, i, oggi)
        html.split(/class="item_small"/).drop(1).each do |blocco|
          titolo = blocco[%r{<h3>\s*<a[^>]*>(.*?)</a>}m, 1]
          next unless titolo

          orari = blocco.scan(/pr\.orario\.split\(' '\)">\s*(\d{1,2})[.:](\d{2})\s*</)
          locandina = blocco[/<img[^>]*src="([^"]+)"/, 1]
          orari.each do |h, m|
            risultati << {
              cinema: ID,
              titolo: Util.decodifica(titolo).strip,
              data: giorno,
              ora: format('%02d:%s', h.to_i, m),
              durata: nil,
              link: BIGLIETTI,
              tag: [],
              locandina: locandina
            }
          end
        end
      end
      risultati.uniq { |r| [r[:titolo], r[:data], r[:ora]] }
    end

    # La scheda attiva riporta "Sabato 7": uso il numero del giorno per
    # confermare la data, altrimenti ricado su oggi + indice.
    def data_scheda(html, indice, oggi)
      stimata = oggi + indice
      etichetta = html[/giornoSettimana=#{indice}"[^>]*>\s*[^\d<]*(\d{1,2})\s*</, 1]
      return stimata unless etichetta

      g = etichetta.to_i
      return stimata if stimata.day == g

      (0..10).map { |d| oggi + d }.find { |d| d.day == g } || stimata
    end
  end
end
