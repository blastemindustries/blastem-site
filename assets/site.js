/* Blastem Industries: behaviour shared by every page.
   Exposes window.BL with small helpers so each page's own script stays short. */
(function () {
  "use strict";
  var calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fine = window.matchMedia("(pointer: fine)").matches;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
  var lerp = function (a, b, t) { return a + (b - a) * t; };
  var mouse = { x: innerWidth / 2, y: innerHeight / 2 };
  var BL = window.BL = { calm: calm, fine: fine, $: $, $$: $$, clamp: clamp, lerp: lerp, mouse: mouse };

  $$("[data-year]").forEach(function (el) { el.textContent = new Date().getFullYear(); });

  /* ---------------- preloader ---------------- */
  (function () {
    var loader = $("#loader");
    function finish() {
      if (loader) loader.classList.add("done");
      document.body.classList.remove("loading");
      document.body.classList.add("ready");
    }
    if (!loader) { finish(); return; }
    var bar = $("#loaderBar"), count = $("#loaderCount"), p = 0, loaded = document.readyState === "complete";
    window.addEventListener("load", function () { loaded = true; });
    setTimeout(function () { loaded = true; }, 3500); // never hold the page hostage
    var start = performance.now();
    (function tick(t) {
      var target = loaded ? 100 : Math.min(90, (t - start) / 12);
      p += (target - p) * (calm ? 1 : 0.08);
      if (target === 100 && p > 99.5) p = 100;
      bar.style.transform = "scaleX(" + p / 100 + ")";
      count.textContent = String(Math.round(p)).padStart(3, "0");
      if (p < 100) requestAnimationFrame(tick); else setTimeout(finish, calm ? 0 : 250);
    })(start);
  })();

  /* ---------------- custom cursor (delegated, so late-added elements work too) ---------------- */
  addEventListener("pointermove", function (e) { mouse.x = e.clientX; mouse.y = e.clientY; }, { passive: true });
  var cur = $("#cursor"), dot = $("#cursorDot"), label = $("#cursorLabel");
  if (cur && fine && !calm) {
    document.documentElement.classList.add("has-cursor");
    var cx = mouse.x, cy = mouse.y;
    addEventListener("mousemove", function (e) { dot.style.transform = "translate(" + e.clientX + "px," + e.clientY + "px)"; });
    (function loop() {
      cx = lerp(cx, mouse.x, 0.18); cy = lerp(cy, mouse.y, 0.18);
      cur.style.transform = "translate(" + cx + "px," + cy + "px)";
      requestAnimationFrame(loop);
    })();
    document.addEventListener("mouseover", function (e) {
      var el = e.target.closest("a, button, [data-cursor], input, label");
      cur.classList.toggle("hover", !!el);
      if (el) label.textContent = el.dataset.cursor || "";
    });
  }

  /* ---------------- nav: scrolled state, hide on scroll down, progress bar ---------------- */
  var nav = $("#nav"), progress = $("#progress"), lastY = 0;
  function onScroll() {
    var y = scrollY, max = document.documentElement.scrollHeight - innerHeight;
    if (nav) {
      nav.classList.toggle("scrolled", y > 30);
      nav.classList.toggle("hide", y > lastY && y > 400 && !nav.classList.contains("open"));
    }
    lastY = y;
    if (progress) progress.style.transform = "scaleX(" + (max > 0 ? y / max : 0) + ")";
  }
  addEventListener("scroll", onScroll, { passive: true }); onScroll();
  var menuBtn = $("#menuBtn");
  if (menuBtn) {
    var setMenu = function (open) {
      nav.classList.toggle("open", open);
      menuBtn.setAttribute("aria-expanded", open); menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    };
    menuBtn.addEventListener("click", function () { setMenu(!nav.classList.contains("open")); });
    $$("#navLinks a").forEach(function (a) { a.addEventListener("click", function () { setMenu(false); }); });
    addEventListener("keydown", function (e) { if (e.key === "Escape") setMenu(false); });
  }

  /* ---------------- text scramble ---------------- */
  var GLYPHS = "!<>-_\\/[]{}=+*^?#01ΛΣΞ";
  function scramble(el, text, dur) {
    if (!el) return;
    text = text || el.dataset.text || el.textContent;
    if (calm) { el.textContent = text; return; }
    var start = performance.now(); dur = dur || 700;
    (function step(t) {
      var k = clamp((t - start) / dur, 0, 1), out = "";
      for (var i = 0; i < text.length; i++) {
        out += (i / text.length < k || text[i] === " ") ? text[i] : GLYPHS[(Math.random() * GLYPHS.length) | 0];
      }
      el.textContent = out;
      if (k < 1) requestAnimationFrame(step);
    })(start);
  }
  BL.scramble = scramble;
  $$("[data-scramble]").forEach(function (a) {
    var t = a.textContent;
    a.addEventListener("mouseenter", function () { scramble(a, t, 450); });
  });

  /* ---------------- reveals ---------------- */
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (!en.isIntersecting) return;
      var el = en.target;
      el.classList.add("in");
      $$(".scramble", el).forEach(function (s) { scramble(s, s.dataset.text, 900); });
      io.unobserve(el);
    });
  }, { threshold: 0.15, rootMargin: "0px 0px -8% 0px" });
  BL.observe = function (el) { io.observe(el); };
  $$(".reveal, .reveal-split").forEach(function (el) {
    if (el.classList.contains("reveal-split")) {
      var sib = el.parentNode.querySelectorAll(".reveal-split");
      el.firstElementChild.style.transitionDelay = (Array.prototype.indexOf.call(sib, el) * 0.09) + "s";
    }
    if (el.dataset.delay) el.style.transitionDelay = el.dataset.delay + "s";
    io.observe(el);
  });

  /* ---------------- magnetic buttons ---------------- */
  if (fine && !calm) {
    $$(".magnetic").forEach(function (el) {
      var s = parseFloat(el.dataset.strength || 0.3), inner = $(".orb-inner", el);
      el.addEventListener("mousemove", function (e) {
        var r = el.getBoundingClientRect(), dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
        el.style.transform = "translate(" + dx * s + "px," + dy * s + "px)";
        if (inner) inner.style.transform = "translate(" + dx * s * 0.4 + "px," + dy * s * 0.4 + "px)";
      });
      el.addEventListener("mouseleave", function () {
        el.style.transition = "transform .6s cubic-bezier(.16,1,.3,1), box-shadow .4s, color .3s, border-color .3s";
        el.style.transform = ""; if (inner) inner.style.transform = "";
        setTimeout(function () { el.style.transition = ""; }, 600);
      });
    });
  }

  /* ---------------- counters: <b data-count="9" data-from="0" data-decimals="2"> ---------------- */
  var cio = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (!en.isIntersecting) return; cio.unobserve(en.target);
      $$("[data-count]", en.target).forEach(function (b, i) {
        var to = +b.dataset.count, from = +(b.dataset.from || 0), dec = +(b.dataset.decimals || 0);
        var start = performance.now() + i * 120, dur = calm ? 0 : 1600;
        (function tick(t) {
          var k = dur ? clamp((t - start) / dur, 0, 1) : 1, e = 1 - Math.pow(1 - k, 4);
          b.textContent = (from + (to - from) * e).toFixed(dec);
          if (k < 1) requestAnimationFrame(tick);
        })(performance.now());
      });
    });
  }, { threshold: 0.4 });
  $$("[data-counters]").forEach(function (el) { cio.observe(el); });

  /* ---------------- spotlight cards: any .spot gets --mx/--my for a pointer-following glow ---------------- */
  document.addEventListener("pointermove", function (e) {
    var card = e.target.closest && e.target.closest(".spot");
    if (!card) return;
    var r = card.getBoundingClientRect();
    card.style.setProperty("--mx", (e.clientX - r.left) + "px");
    card.style.setProperty("--my", (e.clientY - r.top) + "px");
  }, { passive: true });
})();
