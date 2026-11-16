/* Blog CogniScion: melhorias progressivas (menu mobile e filtro de posts).
   Sem JS, a navegação aparece aberta e todos os posts ficam visíveis. */
(function () {
  "use strict";

  function $(sel, ctx) { return (ctx || document).querySelector(sel); }
  function $$(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }

  // Menu mobile
  var menuBtn = $(".menu-btn");
  var nav = $("#site-nav");
  if (menuBtn && nav) {
    var mq = window.matchMedia("(max-width: 640px)");
    menuBtn.hidden = false;

    var setMenu = function (open) {
      nav.classList.toggle("open", open);
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
      menuBtn.setAttribute("aria-label", open ? "Fechar menu" : "Abrir menu");
    };

    menuBtn.addEventListener("click", function () {
      setMenu(!nav.classList.contains("open"));
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && nav.classList.contains("open")) {
        setMenu(false);
        menuBtn.focus();
      }
    });

    // Fecha ao sair do menu com Tab ou ao clicar fora
    nav.addEventListener("focusout", function (e) {
      if (mq.matches && nav.classList.contains("open") && e.relatedTarget &&
          !nav.contains(e.relatedTarget) && e.relatedTarget !== menuBtn) {
        setMenu(false);
      }
    });
    document.addEventListener("click", function (e) {
      if (nav.classList.contains("open") && !nav.contains(e.target) && !menuBtn.contains(e.target)) {
        setMenu(false);
      }
    });

    var onChange = function () { if (!mq.matches) setMenu(false); };
    if (mq.addEventListener) mq.addEventListener("change", onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }

  // Filtro de posts por tema
  var filters = $("[data-filters]");
  var grid = $("[data-grid]");
  if (filters && grid) {
    var chips = $$("[data-filter]", filters);
    var cards = $$(".card", grid);
    var empty = $("[data-empty]");
    var count = $("[data-count]");
    var reset = $("[data-filter-reset]");

    var apply = function (topic) {
      var shown = 0;
      chips.forEach(function (c) {
        c.setAttribute("aria-pressed", c.getAttribute("data-filter") === topic ? "true" : "false");
      });
      cards.forEach(function (card) {
        var on = topic === "all" || card.getAttribute("data-topic") === topic;
        card.hidden = !on;
        if (on) shown++;
      });
      if (empty) empty.hidden = shown > 0;
      if (count) count.textContent = shown + (shown === 1 ? " publicação" : " publicações");
    };

    chips.forEach(function (c) {
      c.addEventListener("click", function () { apply(c.getAttribute("data-filter")); });
    });
    if (reset) {
      reset.addEventListener("click", function () {
        apply("all");
        chips[0].focus();
      });
    }
    filters.hidden = false;
  }
})();
