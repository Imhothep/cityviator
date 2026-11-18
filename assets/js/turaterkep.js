/* Cityviator – OpenStreetMap térképek (Leaflet) */
(function () {
  "use strict";
  var L = window.CVLeaflet;

  var TILE = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  var ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> közreműködők';

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function baseMap(el) {
    var map = L.map(el, { scrollWheelZoom: false });
    L.tileLayer(TILE, { maxZoom: 19, attribution: ATTR }).addTo(map);
    // görgetős nagyítás csak kattintás után, hogy az oldal görgetése ne akadjon el
    map.once("focus click", function () { map.scrollWheelZoom.enable(); });
    return map;
  }

  function numberIcon(n, start) {
    return L.divIcon({
      className: "tm-marker" + (start ? " tm-start" : ""),
      html: "<span>" + n + "</span>",
      iconSize: [30, 30],
      iconAnchor: [15, 15],
      popupAnchor: [0, -14]
    });
  }

  function tourMap(el) {
    var data = JSON.parse(el.getAttribute("data-turaterkep"));
    var map = baseMap(el);
    var bounds = [];

    if (data.line && data.line.length) {
      L.polyline(data.line, { color: "#ffffff", weight: 8, opacity: 0.9 }).addTo(map);
      var route = L.polyline(data.line, { color: "#15803d", weight: 4.5, opacity: 0.95, dashArray: "1 8", lineCap: "round" }).addTo(map);
      L.polyline(data.line, { color: "#15803d", weight: 3, opacity: 0.55 }).addTo(map);
      bounds = bounds.concat(route.getLatLngs());
    }

    data.stations.forEach(function (s, i) {
      var html =
        '<div class="tm-popup">' +
        (s.img ? '<img src="' + esc(s.img) + '" alt="" loading="lazy">' : "") +
        "<strong>" + s.n + ". " + esc(s.name) + "</strong>" +
        (i === 0 ? '<em>Indulás és érkezés</em>' : "") +
        '<a href="#allomas-' + esc(s.id) + '">Ugrás a leíráshoz ↓</a></div>';
      L.marker([s.lat, s.lon], { icon: numberIcon(s.n, i === 0), title: s.name, zIndexOffset: i === 0 ? 1000 : 0 })
        .bindPopup(html, { maxWidth: 240 })
        .addTo(map);
      bounds.push([s.lat, s.lon]);
    });

    if (bounds.length) map.fitBounds(bounds, { padding: [30, 30], maxZoom: 18 });
  }

  function overviewMap(el) {
    var tours = JSON.parse(el.getAttribute("data-attekinto"));
    var map = baseMap(el);
    var bounds = [];
    tours.forEach(function (t) {
      var html =
        '<div class="tm-popup">' +
        (t.img ? '<img src="' + esc(t.img) + '" alt="" loading="lazy">' : "") +
        "<strong>" + esc(t.name) + "</strong><em>" + t.n + " állomás</em>" +
        '<a href="' + esc(t.url) + '">A túra megnyitása →</a></div>';
      L.marker([t.lat, t.lon], { icon: numberIcon("★"), title: t.name }).bindPopup(html, { maxWidth: 240 }).addTo(map);
      bounds.push([t.lat, t.lon]);
    });
    if (bounds.length) map.fitBounds(bounds, { padding: [40, 40], maxZoom: 13 });
  }

  function init() {
    if (!L) return;
    document.querySelectorAll("[data-turaterkep]").forEach(tourMap);
    document.querySelectorAll("[data-attekinto]").forEach(overviewMap);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
