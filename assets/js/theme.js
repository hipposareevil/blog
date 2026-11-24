/*
 * Site theme switcher (wizard / space opera / ...).
 *
 * Loaded in <head> (blocking, tiny) so the theme is applied before first paint.
 * Config comes from window.SITE_THEMES (see layouts/partials/theme-head.html):
 *   { default, order: [...], themes: { name: { label, art: { slot: url } } }, match: [{contains, slot}] }
 * An <img data-art-slot="archives"> is swapped for the active theme's art for that slot.
 *
 * What it does
 *  1. picks a theme: ?theme=x  >  localStorage  >  config default
 *  2. sets <html data-theme="x"> (all styling hangs off this - see themes.css)
 *  3. swaps hero / logo images for the theme's art (and restores them again)
 *  4. injects a Mode + Theme + Layout dropdown in the header (desktop) / a toggle button (mobile)
 */
(function () {
  var cfg = window.SITE_THEMES;
  if (!cfg || !cfg.order || !cfg.order.length) return;

  var KEY = "site-theme";
  var root = document.documentElement;
  var base = cfg.default || cfg.order[0];

  function valid(t) { return !!t && cfg.order.indexOf(t) > -1; }
  function load() { try { return localStorage.getItem(KEY); } catch (e) { return null; } }
  function save(t) { try { localStorage.setItem(KEY, t); } catch (e) { /* private mode */ } }

  var q = /[?&]theme=([\w-]+)/.exec(location.search);
  var current = q && valid(q[1]) ? q[1] : load();
  if (!valid(current)) current = base;
  if (q && valid(q[1])) save(current);
  root.setAttribute("data-theme", current);

  // Layout density: "full" (default) or "minimal" (hero images shrunk to thin strips; see themes.css).
  // Independent of the theme. ?density=minimal|full overrides and is remembered.
  var DKEY = "site-density";
  var DENSITIES = [["full", "Full"], ["minimal", "Minimal"]];
  function validD(d) { return d === "full" || d === "minimal"; }
  function loadD() { try { return localStorage.getItem(DKEY); } catch (e) { return null; } }
  function saveD(d) { try { localStorage.setItem(DKEY, d); } catch (e) { /* private mode */ } }
  var qd = /[?&]density=(\w+)/.exec(location.search);
  var density = qd && validD(qd[1]) ? qd[1] : loadD();
  if (!validD(density)) density = "full";
  if (qd && validD(qd[1])) saveD(density);
  root.setAttribute("data-density", density);

  /* ---------- art swapping ---------- */
  // Blowfish hero markup, plus any <img data-art-slot="...">. Anything else: add class="theme-art".
  var HERO = "#background-image, img.single_hero_round, .single_hero_background img, img.theme-art, img[data-art-slot]";
  var LOGO = "img.logo";

  function pageArt(t) {
    var m = document.querySelector('meta[name="theme-art"][data-theme="' + t + '"]');
    return m && m.getAttribute("content");
  }

  // Which slot an <img> is: data-art-slot, else (Blowfish's own images) a piece of its original src.
  function slotOf(img) {
    var s = img.getAttribute("data-art-slot");
    if (s) return s;
    var src = img.getAttribute("data-orig-src") || img.getAttribute("src") || "";
    var m = cfg.match || [];
    for (var i = 0; i < m.length; i++) {
      if (src.indexOf(m[i].contains) > -1) return m[i].slot;
    }
    return null;
  }

  // The URL this image should show in theme t, or null = leave it as the page rendered it.
  function target(img, t) {
    var art = (cfg.themes[t] && cfg.themes[t].art) || {};
    if (img.matches(LOGO)) return art.logo || null;
    var slot = slotOf(img);
    var own = pageArt(t);
    if (own && !(slot && slot.indexOf("tile-") === 0)) return own;   // a page's own art; never the small Browse tiles
    return slot ? (art[slot] || null) : null;
  }

  function apply(img) {
    var orig = img.getAttribute("data-orig-src");
    if (orig === null) {
      orig = img.getAttribute("src") || "";
      img.setAttribute("data-orig-src", orig);
    }
    var to = target(img, current);
    if (to) {
      if (img.getAttribute("src") !== to) img.setAttribute("src", to);
      img.setAttribute("data-theme-art", current);
    } else {
      if (img.getAttribute("src") !== orig) img.setAttribute("src", orig);
      img.removeAttribute("data-theme-art");
    }
  }

  function applyAll() {
    var list = document.querySelectorAll(HERO + ", " + LOGO);
    for (var i = 0; i < list.length; i++) apply(list[i]);
  }

  // Swap images as the parser creates them, so wizard art never flashes.
  var observer = new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var added = muts[i].addedNodes;
      for (var j = 0; j < added.length; j++) {
        var n = added[j];
        if (n.nodeType !== 1) continue;
        if (n.matches && n.matches(HERO + ", " + LOGO)) apply(n);
        else if (n.querySelectorAll) {
          var kids = n.querySelectorAll(HERO + ", " + LOGO);
          for (var k = 0; k < kids.length; k++) apply(kids[k]);
        }
      }
    }
  });
  observer.observe(root, { childList: true, subtree: true });

  /* ---------- toggle button ---------- */
  var ICONS = {
    // simple 24px glyphs, styled by Blowfish's `.icon svg` rule (fill: currentColor)
    wizard: '<path d="M12.6 1.5c.9 3.4.3 5.8 1.8 9L17.6 17H21v3H3v-3h3.4l3.2-6.5c1.5-3.2.9-5.600 2-9z"/>',
    opera: '<path fill-rule="evenodd" d="M12 2c3.3 2.3 5.2 5.9 5.2 9.8 0 1.2-.2 2.3-.5 3.4l2.3 2.9V21l-3.5-1.5c-.9.9-2.1 1.5-3.5 1.5s-2.6-.6-3.5-1.5L5 21v-2.9l2.3-2.9c-.3-1.1-.5-2.2-.5-3.4C6.8 7.9 8.7 4.3 12 2zm0 5.6a2.1 2.1 0 100 4.2 2.1 2.1 0 000-4.2z"/>',
    folktale: '<path fill-rule="evenodd" d="M12 6.2C10.3 5 7.8 4.6 4 4.8v13.4c3.8-.2 6.3.2 8 1.4 1.7-1.2 4.2-1.600 8-1.400V4.800c-3.800-.2-6.300.2-8 1.400zM11.200 8v9.300c-1.200-.6-2.900-.9-5.200-.9V6.700c2.300 0 4 .3 5.200 1.300z"/>',
    orbital: '<path fill-rule="evenodd" d="M12 3a9 9 0 100 18 9 9 0 000-18zm0 2.4a6.6 6.6 0 110 13.2 6.6 6.6 0 010-13.2zm-1.2 3.100L14.600 12l-3.800 3.900-1.400-1.400L11.800 12 9.400 9.600z"/>'
  };

  function iconSvg(t) {
    var p = ICONS[t] || '<circle cx="12" cy="12" r="6"/>';
    return '<span class="icon relative inline-block px-1 align-text-bottom"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' + p + "</svg></span>";
  }

  function nextTheme() {
    return cfg.order[(cfg.order.indexOf(current) + 1) % cfg.order.length];
  }

  function label(t) { return (cfg.themes[t] && cfg.themes[t].label) || t; }

  function refreshButtons() {
    var n = nextTheme();
    var btns = document.querySelectorAll(".theme-switcher");
    for (var i = 0; i < btns.length; i++) {
      btns[i].innerHTML = iconSvg(n);
      btns[i].setAttribute("aria-label", "Switch to " + label(n) + " theme");
      btns[i].setAttribute("title", "Switch to " + label(n) + " theme");
    }
  }

  function setTheme(t) {
    current = t;
    save(t);
    root.setAttribute("data-theme", t);
    applyAll();
    refreshButtons();
    document.dispatchEvent(new CustomEvent("themechange", { detail: { theme: t } }));
  }

  var MODES = [["light", "Light"], ["dark", "Dark"]];
  var TRIGGER_ICON = '<span class="icon relative inline-block px-1 align-text-bottom"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M12 2a10 10 0 100 20 10 10 0 000-20zm0 2v16a8 8 0 000-16z"/></svg></span>'
    + '<span class="theme-menu__chevron" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></span>';

  function isDark() { return root.classList.contains("dark"); }

  function menuItem(group, value, text) {
    return '<button type="button" class="theme-menu__item bf-icon-color-hover" data-group="' + group
      + '" data-value="' + value + '" aria-pressed="false">' + text + "</button>";
  }

  function refreshMenus() {
    var items = document.querySelectorAll(".theme-menu__item");
    for (var i = 0; i < items.length; i++) {
      var g = items[i].getAttribute("data-group"), v = items[i].getAttribute("data-value");
      var on = g === "mode" ? (v === "dark") === isDark()
             : g === "density" ? v === density
             : v === current;
      items[i].setAttribute("aria-pressed", on ? "true" : "false");
    }
  }

  // withMode=false on desktop: light/dark has its own button next to the dropdown.
  function listHtml(withMode) {
    var html = '<div class="theme-menu__list">';
    if (withMode) {
      html += '<span class="theme-menu__heading">Mode</span>';
      MODES.forEach(function (m) { html += menuItem("mode", m[0], m[1]); });
    }
    html += '<span class="theme-menu__heading">Theme</span>';
    cfg.order.forEach(function (t) { html += menuItem("theme", t, label(t)); });
    html += '<span class="theme-menu__heading">Layout</span>';
    DENSITIES.forEach(function (d) { html += menuItem("density", d[0], d[1]); });
    return html + "</div>";
  }

  function bindMenu(el, blowfishSwitcher) {
    el.addEventListener("click", function (e) {
      var b = e.target.closest ? e.target.closest(".theme-menu__item") : null;
      if (!b) return;
      var g = b.getAttribute("data-group"), v = b.getAttribute("data-value");
      if (g === "mode") {
        if ((v === "dark") !== isDark() && blowfishSwitcher) blowfishSwitcher.click();
      } else if (g === "density") {
        density = v; saveD(v); root.setAttribute("data-density", v);
        document.dispatchEvent(new CustomEvent("densitychange", { detail: { density: v } }));
      } else if (v !== current) {
        setTheme(v);
      }
      refreshMenus();
    });
  }

  function makeMenu(blowfishSwitcher) {
    var wrap = document.createElement("div");
    wrap.className = "nested-menu theme-menu";
    wrap.innerHTML = '<div class="cursor-pointer flex items-center">'
      + '<button type="button" class="theme-menu__trigger flex items-center text-base bf-icon-color-hover"'
      + ' aria-haspopup="true" aria-label="Appearance, theme and layout" title="Appearance, theme and layout">' + TRIGGER_ICON + "</button></div>"
      + '<div class="menuhide"><div class="pt-2 p-5 mt-2 rounded-xl backdrop-blur shadow-2xl bg-neutral/25 dark:bg-neutral-800/25">'
      + listHtml(false) + "</div></div>";
    bindMenu(wrap, blowfishSwitcher);
    return wrap;
  }

  // Phone: the same three groups at the bottom of the hamburger menu.
  var MOON = '<path d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.800z"/>';
  var SUN = '<path d="M12 7a5 5 0 100 10 5 5 0 000-10zM11 1h2v3h-2zM11 20h2v3h-2zM1 11h3v2H1zM20 11h3v2h-3zM4.2 5.600l1.400-1.400 2.100 2.100-1.400 1.400zM16.300 17.700l1.400-1.400 2.100 2.100-1.400 1.400zM4.200 18.400l2.100-2.100 1.400 1.400-2.100 2.100zM16.300 6.300l2.100-2.100 1.400 1.400-2.100 2.100z"/>';

  // Desktop: standalone light/dark button beside the dropdown. Shows the mode you would switch TO.
  function makeModeButton(blowfishSwitcher) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "theme-mode-btn flex items-center text-base bf-icon-color-hover";
    b.addEventListener("click", function () { if (blowfishSwitcher) blowfishSwitcher.click(); refreshModeButtons(); });
    return b;
  }
  function refreshModeButtons() {
    var bs = document.querySelectorAll(".theme-mode-btn");
    for (var i = 0; i < bs.length; i++) {
      var dark = isDark();
      bs[i].setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
      bs[i].setAttribute("title", dark ? "Switch to light mode" : "Switch to dark mode");
      bs[i].innerHTML = '<span class="icon relative inline-block px-1 align-text-bottom"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' + (dark ? SUN : MOON) + "</svg></span>";
    }
  }

  function injectMobileList(blowfishSwitcher) {
    var nav = document.querySelector('[role="dialog"] nav');
    if (!nav) return false;
    var box = document.createElement("div");
    box.className = "theme-menu theme-menu--inline";
    box.innerHTML = listHtml(true);
    bindMenu(box, blowfishSwitcher);
    nav.appendChild(box);
    return true;
  }

  // Keep the checkmarks right when light/dark is changed by Blowfish (any button, or the OS).
  new MutationObserver(function () { refreshMenus(); refreshModeButtons(); }).observe(root, { attributes: true, attributeFilter: ["class"] });

  function makeButton(extraClass) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "theme-switcher " + (extraClass || "");
    b.addEventListener("click", function () { setTheme(nextTheme()); });
    return b;
  }

  function injectButtons() {
    if (cfg.order.length < 2) return;
    var placed = false;

    // Desktop: one dropdown (mode + theme) replaces Blowfish's moon/sun button.
    // The original button stays in the DOM, hidden, because Blowfish's own handler does the
    // light/dark switching and we simply click it.
    var d = document.getElementById("appearance-switcher");
    if (d && d.parentNode && d.parentNode.parentNode) {
      var menu = makeMenu(d);
      d.parentNode.parentNode.insertBefore(menu, d.parentNode);
      d.parentNode.parentNode.insertBefore(makeModeButton(d), menu);
      d.parentNode.style.display = "none";
      placed = true;
    }
    // Mobile menu.
    var m = document.getElementById("appearance-switcher-mobile");
    if (m && m.parentNode) {
      m.parentNode.insertBefore(
        makeButton("flex items-center justify-center text-neutral-900 hover:text-primary-600 dark:text-neutral-200 dark:hover:text-primary-400"),
        m
      );
      placed = true;
    }
    injectMobileList(m || d);
    // No Blowfish switcher on this build? Fall back to a floating button.
    if (!placed) {
      var f = makeButton("theme-switcher--floating");
      document.body.appendChild(f);
    }
    refreshButtons();
    refreshMenus();
    refreshModeButtons();
  }

  document.addEventListener("DOMContentLoaded", function () {
    applyAll();
    observer.disconnect();
    injectButtons();
  });
})();
