#!/usr/bin/env ruby
# Genera _site/index.html con gli orari dei quattro cinema.
#
# Uso:  ruby build.rb
# Il token TMDB viene letto dalla variabile d'ambiente TMDB_TOKEN
# oppure, in locale, dal file .tmdb_token (escluso da git).

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
$LOAD_PATH.unshift(File.join(__dir__, 'lib'))
require 'yaml'
require 'fileutils'
require 'util'
require 'tmdb'
require 'catalogo'
require 'pagina'
require 'fonti/the_space'
require 'fonti/arca'
require 'fonti/cityplex'
require 'fonti/uci'

FONTI = [Fonti::TheSpace, Fonti::Arca, Fonti::Cityplex, Fonti::Uci].freeze

config = YAML.load_file(File.join(__dir__, 'config.yml')) || {}
correzioni = YAML.load_file(File.join(__dir__, 'correzioni.yml')) || {}
giorni = (config['giorni'] || 7).to_i
oggi = Date.today

token = ENV['TMDB_TOKEN'].to_s
%w[.tmdb_token tmdb_token.txt].each do |nome|
  file_token = File.join(__dir__, nome)
  token = File.read(file_token).gsub(/\s+/, '') if token.strip.empty? && File.exist?(file_token)
end
tmdb = Tmdb.new(token)

avvisi = []
avvisi << 'Token TMDB mancante: i generi vengono presi solo da MyMovies.' unless tmdb.attivo?

spettacoli = []
FONTI.each do |fonte|
  begin
    trovati = fonte.spettacoli(oggi, giorni)
    puts "#{fonte::NOME}: #{trovati.size} spettacoli"
    avvisi << "#{fonte::NOME}: nessun orario trovato (il sito potrebbe essere cambiato)." if trovati.empty?
    spettacoli.concat(trovati)
  rescue StandardError => e
    warn "#{fonte::NOME}: ERRORE #{e.class}: #{e.message}"
    avvisi << "#{fonte::NOME}: impossibile leggere gli orari (#{e.message})."
  end
end

film = Catalogo.new(config, correzioni, tmdb).costruisci(spettacoli)
avvisi << "TMDB: #{tmdb.errori.size} ricerche non riuscite." unless tmdb.errori.empty?
tmdb.errori.first(5).each { |e| warn e }

conteggio = film.group_by { |f| f[:categoria] }.transform_values(&:size)
puts "Film: #{film.size} (#{conteggio.map { |k, v| "#{k}: #{v}" }.join(', ')})"
film.select { |f| f[:categoria] == :sconosciuto }.each { |f| puts "  genere sconosciuto: #{f[:titolo]}" }

FileUtils.mkdir_p(File.join(__dir__, '_site'))
# Logo, icone per la schermata Home e manifest dell'app
Dir[File.join(__dir__, 'assets', '*')].each { |f| FileUtils.cp(f, File.join(__dir__, '_site')) }
html = Pagina.new(film: film, oggi: oggi, giorni: giorni, config: config,
                  avvisi: avvisi, generato: Time.now).html
File.write(File.join(__dir__, '_site', 'index.html'), html)

dati = film.map do |f|
  f.merge(spettacoli: f[:spettacoli].map { |s| s.merge(data: s[:data].iso8601) })
end
File.write(File.join(__dir__, '_site', 'orari.json'), JSON.pretty_generate(dati))
puts 'Pagina generata: _site/index.html'
