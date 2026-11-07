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
  const saveButton = document.getElementById("save-game");
  const loadButton = document.getElementById("load-game");
  const newButton = document.getElementById("new-game");
  const continueButton = document.getElementById("continue-game");
  const startPanel = document.getElementById("game-start");
  const helpButton = document.getElementById("show-help");
  const helpPanel = document.getElementById("controls-help");
  const pauseButton = document.getElementById("pause-game");
  const audioButton = document.getElementById("toggle-audio");
  const pauseOverlay = document.getElementById("game-paused");
  const message = document.getElementById("game-message");

  const GAME_PIXELS = 256;
  let closed = false;
  let paused = false;
  let audioEnabled = true;
  let helpAutoPaused = false;
  let gameAudioContext = null;
  let masterGain = null;

  // Intercept the connection of the Godot Web Audio output to the speakers.
  // A dedicated GainNode mutes audio reliably, even when Godot automatically
  // resumes AudioContext after a keyboard/mouse gesture.
  const audioNodePrototype = window.AudioNode && window.AudioNode.prototype;
  if (audioNodePrototype && typeof audioNodePrototype.connect === "function") {
    const originalConnect = audioNodePrototype.connect;
    audioNodePrototype.connect = function (destination, ...options) {
      if (masterGain && this !== masterGain &&
          this.context === gameAudioContext &&
          destination === gameAudioContext.destination) {
        return originalConnect.call(this, masterGain, ...options);
      }
      return originalConnect.call(this, destination, ...options);
    };
  }

  // Install before Godot starts, without modifying generated .pck/.wasm.
  for (const name of ["AudioContext", "webkitAudioContext"]) {
    const NativeContext = window[name];
    if (typeof NativeContext !== "function") continue;
    try {
      window[name] = class PotapAudioContext extends NativeContext {
        constructor(...args) {
          super(...args);
          gameAudioContext = this;
          masterGain = null;
          if (audioNodePrototype && typeof this.createGain === "function") {
            masterGain = this.createGain();
            masterGain.gain.value = 1;
            masterGain.connect(this.destination);
          }
        }
      };
    } catch (error) {
      console.warn("Cannot monitor WebAudio context:", error);
    }
  }

  function applyAudioState() {
    const audible = audioEnabled && !paused;
    if (masterGain) {
      masterGain.gain.value = audible ? 1 : 0;
      return;
    }
    if (!gameAudioContext) return;
    // Compatibility fallback for browsers without AudioNode.connect patch.
    const operation = audible ? "resume" : "suspend";
    try {
      Promise.resolve(gameAudioContext[operation]()).catch((error) => {
        console.warn("WebAudio " + operation + " rejected:", error);
        showMessage("Браузер ограничил доступ к звуку. Попробуйте нажать кнопку снова.");
      });
    } catch (error) {
      console.warn("WebAudio " + operation + " failed:", error);
      showMessage("Не удалось изменить состояние звука.");
    }
  }

  function syncPlaybackButtons() {
    pauseButton.textContent = paused ? "▶ Продолжить (P)" : "⏸ Пауза (P)";
    pauseButton.disabled = closed || !window.potapGameReady;
    audioButton.textContent = audioEnabled ? "♫ Музыка: ВКЛ (M)" : "♫ Музыка: ВЫКЛ (M)";
    audioButton.disabled = closed || !window.potapGameReady;
    pauseOverlay.hidden = !paused || closed;
    pauseButton.setAttribute("aria-pressed", String(paused));
    audioButton.setAttribute("aria-pressed", String(audioEnabled));
  }

  function togglePause() {
    if (closed || !window.potapGameReady) return;
    const runtime = engine && engine.rtenv;
    if (!runtime || typeof runtime.pauseMainLoop !== "function" || typeof runtime.resumeMainLoop !== "function") {
      showMessage("Пауза недоступна в этой браузерной сборке.");
      return;
    }
    try {
      if (paused) runtime.resumeMainLoop();
      else runtime.pauseMainLoop();
      paused = !paused;
      applyAudioState();
      syncPlaybackButtons();
      canvas.focus();
      showMessage("");
    } catch (error) {
      console.warn("Cannot toggle game pause:", error);
      showMessage("Не удалось переключить паузу.");
    }
  }

  function toggleAudio() {
    if (closed || !window.potapGameReady) return;
    if (!gameAudioContext) {
      showMessage("Звуковое устройство ещё не готово.");
      return;
    }
    audioEnabled = !audioEnabled;
    applyAudioState();
    syncPlaybackButtons();
    canvas.focus();
    showMessage("");
  }

  function closeGame() {
    if (closed) return;
    // Exit must also work while Emscripten's main loop is paused.
    if (paused && engine && engine.rtenv && typeof engine.rtenv.resumeMainLoop === "function") {
      try { engine.rtenv.resumeMainLoop(); } catch (error) { console.warn(error); }
    }
    paused = false;
    try { engine.requestQuit(); } catch (error) { console.warn("Cannot stop game:", error); }
    showStopped();
    if (fullscreenElement()) {
      const exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (exit) {
        try { Promise.resolve(exit.call(document)).catch(() => {}); } catch (_) { /* ignore */ }
      }
    }
  }

  // Updated Web builds expose these events from GDScript. Old potap.pck
  // files cannot save the game; show controls but do not offer fake saves.
  function syncSaveButtons() {
    const state = window.potapSaveState || {};
    const bridge = window.potapBridgeReady === true;
    const ready = bridge && !!window.potapGameReady && !closed;
    saveButton.disabled = !ready || !state.can_save;
    loadButton.disabled = !ready || !state.has_save;
    continueButton.disabled = !ready || !state.has_save;
    newButton.disabled = !ready;
    startPanel.hidden = !ready || !state.at_title;
    if (state.message && state.message !== window.potapLastSaveMessage) {
      window.potapLastSaveMessage = state.message;
      showMessage(state.message);
    }
  }
  window.potapUpdateSaveControls = syncSaveButtons;

  function sendSaveAction(name) {
    if (closed || !window.potapGameReady || !window.potapBridgeReady) {
      showMessage("Для сохранений нужна обновлённая Web-сборка игры.");
      return;
    }
    if ((name === "potap-load" || name === "potap-new" || name === "potap-continue") && paused) {
      togglePause();
    }
    if (name !== "potap-save" && !helpPanel.hidden) {
      helpPanel.hidden = true;
      helpAutoPaused = false;
    }
    window.dispatchEvent(new Event(name));
    canvas.focus();
  }

  function toggleHelp() {
    if (closed) return;
    if (helpPanel.hidden) {
      helpPanel.hidden = false;
      helpAutoPaused = false;
      if (window.potapGameReady && !paused) {
        togglePause();
        helpAutoPaused = paused;
      }
    } else {
      helpPanel.hidden = true;
      if (helpAutoPaused && paused) togglePause();
      helpAutoPaused = false;
    }
    helpButton.setAttribute("aria-expanded", String(!helpPanel.hidden));
    resizeGame();
    canvas.focus();
  }

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
    syncPlaybackButtons();
    syncSaveButtons();
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
    paused = false;
    canvas.style.visibility = "hidden";
    stopped.hidden = false;
    startPanel.hidden = true;
    helpPanel.hidden = true;
    syncSaveButtons();
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
    const key = event.key.length === 1 && event.key !== " "
      ? event.key.toLowerCase() : event.key;
    if (closed || !GAME_KEYS.has(key)) return;
    event.preventDefault();
    canvas.focus();
  });

  // Mouse use of toolbar controls must not leave keyboard focus on a
  // button. In particular, Space must keep jumping after any toolbar click.
  for (const button of [windowButton, fullscreenButton, closeButton, pauseButton, audioButton,
                        saveButton, loadButton, newButton, continueButton, helpButton]) {
    button.addEventListener("mousedown", (event) => {
      event.preventDefault();
      if (!closed) canvas.focus();
    });
  }

  fullscreenButton.addEventListener("click", enterFullscreen);
  windowButton.addEventListener("click", leaveFullscreen);
  pauseButton.addEventListener("click", togglePause);
  audioButton.addEventListener("click", toggleAudio);
  closeButton.addEventListener("click", closeGame);
  saveButton.addEventListener("click", () => sendSaveAction("potap-save"));
  loadButton.addEventListener("click", () => sendSaveAction("potap-load"));
  continueButton.addEventListener("click", () => sendSaveAction("potap-continue"));
  newButton.addEventListener("click", () => sendSaveAction("potap-new"));
  helpButton.addEventListener("click", toggleHelp);

  // Handle shortcuts before Godot or an HTML button receives them. Enter
  // and Esc are reserved for the window and exit; P and M are options.
  document.addEventListener("keydown", (event) => {
    if (closed || !window.potapGameReady || event.repeat) return;
    if (event.altKey || event.metaKey || event.ctrlKey) return;
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      if (isFullscreen()) leaveFullscreen();
      else enterFullscreen();
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      closeGame();
    } else if (event.code === "KeyP" || event.key.toLowerCase() === "p") {
      event.preventDefault();
      event.stopPropagation();
      togglePause();
    } else if (event.code === "KeyM" || event.key.toLowerCase() === "m") {
      event.preventDefault();
      event.stopPropagation();
      toggleAudio();
    } else if (event.code === "KeyH" || event.key.toLowerCase() === "h") {
      event.preventDefault();
      event.stopPropagation();
      toggleHelp();
    } else if (event.key === "F5") {
      if (window.potapBridgeReady) {
        event.preventDefault();
        event.stopPropagation();
        sendSaveAction("potap-save");
      }
    } else if (event.key === "F9") {
      if (window.potapBridgeReady) {
        event.preventDefault();
        event.stopPropagation();
        sendSaveAction("potap-load");
      }
    } else if ((event.code === "KeyC" || event.key.toLowerCase() === "c") &&
               window.potapSaveState?.at_title) {
      event.preventDefault();
      event.stopPropagation();
      sendSaveAction("potap-continue");
    } else if ((event.code === "KeyN" || event.key.toLowerCase() === "n") &&
               window.potapSaveState?.at_title) {
      event.preventDefault();
      event.stopPropagation();
      sendSaveAction("potap-new");
    }
  }, true);

  document.addEventListener("fullscreenchange", syncButtons);
  document.addEventListener("webkitfullscreenchange", syncButtons);
  window.addEventListener("resize", resizeGame);
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(resizeGame).observe(view);
  syncButtons();
})();
