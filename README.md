# Cityviator – Városlátogató

Hugo + Blowfish oldal gyalogos városi túrákhoz – https://cityviator.hu

## Futtatás

```bash
hugo server          # helyi előnézet: http://localhost:1313
hugo --minify        # éles build a public/ mappába
```

Hugo **extended** 0.166–0.169 szükséges (Blowfish v3).

## Új túra felvétele

1. Hozz létre egy mappát: `content/turak/<slug>/index.md` (TOML `+++` front matter, lásd a meglévő túrákat).
2. Minden állomás egy `[[allomasok]]` blokk: `id`, `name`, `cim`, `lat`, `lon`, `leiras` (Markdown), `kepek` (képmappa-minta, pl. `"img/<id>/*"`), `forras`.
   A fotókat a túra mappájába tedd: `content/turak/<slug>/img/<id>/`, a borítókép neve `feature.jpg`.
   Az **első** állomás a kiinduló- és érkezési pont.
3. A szövegben: `{{< turaterkep >}}` (térkép + összegzés + GPX) és `{{< allomasok >}}` (állomások a bejárási sorrendben).
4. Számold ki az útvonalat:

```bash
python3 scripts/utvonalterv.py <slug>
```

A szkript az OpenStreetMap úthálózatán (OSRM, gyalogos profil) lekéri az állomások közötti
gyalogos távolságokat, kiszámolja a legrövidebb körutat (≤10 állomásig pontos megoldás),
és elmenti a `data/routes/<slug>.json` és a `static/gpx/<slug>.gpx` fájlt. Állomás-módosítás után futtasd újra.

## Felépítés

- `config/_default/` – Hugo és Blowfish beállítások (magyar nyelv, forest színséma)
- `layouts/shortcodes/` – `turaterkep`, `allomasok`, `osszes-turaterkep`
- `layouts/partials/extend-head-uncached.html` – Leaflet csak a térképes oldalakon
- `assets/js/turaterkep.js`, `assets/css/custom.css` – térkép és állomás-stílusok

## Források

Leírások és fotók: [zárterkély – esőnap](https://zarterkely.hu/blog/esonap/).
A fotók a zarterkely.hu forrásából (zarterkely3) lettek átmásolva, és ugyanazzal a galéria-modullal
jelennek meg: `themes/hugo-shortcode-gallery` (justifiedGallery + swipebox lightbox). Az állomásoknál a
`layouts/partials/galeria.html` ugyanezt a modult használja; szabadon a `{{< gallery2 match="img/..." >}}` shortcode is használható.
Térkép: © OpenStreetMap közreműködők.
