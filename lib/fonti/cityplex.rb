require_relative '../util'

# Pescara Cityplex: la home riporta la programmazione settimanale come testo,
# per esempio "SE DOMANI NON TORNO … dal 05 all' 11 novembre ore 16.30 - 18.45".
module Fonti
  module Cityplex
    ID = 'cityplex'
    NOME = 'Pescara Cityplex'
    SITO = 'https://pescaracityplex.it/'
    CIAOTICKETS = 'https://www.ciaotickets.com/cineteatro-massimo-pescara'

    MESE_RE = "(#{Util::MESI.join('|')})".freeze

    module_function

    def spettacoli(oggi, giorni)
      html = Util.get(SITO)
      blocchi = html.scan(%r{elementor-divider__text[^>]*>(.*?)</span>}m).flatten.map { |b| Util.testo(b) }
      intestazione = blocchi.find { |b| b =~ /programmazione/i } || ''
      lunedi_chiuso = intestazione =~ /luned[iì] chiuso/i
      anno = (intestazione[/\b(20\d{2})\b/, 1] || oggi.year).to_i
      biglietti = link_biglietti

      fine = oggi + giorni
      risultati = []
      blocchi.each do |blocco|
        next if blocco.equal?(intestazione) || blocco !~ /\bore\b/i

        righe = blocco.split("\n").map(&:strip).reject(&:empty?)
        titolo = righe.first.to_s.sub(/\s+(dal|il|l['’])\s+\d.*\z/i, '').strip
        next if titolo.empty?

        note = righe[1..-1].to_a.reject { |r| r =~ /\bore\b/i }
        tag = note.any? { |n| n =~ /evento|regista|ospit|presenza/i } ? ['Evento'] : []

        blocco.scan(/(.*?)\bore\b\s*([\d\s.:,\-–e]+)/mi).each do |parte_date, parte_orari|
          date = interpreta_date(parte_date, anno, oggi, lunedi_chiuso)
          orari = parte_orari.scan(/(\d{1,2})[.:](\d{2})/).map { |h, m| format('%02d:%s', h.to_i, m) }
          date.each do |d|
            next if d < oggi || d >= fine

            orari.each do |o|
              risultati << {
                cinema: ID, titolo: titolo, data: d, ora: o, durata: nil,
                link: link_film(titolo, biglietti), tag: tag, locandina: nil
              }
            end
          end
        end
      end
      risultati.uniq { |r| [r[:titolo], r[:data], r[:ora]] }
    end

    # Riconosce: "dal 05 all' 11 novembre", "dal 30 ottobre al 5 novembre",
    # "il 06-07-08 novembre", "08 novembre".
    def interpreta_date(testo, anno, oggi, lunedi_chiuso)
      t = testo.downcase.tr('’', "'")
      if (m = t.match(/dal\s+(\d{1,2})(?:\s+#{MESE_RE})?\s+al+'?\s*(\d{1,2})\s+#{MESE_RE}/))
        mese_fine = Util.mese(m[4])
        mese_inizio = m[2] ? Util.mese(m[2]) : mese_fine
        inizio = crea_data(anno, mese_inizio, m[1].to_i, oggi)
        termine = crea_data(anno, mese_fine, m[3].to_i, oggi)
        return [] unless inizio && termine

        termine = Date.new(termine.year + 1, termine.month, termine.day) if termine < inizio
        giorni = (inizio..termine).to_a
        giorni.reject!(&:monday?) if lunedi_chiuso
        return giorni
      end
      if (m = t.match(/(\d{1,2}(?:\s*[-,e]\s*\d{1,2})+)\s+#{MESE_RE}/))
        mese = Util.mese(m[2])
        return m[1].scan(/\d{1,2}/).map { |g| crea_data(anno, mese, g.to_i, oggi) }.compact
      end
      if (m = t.match(/(\d{1,2})\s+#{MESE_RE}/))
        d = crea_data(anno, Util.mese(m[2]), m[1].to_i, oggi)
        return d ? [d] : []
      end
      []
    end

    # Gestisce il cambio d'anno (programmazione di fine dicembre/inizio gennaio).
    def crea_data(anno, mese, giorno, oggi)
      return nil unless mese

      d = Date.new(anno, mese, giorno)
      d = Date.new(anno + 1, mese, giorno) if d < oggi - 60
      d
    rescue ArgumentError
      nil
    end

    # Pagine dei singoli film su Ciaotickets (es. /it/biglietti/dio-ride-pescara-pe).
    def link_biglietti
      html = Util.get(CIAOTICKETS)
      html.scan(%r{href="(/it/biglietti/[^"]+)"}).flatten.uniq.map do |p|
        ["https://www.ciaotickets.com#{p}", Util.normalizza(p.split('/').last.tr('-', ' '))]
      end
    rescue StandardError
      []
    end

    def link_film(titolo, biglietti)
      chiave = Util.normalizza(titolo)
      trovato = biglietti.find { |_, slug| slug.start_with?("#{chiave} ") || slug == chiave }
      trovato ? trovato.first : CIAOTICKETS
    end
  end
end
