require_relative '../util'

# Lettura della pagina di un cinema su MyMovies (programmazione di oggi).
# Usata per UCI e come riserva per The Space. Oltre agli orari restituisce
# generi, paesi, durata e trama, utili anche per gli altri cinema.
module Fonti
  module MyMovies
    # Generi MyMovies → generi TMDB.
    GENERI = {
      'drammatico' => 'Dramma', 'commedia' => 'Commedia', 'documentario' => 'Documentario',
      'animazione' => 'Animazione', 'azione' => 'Azione', 'avventura' => 'Avventura',
      'horror' => 'Horror', 'thriller' => 'Thriller', 'fantascienza' => 'Fantascienza',
      'fantasy' => 'Fantasy', 'storico' => 'Storia', 'biografico' => 'Storia',
      'musicale' => 'Musica', 'musical' => 'Musica', 'concerto' => 'Musica',
      'sentimentale' => 'Romance', 'romantico' => 'Romance', 'giallo' => 'Mistero',
      'poliziesco' => 'Crime', 'noir' => 'Crime', 'guerra' => 'Guerra',
      'western' => 'Western', 'family' => 'Famiglia', 'famiglia' => 'Famiglia'
    }.freeze

    module_function

    def spettacoli(pagina:, cinema:, link:, oggi:)
      html = Util.get(pagina)
      risultati = []
      html.split(/id="poster-\d+"/).drop(1).each do |blocco|
        titolo = blocco[%r{<a href="https://www\.mymovies\.it/film/\d{4}/[^"]+/" title="([^"]+)">}, 1]
        next unless titolo

        orari = blocco.scan(/mm-weight-700">\s*(\d{1,2}):(\d{2})\s*</)
        next if orari.empty?

        lancio = blocco[%r{schedine-lancio">(.*?)</div>}m, 1].to_s
        # Il testo dei link è il genere al singolare ("Drammatico"), lo slug a volte è plurale.
        generi = lancio.scan(%r{<a title="Film [^"]*" href="https://www\.mymovies\.it/film/[a-z-]+/">([^<]+)</a>})
                       .flatten.map { |g| GENERI[Util.decodifica(g).strip.downcase] }.compact.uniq
        testo_lancio = Util.testo(lancio)
        durata = testo_lancio[/Durata\s+(\d+)\s+Minuti/i, 1]
        trama = Util.testo(blocco[/id="trama\d+"[^>]*>(.*?)<script/m, 1].to_s)
        trama = Util.testo(blocco[/<div>\s*([^<]{40,}?)\s*<span id="espandi/m, 1].to_s) if trama.empty?

        orari.each do |h, m|
          risultati << {
            cinema: cinema,
            titolo: Util.decodifica(titolo).strip,
            data: oggi,
            ora: format('%02d:%s', h.to_i, m),
            durata: durata && durata.to_i,
            link: link,
            tag: [],
            generi_fonte: generi,
            paesi_fonte: paesi_da_lancio(testo_lancio),
            trama_fonte: trama,
            locandina: blocco[/src="(https?:[^"]+)"/, 1]
          }
        end
      end
      risultati.uniq { |r| [r[:titolo], r[:data], r[:ora]] }
    end

    # Formati visti:
    #   "Commedia , Drammatico - Regno Unito , USA 2026 . Durata 118 Minuti."
    #   "Commedia , Italia 2026 . Durata 114 Minuti."   (film italiani: niente trattino)
    def paesi_da_lancio(testo)
      parte = testo[/([^.\n]+?)\s+\d{4}\s*\.\s*Durata/i, 1].to_s
      return [] if parte.empty?

      if parte =~ /\s[-–]\s+(.+)\z/
        Regexp.last_match(1).split(',').map(&:strip).reject(&:empty?)
      else
        ultimo = parte.split(',').last.to_s.strip
        ultimo =~ /\Aitalia\z/i ? ['Italia'] : []
      end
    end
  end
end
