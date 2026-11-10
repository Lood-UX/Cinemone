# 🎬 OneScreen

Pagina personale con gli orari di quattro cinema dell'area di Pescara,
filtrati per genere e divisi in fasce rispetto alla cena:

- The Space Montesilvano
- Multiplex Arca Spoltore
- Pescara Cityplex
- UCI Megalò Chieti (orari letti da MyMovies, solo il giorno corrente)

Ogni orario è un pulsante che porta all'acquisto del biglietto.

## Come funziona

Due volte al giorno GitHub Actions esegue `build.rb`, che:

1. legge la programmazione dei quattro cinema (`lib/fonti/`)
2. cerca ogni film su TMDB per genere, durata e locandina (`lib/tmdb.rb`)
3. filtra per genere e calcola le fasce (`lib/catalogo.rb`)
4. genera la pagina (`modelli/pagina.html.erb`) e la pubblica su GitHub Pages

## Cosa puoi modificare

- **`config.yml`**: generi preferiti ed esclusi, film da mostrare sempre o mai, orari della cena, giorni da mostrare.
- **`correzioni.yml`**: correzioni manuali quando un film viene abbinato al titolo TMDB sbagliato.

Dopo ogni modifica su GitHub la pagina si rigenera da sola in un paio di minuti.
Per aggiornarla subito: scheda **Actions** → **Aggiorna orari** → **Run workflow**.

## Provarlo in locale

```bash
ruby build.rb
open _site/index.html
```

Per i generi da TMDB in locale, crea un file `.tmdb_token` con il tuo token
(il file è escluso da git e non viene pubblicato).
