require_relative 'util'

# Unisce gli spettacoli dei vari cinema in un elenco di film,
# aggiunge i dati TMDB, calcola le fasce e applica i filtri sui generi.
class Catalogo
  # Emoji: 🌇 tramonto (esci e vai a cena) · 🥪 cena al volo · 🌙 notte (ceni con calma, poi cinema)
  FASCE = [
    [:prima, '🌇', 'Prima di cena'],
    [:cavallo, '🥪', 'A cavallo della cena'],
    [:dopo, '🌙', 'Dopo cena']
  ].freeze

  def initialize(config, correzioni, tmdb)
    @config = config
    @tmdb = tmdb
    @correzioni = (correzioni || {}).each_with_object({}) { |(k, v), h| h[Util.normalizza(k)] = v || {} }
    @preferiti = lista(config['generi_preferiti'])
    @esclusi = lista(config['generi_esclusi'])
    @sempre = lista(config['film_sempre']).map { |t| Util.normalizza(t) }
    @mai = lista(config['film_mai']).map { |t| Util.normalizza(t) }
    cena = config['cena'] || {}
    @fine_prima = Util.minuti(cena['prima_di_cena_finisce_entro'] || '20:45')
    @inizio_dopo = Util.minuti(cena['dopo_cena_inizia_da'] || '21:30')
    @pubblicita = (config['pubblicita_minuti'] || 15).to_i
    @durata_predefinita = (config['durata_predefinita'] || 120).to_i
  end

  def costruisci(spettacoli)
    riserva = schede_riserva(spettacoli)
    gruppi = spettacoli.group_by { |s| Util.normalizza(s[:titolo]) }

    film = gruppi.map { |chiave, lista| crea_film(chiave, lista, riserva) }.compact

    # Due titoli scritti in modo diverso ma con lo stesso film TMDB → un solo film.
    film = film.group_by { |f| f[:tmdb_id] ? "tmdb#{f[:tmdb_id]}" : "t#{f[:chiave]}" }.map do |_, simili|
      principale = simili.max_by { |f| f[:spettacoli].size }
      principale[:spettacoli] = simili.flat_map { |f| f[:spettacoli] }
      principale
    end

    film.each { |f| completa_spettacoli(f) }
    film.reject { |f| f[:spettacoli].empty? }.sort_by { |f| Util.normalizza(f[:titolo]) }
  end

  private

  def lista(valore)
    Array(valore).map(&:to_s).map(&:strip).reject(&:empty?)
  end

  # Generi e durata letti da MyMovies (UCI), usati quando TMDB non trova il film.
  def schede_riserva(spettacoli)
    spettacoli.select { |s| s.key?(:generi_fonte) || s.key?(:paesi_fonte) }
              .each_with_object({}) do |s, h|
      h[Util.normalizza(s[:titolo])] ||= { generi: s[:generi_fonte] || [], durata: s[:durata],
                                           paesi: s[:paesi_fonte] || [], trama: s[:trama_fonte].to_s }
    end
  end

  def crea_film(chiave, lista, riserva)
    return nil if @mai.include?(chiave)

    correzione = @correzioni[chiave] || {}
    titolo_sorgente = titolo_migliore(lista.map { |s| s[:titolo] })
    info = if correzione['tmdb_id']
             (@tmdb.dettagli(correzione['tmdb_id']) rescue nil) if @tmdb.attivo?
           else
             @tmdb.cerca(titolo_sorgente, titolo_originale: lista.map { |s| s[:titolo_originale] }.compact.first)
           end
    scheda = riserva[chiave] || {}

    generi = if correzione['generi']
               lista(correzione['generi'])
             else
               ((info ? info[:generi] : []) + (scheda[:generi] || [])).uniq
             end
    durate_fonte = lista.map { |s| s[:durata] }.compact
    durata = (info && info[:durata]) || durate_fonte.max || scheda[:durata]

    {
      chiave: chiave,
      titolo: correzione['titolo'] || (info && info[:titolo]) || titolo_sorgente,
      tmdb_id: info && info[:id],
      tmdb_url: info && info[:url],
      generi: generi,
      durata: durata,
      locandina: (info && info[:locandina]) || lista.map { |s| s[:locandina] }.compact.first,
      trama: [info && info[:trama], scheda[:trama]].map(&:to_s).find { |t| !t.strip.empty? }.to_s,
      voto: info && info[:voto],
      categoria: categoria(chiave, generi),
      origine: origine(correzione, info, scheda),
      spettacoli: lista
    }
  end

  # :italiano, :straniero o :sconosciuta.
  # TMDB: paese d'origine Italia oppure lingua originale italiana.
  # MyMovies: primo paese indicato nella scheda.
  def origine(correzione, info, scheda)
    manuale = correzione['origine'].to_s.downcase
    return :italiano if manuale.start_with?('ital')
    return :straniero if manuale.start_with?('stran')

    if info && (info[:paesi].to_a.any? || info[:lingua])
      italiano = info[:paese_principale] == 'IT' || info[:lingua] == 'it'
      return italiano ? :italiano : :straniero
    end
    paesi = scheda[:paesi].to_a
    return :sconosciuta if paesi.empty?

    paesi.first =~ /\Aital/i ? :italiano : :straniero
  end

  # Preferisce un titolo scritto in maiuscolo/minuscolo rispetto al TUTTO MAIUSCOLO.
  def titolo_migliore(titoli)
    misti = titoli.reject { |t| t == t.upcase }
    scelto = (misti.empty? ? titoli : misti).max_by { |t| titoli.count(t) }
    scelto == scelto.upcase ? scelto.capitalize : scelto
  end

  def categoria(chiave, generi)
    return :preferito if @sempre.include?(chiave)
    return :altro if (generi & @esclusi).any?
    return :preferito if (generi & @preferiti).any?
    return :sconosciuto if generi.empty?

    :altro
  end

  def completa_spettacoli(film)
    durata = film[:durata] || @durata_predefinita
    film[:spettacoli] = film[:spettacoli].map do |s|
      s = s.dup
      inizio = Util.minuti(s[:ora])
      # Spettacoli dopo mezzanotte: appartengono alla serata precedente.
      if inizio < 5 * 60
        inizio += 24 * 60
        s[:data] -= 1
      end
      fine = inizio + @pubblicita + durata
      s[:inizio] = inizio
      s[:fine] = Util.ora(fine)
      s[:fine_stimata] = film[:durata].nil?
      s[:fascia] = if fine <= @fine_prima then :prima
                   elsif inizio >= @inizio_dopo then :dopo
                   else :cavallo
                   end
      s
    end
    film[:spettacoli] = film[:spettacoli]
                        .uniq { |s| [s[:cinema], s[:data], s[:ora]] }
                        .sort_by { |s| [s[:data], s[:inizio], s[:cinema]] }
  end
end
