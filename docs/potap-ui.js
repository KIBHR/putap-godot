/* Web-only presentation controls. The Godot canvas stays at 256x256 internally. */
(() => {
  "use strict";
  const shell = document.getElementById("game-shell");
  const view = document.getElementById("game-view");
  const frame = document.getElementById("game-frame");
  const canvas = document.getElementById("canvas");
  const stopped = document.getElementById("game-stopped");
  const windowButton = document.getElementById("window-mode");
  const fullscreenButton = document.getElementById("fullscreen-mode");
  const closeButton = document.getElementById("close-game");
  const message = document.getElementById("game-message");
  const GAME_PIXELS = 256;
  let closed = false;

  function resizeGame() {
    const usableWidth = Math.max(1, view.clientWidth - 24);
    const usableHeight = Math.max(1, view.clientHeight - 24);
    const maxScale = Math.min(usableWidth, usableHeight) / GAME_PIXELS;
    const scale = maxScale >= 1 ? Math.floor(maxScale) : maxScale;
    const side = Math.max(1, Math.floor(GAME_PIXELS * scale));
    frame.style.width = side + "px";
    frame.style.height = side + "px";
  }

  function syncButtons() {
    const full = document.fullscreenElement === shell;
    windowButton.disabled = !full || closed;
    fullscreenButton.disabled = full || closed;
    closeButton.disabled = closed || !window.potapGameReady;
  }

  async function enterFullscreen() {
    message.textContent = "";
    try {
      if (shell.requestFullscreen) {
        await shell.requestFullscreen();
      } else {
        throw new Error("Fullscreen API is unavailable");
      }
      canvas.focus();
    } catch (_) {
      message.textContent = "Браузер не разрешил полноэкранный режим.";
    }
    syncButtons();
  }

  async function leaveFullscreen() {
    message.textContent = "";
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      canvas.focus();
    } catch (_) {
      message.textContent = "Не удалось вернуться в оконный режим. Нажмите Esc.";
    }
    syncButtons();
  }

  function showStopped() {
    if (closed) return;
    closed = true;
    window.potapGameReady = false;
    canvas.style.visibility = "hidden";
    stopped.hidden = false;
    message.textContent = "";
    syncButtons();
  }

  window.potapOnReady = () => {
    window.potapGameReady = true;
    syncButtons();
    resizeGame();
  };
  window.potapOnExit = () => {
    showStopped();
  };

  fullscreenButton.addEventListener("click", enterFullscreen);
  windowButton.addEventListener("click", leaveFullscreen);
  closeButton.addEventListener("click", () => {
    if (closed) return;
    // A web page cannot close an ordinary browser tab; stop the Godot instance.
    try { engine.requestQuit(); } catch (err) { console.warn("Cannot stop game:", err); }
    showStopped();
    if (document.fullscreenElement === shell) {
      document.exitFullscreen().catch(() => {});
    }
  });

  document.addEventListener("fullscreenchange", () => {
    syncButtons();
    resizeGame();
  });
  window.addEventListener("resize", resizeGame);
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(resizeGame).observe(view);
  syncButtons();
  resizeGame();
})();
