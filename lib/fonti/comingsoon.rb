require_relative '../util'

# Lettura degli orari da ComingSoon: per ogni film in programmazione in un cinema
# c'è una pagina "vedi tutte le date" con tutti i giorni e gli orari già pubblicati.
# Usata per UCI (tutti i giorni) e come riserva per The Space.
module Fonti
  module ComingSoon
    MESI = %w[GEN FEB MAR APR MAG GIU LUG AGO SET OTT NOV DIC].freeze

    module_function

    # pagina: indirizzo della pagina del cinema su ComingSoon (con la "/" finale)
    # link_ufficiale: true per usare i link d'acquisto di ComingSoon (solo se portano al sito del cinema)
    def spettacoli(pagina:, cinema:, link:, oggi:, giorni:, link_ufficiale: nil)
      elenco = Util.get(pagina)
      idf = elenco.scan(%r{/ticket/\?idf=(\d+)}).flatten.uniq
      fine = oggi + giorni
      risultati = []

      idf.each do |id|
        html = begin
          Util.get("#{pagina}ticket/?idf=#{id}")
        rescue StandardError => e
          warn "  ComingSoon #{cinema} idf=#{id}: #{e.message}"
          next
        end
        blocchi = html.split(/<p class="h1">/).drop(1)
        titolo_base = nil

        blocchi.each do |blocco|
          intestazione = Util.decodifica(blocco[/\A([^<]+)</, 1].to_s).strip
          next if intestazione.empty?

          titolo_base ||= intestazione
          variante = intestazione.sub(titolo_base, '').strip
          tag = variante.empty? ? [] : [variante.sub(/\Asala\s+/i, 'Sala ')]
          titolo, tag_titolo = pulisci_titolo(titolo_base)
          tag = (tag_titolo + tag).uniq

          blocco.scan(%r{<span class="day">(\d+)</span>\s*<span class="month">(\w+)</span>.*?<div class="media-body">(.*?)</div>}m)
                .each do |giorno, mese, corpo|
            data = crea_data(giorno.to_i, mese, oggi)
            next unless data && data >= oggi && data < fine

            corpo.scan(%r{<button([^>]*)>\s*(\d{1,2}):(\d{2})\s*</button>}).each do |attributi, h, m|
              acquisto = Util.decodifica(attributi[/data-url="([^"]*)"/, 1].to_s)
              usa = link_ufficiale && acquisto.start_with?(link_ufficiale)
              risultati << {
                cinema: cinema,
                titolo: titolo,
                data: data,
                ora: format('%02d:%s', h.to_i, m),
                durata: nil,
                link: usa ? acquisto.sub(/\?SC_CMP=.*\z/, '') : link,
                tag: tag,
                locandina: nil
              }
            end
          end
        end
      end
      risultati.uniq { |r| [Util.normalizza(r[:titolo]), r[:data], r[:ora], r[:tag]] }
    end

    # "(O.V.) George Michael: The Faith Tour" → ["George Michael: The Faith Tour", ["Lingua originale"]]
    # "Hunger Games (Re-Release)" → ["Hunger Games", []]
    def pulisci_titolo(titolo)
      tag = []
      t = titolo.dup
      if t =~ /\((?:O\.?\s?V\.?|V\.?\s?O\.?(?:\s?S\.?)?|lingua originale)\)/i
        tag << 'Lingua originale'
        t = t.gsub(/\((?:O\.?\s?V\.?|V\.?\s?O\.?(?:\s?S\.?)?|lingua originale)\)/i, '')
      end
      t = t.gsub(/\((?:re-?release|riedizione|versione restaurata)\)/i, '')
      [t.gsub(/\s+/, ' ').strip, tag]
    end

    # "11" + "NOV" → data, gestendo il passaggio dicembre → gennaio.
    def crea_data(giorno, mese, oggi)
      m = MESI.index(mese.to_s.upcase[0, 3])
      return nil unless m

      d = Date.new(oggi.year, m + 1, giorno)
      d = Date.new(oggi.year + 1, m + 1, giorno) if d < oggi - 60
      d
    rescue ArgumentError
      nil
    end
  end
end
