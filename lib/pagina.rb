require 'erb'
require 'time'
require_relative 'util'
require_relative 'catalogo'

# Genera la pagina HTML a partire dall'elenco dei film.
class Pagina
  GIORNI = %w[Domenica Lunedì Martedì Mercoledì Giovedì Venerdì Sabato].freeze
  GIORNI_BREVI = %w[Dom Lun Mar Mer Gio Ven Sab].freeze
  MESI = %w[gennaio febbraio marzo aprile maggio giugno luglio agosto
            settembre ottobre novembre dicembre].freeze

  # Colori dei cinema: brillanti, leggibili sul vetro scuro delle schede.
  CINEMA = {
    'space' => { breve: 'Space', nome: 'The Space Montesilvano', colore: '#4fd1c5' },
    'arca' => { breve: 'Arca', nome: 'Multiplex Arca Spoltore', colore: '#ff9a6b' },
    'cityplex' => { breve: 'Cityplex', nome: 'Pescara Cityplex', colore: '#c7a4ff' },
    'uci' => { breve: 'UCI', nome: 'UCI Megalò Chieti', colore: '#7cb7ff' }
  }.freeze

  ORIGINI = [
    [:italiano, 'Film italiani'],
    [:straniero, 'Film stranieri'],
    [:sconosciuta, 'Origine non nota']
  ].freeze

  ETICHETTA_ORIGINE = { italiano: 'Italia', straniero: 'Estero' }.freeze

  FASCE_BREVI = { prima: 'Prima di cena', cavallo: 'A cavallo', dopo: 'Dopo cena' }.freeze

  def initialize(film:, oggi:, giorni:, config:, avvisi:, generato:)
    @film = film
    @oggi = oggi
    @giorni = (0...giorni).map { |i| oggi + i }
    @config = config
    @avvisi = avvisi
    @generato = generato
  end

  def html
    modello = File.read(File.join(__dir__, '..', 'modelli', 'pagina.html.erb'), encoding: 'UTF-8')
    ERB.new(modello, trim_mode: '-').result(binding)
  end

  private

  # Logo incorporato nella pagina (si vede anche senza i file accanto).
  def logo_data_uri
    require 'base64'
    svg = File.read(File.join(__dir__, '..', 'assets', 'icona.svg'), encoding: 'UTF-8')
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  def h(testo)
    CGI.escapeHTML(testo.to_s)
  end

  def sopratitolo_giorno(data)
    return 'Oggi' if data == @oggi
    return 'Domani' if data == @oggi + 1

    "Tra #{(data - @oggi).to_i} giorni"
  end

  def data_estesa(data)
    "#{GIORNI[data.wday]} #{data.day} #{MESI[data.month - 1]}"
  end

  # Film di una categoria che hanno spettacoli in quel giorno.
  def film_del_giorno(data, categoria)
    @film.select { |f| f[:categoria] == categoria && f[:spettacoli].any? { |s| s[:data] == data } }
  end

  def spettacoli(film, data, fascia)
    film[:spettacoli].select { |s| s[:data] == data && s[:fascia] == fascia }
  end

  def durata(minuti)
    return nil unless minuti

    minuti >= 60 ? format('%dh %02dm', minuti / 60, minuti % 60) : "#{minuti}m"
  end

  # Istante dello spettacolo in millisecondi, per attenuare quelli già iniziati.
  def istante(spettacolo)
    base = Time.new(spettacolo[:data].year, spettacolo[:data].month, spettacolo[:data].day)
    ((base + spettacolo[:inizio] * 60).to_f * 1000).to_i
  end

  def cinema_presenti(data)
    @film.flat_map { |f| f[:spettacoli] }.select { |s| s[:data] == data }.map { |s| s[:cinema] }.uniq
  end

  FRECCIA = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M5 11 11 5M6 5h5v5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'.freeze

  # Scheda di un film per un giorno, in stile app Inviti:
  # locandina a tutta larghezza, sfondo sfumato dal poster, pannelli in vetro.
  def scheda(film, data)
    fasce = Catalogo::FASCE.map do |fascia, icona, nome|
      lista = spettacoli(film, data, fascia)
      next if lista.empty?

      %(<div class="fascia" data-fascia="#{fascia}"><div class="fascia-nome #{fascia}"><span class="emoji">#{icona}</span>#{nome}</div>) +
        %(<div class="orari">#{lista.map { |s| pulsante(s) }.join}</div></div>)
    end.compact.join

    poster = film[:locandina]
    stile = poster ? %( style="--poster:url('#{h(poster)}')") : ''
    immagine = if poster
                 %(<img class="locandina" src="#{h(poster)}" alt="" loading="lazy">)
               else
                 %(<div class="locandina vuota" aria-hidden="true">#{h(film[:titolo].to_s[0])}</div>)
               end

    origine = { italiano: '🇮🇹 Italiano', straniero: '🌍 Straniero' }[film[:origine]]
    chip_origine = origine ? %(<span class="chip sx">#{origine}</span>) : ''
    chip_voto = film[:voto] ? %(<span class="chip dx">★ #{h(film[:voto])}</span>) : ''
    generi = film[:generi].first(3).map { |g| h(g) }.join(' · ')
    meta = [generi, durata(film[:durata])].compact.reject(&:empty?).join('<span class="punto">·</span>')
    titolo = film[:tmdb_url] ? %(<a href="#{h(film[:tmdb_url])}" target="_blank" rel="noopener">#{h(film[:titolo])}</a>) : h(film[:titolo])

    trama = film[:trama].to_s.strip
    blocco_trama = if trama.empty?
                     ''
                   elsif trama.length > 200
                     %(<div class="vetro trama"><p>#{h(trama)}</p><button type="button" class="altro">Leggi tutto</button></div>)
                   else
                     %(<div class="vetro trama corta"><p>#{h(trama)}</p></div>)
                   end

    <<~HTML
      <article class="film#{poster ? '' : ' senza-poster'}" data-origine="#{film[:origine]}"#{stile}>
        <div class="sfondo" aria-hidden="true"></div>
        <div class="copertina">#{immagine}#{chip_origine}#{chip_voto}</div>
        <div class="intestazione">
          <h3>#{titolo}</h3>
          <div class="meta">#{meta}</div>
        </div>
        #{blocco_trama}
        <div class="vetro spettacoli">#{fasce}</div>
      </article>
    HTML
  end

  def pulsante(s)
    c = CINEMA[s[:cinema]] || { breve: s[:cinema], nome: s[:cinema], colore: '#888' }
    tag = s[:tag].map { |t| %(<span class="tag">#{h(t)}</span>) }.join
    fine = "fine #{s[:fine_stimata] ? '~' : ''}#{s[:fine]}"
    classi = ['orario', s[:fascia].to_s, (s[:esaurito] ? 'esaurito' : nil)].compact.join(' ')
    <<~HTML
      <a class="#{classi}" href="#{h(s[:link])}" target="_blank" rel="noopener"
         data-inizio="#{istante(s)}" style="--c:#{c[:colore]}" aria-label="#{h(s[:ora])}, #{h(c[:nome])}: acquista">
        <span class="ora">#{h(s[:ora])}</span>
        <span class="cin">#{h(c[:breve])}</span>
        <span class="fine">#{fine}</span>#{tag}
      </a>
    HTML
  end
end
