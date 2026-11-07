/* Browser presentation and window controls for the 256x256 Godot game. */
(() => {
  "use strict";

  const shell = document.getElementById("game-shell");
  const view = document.getElementById("game-view");
  const frame = document.getElementById("game-frame");
  const toolbar = document.getElementById("game-toolbar");
  const canvas = document.getElementById("canvas");
  const stopped = document.getElementById("game-stopped");
  const windowButton = document.getElementById("window-mode");
  const fullscreenButton = document.getElementById("fullscreen-mode");
  const closeButton = document.getElementById("close-game");
  const message = document.getElementById("game-message");

  const GAME_PIXELS = 256;
  let closed = false;

  function fullscreenElement() {
    return document.fullscreenElement || document.webkitFullscreenElement || null;
  }

  function isFullscreen() {
    return fullscreenElement() === shell;
  }

  function resizeGame() {
    const usableWidth = Math.max(1, view.clientWidth - 24);
    // Balance the bottom toolbar with equal free space at the top.
    const usableHeight = Math.max(1, view.clientHeight - 2 * toolbar.offsetHeight - 24);
    const maxScale = Math.min(usableWidth, usableHeight) / GAME_PIXELS;
    // Keep pixel-perfect integer scaling in windowed mode; make actual
    // fullscreen use the available space, even between integer scale steps.
    const scale = isFullscreen() ? maxScale : (maxScale >= 1 ? Math.floor(maxScale) : maxScale);
    const side = Math.max(1, Math.floor(GAME_PIXELS * scale));
    frame.style.width = side + "px";
    frame.style.height = side + "px";
  }

  function syncButtons() {
    const full = isFullscreen();
    // Both actions should be clickable, even if the user is already in that mode.
    windowButton.disabled = closed;
    fullscreenButton.disabled = closed;
    closeButton.disabled = closed || !window.potapGameReady;
    windowButton.setAttribute("aria-pressed", String(!full));
    fullscreenButton.setAttribute("aria-pressed", String(full));
    resizeGame();
  }

  function showMessage(text) {
    message.textContent = text;
  }

  function enterFullscreen() {
    if (closed) return;
    canvas.focus();
    showMessage("");
    if (isFullscreen()) {
      showMessage("Полноэкранный режим уже включён.");
      return;
    }

    // The call itself MUST happen synchronously within a user click;
    // browsers refuse fullscreen requests made after an async delay.
    const request = shell.requestFullscreen || shell.webkitRequestFullscreen;
    if (!request) {
      showMessage("Этот браузер не поддерживает полноэкранный режим для игры.");
      return;
    }

    try {
      Promise.resolve(request.call(shell)).then(() => {
        syncButtons();
        canvas.focus();
      }).catch((error) => {
        console.warn("Fullscreen request denied:", error);
        showMessage("Браузер запретил полноэкранный режим. Если игра во встроенном окне, откройте её отдельной вкладкой.");
        syncButtons();
      });
    } catch (error) {
      console.warn("Fullscreen request failed:", error);
      showMessage("Не удалось включить полноэкранный режим в этом браузере.");
      syncButtons();
    }
  }

  function leaveFullscreen() {
    if (closed) return;
    canvas.focus();
    showMessage("");
    if (!fullscreenElement()) {
      showMessage("Оконный режим уже включён.");
      syncButtons();
      canvas.focus();
      return;
    }
    const exit = document.exitFullscreen || document.webkitExitFullscreen;
    if (!exit) {
      showMessage("Нажмите Esc, чтобы выйти из полноэкранного режима.");
      return;
    }
    try {
      Promise.resolve(exit.call(document)).then(() => {
        syncButtons();
        canvas.focus();
      }).catch((error) => {
        console.warn("Exit fullscreen failed:", error);
        showMessage("Нажмите Esc, чтобы выйти из полноэкранного режима.");
        syncButtons();
      });
    } catch (error) {
      console.warn("Exit fullscreen failed:", error);
      showMessage("Нажмите Esc, чтобы выйти из полноэкранного режима.");
      syncButtons();
    }
  }

  function showStopped() {
    if (closed) return;
    closed = true;
    window.potapGameReady = false;
    canvas.style.visibility = "hidden";
    stopped.hidden = false;
    showMessage("");
    syncButtons();
  }

  window.potapOnReady = () => {
    window.potapGameReady = true;
    syncButtons();
  };

  window.potapOnExit = showStopped;

  // Arrow keys navigate the game; Space jumps. Never let a focused
  // toolbar button turn those inputs into an accidental click ("Exit").
  const GAME_KEYS = new Set([
    "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown",
    " ", "Spacebar", "Shift", "Control", "Alt",
    "a", "d", "w", "s"
  ]);
  toolbar.addEventListener("keydown", (event) => {
    if (closed || !GAME_KEYS.has(event.key.toLowerCase().length === 1 && event.key !== " " ? event.key.toLowerCase() : event.key)) return;
    event.preventDefault();
    canvas.focus();
  });

  // Mouse use of toolbar controls must not leave keyboard focus on a
  // button. In particular, Space must keep jumping after any toolbar click.
  for (const button of [windowButton, fullscreenButton, closeButton]) {
    button.addEventListener("mousedown", (event) => {
      event.preventDefault();
      if (!closed) canvas.focus();
    });
  }

  fullscreenButton.addEventListener("click", enterFullscreen);
  windowButton.addEventListener("click", leaveFullscreen);
  closeButton.addEventListener("click", () => {
    if (closed) return;
    try { engine.requestQuit(); } catch (error) { console.warn("Cannot stop game:", error); }
    showStopped();
    if (fullscreenElement()) {
      const exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (exit) {
        try { Promise.resolve(exit.call(document)).catch(() => {}); } catch (_) { /* ignore */ }
      }
    }
  });

  document.addEventListener("fullscreenchange", syncButtons);
  document.addEventListener("webkitfullscreenchange", syncButtons);
  window.addEventListener("resize", resizeGame);
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(resizeGame).observe(view);
  syncButtons();
})();
