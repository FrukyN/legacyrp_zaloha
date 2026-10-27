window.APP = {
  template: '#app_template',
  name: 'app',
  data () {
    return {
      style: CONFIG.style,
      showInput: false,
      showWindow: false,
      suggestions: [],
      templates: CONFIG.templates,
      message: '',
      maxAreaChar: 200,
      maxMessages: 100,
      messages: [],
      oldMessages: [],
      oldMessagesIndex: -1,
      showChat: true,
      time2: 0,
      loocTime: 0,
      isError: false,
      isError2: false,
      isChatHidden: false
    };
  },
  destroyed () {
    clearInterval(this.focusTimer);
    window.removeEventListener('message', this.listener);
  },
  mounted () {
    this.$nextTick(function () {
      window.setInterval(() => {
        this.loocTime = this.time2 - Math.round(new Date().getTime() / 1000);
      }, 1000);
    });

    post('https://chat/loaded', JSON.stringify({}));

    this.listener = window.addEventListener('message', (event) => {
      const item = event.data || event.detail;
      if (this[item.type]) {
        this[item.type](item);
      }
    });
  },
  watch: {
    messages () {
      if (this.isChatHidden) return;

      if (this.showWindowTimer) {
        clearTimeout(this.showWindowTimer);
      }
      this.showWindow = true;
      this.resetShowWindowTimer();

      const messagesObj = this.$refs.messages;
      this.$nextTick(() => {
        if (messagesObj) {
          messagesObj.scrollTop = messagesObj.scrollHeight;
        }
      });
    },
  },
  methods: {
    // Okamžité skrytí celého DOM elementu
    SET_CHAT_HIDDEN ({ state }) {
      this.isChatHidden = state;
      const appEl = document.getElementById('app');

      if (state) {
        this.hideInput(true);
        this.showWindow = false;
        if (appEl) appEl.style.display = 'none';
      } else {
        if (appEl) appEl.style.display = 'block';
      }
    },
    ON_SCREEN_STATE_CHANGE ({ shouldHide }) {
      const appEl = document.getElementById('app');
      if (shouldHide || this.isChatHidden) {
        if (appEl) appEl.style.display = 'none';
      } else {
        if (appEl) appEl.style.display = 'block';
      }
    },
    ON_HIDE () {
      this.SET_CHAT_HIDDEN({ state: true });
    },
    ON_SHOW () {
      this.SET_CHAT_HIDDEN({ state: false });
    },
    editedTextArea () {
      if (!this.message.startsWith('/')) {
        this.maxAreaChar = 200;
        if (this.message.length > 200) {
          this.message = this.message.substring(0, 80);
          this.isError = true;
          setTimeout(() => {
            this.isError = false;
          }, 600);
        }
      } else {
        this.maxAreaChar = 200;
      }
    },
    ON_OPEN () {
      if (this.isChatHidden) return;

      const appEl = document.getElementById('app');
      if (appEl) appEl.style.display = 'block';

      this.showInput = true;
      this.showWindow = true;
      if (this.showWindowTimer) {
        clearTimeout(this.showWindowTimer);
      }
      this.focusTimer = setInterval(() => {
        if (this.$refs.input) {
          this.$refs.input.focus();
        } else {
          clearInterval(this.focusTimer);
        }
      }, 50);
    },
    ON_TIME ({ time }) {
      this.time2 = time;
    },
    ON_MESSAGE ({ message }) {
      if (this.isChatHidden) return;

      this.messages.push(message);
      if (this.messages.length > this.maxMessages) {
        this.messages.splice(0, this.messages.length - this.maxMessages);
      }
    },
    ON_CLEAR () {
      this.messages = [];
      this.oldMessages = [];
      this.oldMessagesIndex = -1;
    },
    ON_SUGGESTION_ADD ({ suggestion }) {
      if (!suggestion.params) {
        suggestion.params = [];
      }
      if (this.suggestions.find(a => a.name == suggestion.name)) {
        return;
      }
      this.suggestions.push(suggestion);
    },
    ON_SUGGESTIONS_ADD ({ suggestions }) {
      suggestions.forEach((suggestion) => {
        this.ON_SUGGESTION_ADD({ suggestion });
      });
    },
    ON_SUGGESTION_REMOVE ({ name }) {
      this.suggestions = this.suggestions.filter((sug) => sug.name !== name);
    },
    ON_TEMPLATE_ADD ({ template }) {
      if (this.templates[template.id]) {
        this.warn(`Tried to add duplicate template '${template.id}'`);
      } else {
        this.templates[template.id] = template.html;
      }
    },
    warn (msg) {
      this.messages.push({
        args: [msg],
        template: '^3<b>CHAT-WARN</b>: ^0{0}',
      });
    },
    clearShowWindowTimer () {
      clearTimeout(this.showWindowTimer);
    },
    resetShowWindowTimer () {
      this.clearShowWindowTimer();
      this.showWindowTimer = setTimeout(() => {
        if (!this.showInput) {
          this.showWindow = false;
        }
      }, CONFIG.fadeTimeout || 3000);
    },
    keyUp () {
      this.resize();
    },
    keyDown (e) {
      if (e.which === 38 || e.which === 40) {
        e.preventDefault();
        this.moveOldMessageIndex(e.which === 38);
      } else if (e.which == 33) {
        var buf = this.$refs.messages;
        if (buf) buf.scrollTop = buf.scrollTop - 100;
      } else if (e.which == 34) {
        var buf = this.$refs.messages;
        if (buf) buf.scrollTop = buf.scrollTop + 100;
      }
    },
    moveOldMessageIndex (up) {
      if (up && this.oldMessages.length > this.oldMessagesIndex + 1) {
        this.oldMessagesIndex += 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 >= 0) {
        this.oldMessagesIndex -= 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 === -1) {
        this.oldMessagesIndex = -1;
        this.message = '';
      }
    },
    resize () {
      const input = this.$refs.input;
      if (!input) return;
      input.style.height = '5px';
      input.style.height = `${input.scrollHeight + 2}px`;
    },
    send (e) {
      if (this.loocTime > 0 && !this.message.startsWith('/')) {
        if (!this.isError2) {
          this.ON_MESSAGE({
            message: {
              color: null,
              args: [`Chat ^7> ^1Musíš počkat ${this.loocTime} sekund než budeš moct poslat další zprávu do looc!`],
              multiline: true,
            }
          });
          this.isError2 = true;
          setTimeout(() => {
            this.isError2 = false;
          }, 1000);
        }
        return;
      }
      if (this.message !== '') {
        post('https://chat/chatResult', JSON.stringify({
          message: this.message,
        }));
        this.oldMessages.unshift(this.message);
        this.oldMessagesIndex = -1;
        this.hideInput();
      } else {
        this.hideInput(true);
      }
    },
hideInput (canceled = false) {
  if (canceled) {
    post('https://chat/chatResult', JSON.stringify({ canceled }));
  }
      this.message = '';
      this.showInput = false;
      clearInterval(this.focusTimer);
      this.resetShowWindowTimer();
    },
  },
};