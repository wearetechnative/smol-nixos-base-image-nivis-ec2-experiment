/* Motion and the running counter.
 *
 * Nothing here creates content. The page is already complete when this
 * file does not run: the charts are server-rendered SVG, every number is
 * in the HTML, and the counter is the only element that depends on
 * JavaScript, which is why CSS hides it until `.js` is set.
 *
 * Everything below checks `prefers-reduced-motion` first. */

(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* The descent line is drawn by animating its own length, which has to
   * be measured rather than guessed. */
  function primeDescent() {
    var line = document.querySelector(".chart--descent .descent-line");
    if (!line || !line.getTotalLength) return;
    var len = Math.ceil(line.getTotalLength());
    line.style.setProperty("--len", len);
  }

  function revealOnScroll() {
    var sections = document.querySelectorAll(".section");
    if (!("IntersectionObserver" in window)) {
      sections.forEach(function (s) { s.classList.add("in-view"); });
      return;
    }
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) {
            e.target.classList.add("in-view");
            io.unobserve(e.target);
          }
        });
      },
      { rootMargin: "-12% 0px -12% 0px" }
    );
    sections.forEach(function (s) { io.observe(s); });
  }

  /* The counter walks the same step function the chart draws: it holds
   * still through the plateaus, because those experiments moved nothing. */
  function runCounter(series) {
    var box = document.getElementById("counter");
    var value = document.getElementById("counter-value");
    var idOut = document.getElementById("counter-id");
    var descent = document.getElementById("descent");
    if (!box || !value || !idOut || !descent || !series.length) return;

    var points = series.filter(function (p) { return p.closure_mib !== null; });

    function format(n) {
      return Math.round(n).toLocaleString("en-GB").replace(/,/g, " ");
    }

    var ticking = false;
    function update() {
      ticking = false;
      var rect = descent.getBoundingClientRect();
      var vh = window.innerHeight || document.documentElement.clientHeight;
      var span = rect.height + vh;
      var progress = (vh - rect.top) / span;
      progress = Math.max(0, Math.min(1, progress));

      var i = Math.min(points.length - 1, Math.floor(progress * points.length));
      var p = points[i];
      value.textContent = format(p.closure_mib);
      idOut.textContent = p.id;
      box.style.opacity = rect.bottom < 0 || rect.top > vh ? "0.35" : "1";
    }

    function onScroll() {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(update);
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    update();
  }

  function start() {
    if (!reduced) {
      primeDescent();
      revealOnScroll();
    } else {
      document.querySelectorAll(".section").forEach(function (s) {
        s.classList.add("in-view");
      });
    }

    fetch("data.json")
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) { if (data) runCounter(data.series); })
      .catch(function () { /* the page does not need it */ });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
