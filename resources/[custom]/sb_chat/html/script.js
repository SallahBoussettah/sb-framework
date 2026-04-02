(function() {
    const messageList = document.getElementById('message-list');
    const inputArea = document.getElementById('input-area');
    const chatInput = document.getElementById('chat-input');
    const commandSuggestions = document.getElementById('command-suggestions');

    const chatContainer = document.getElementById('chat-container');

    let suggestions = [];
    let messages = [];
    let maxMessages = 100;
    let fadeTime = 15000;
    let isOpen = false;
    let selectedSuggestion = -1;
    let filteredSuggestions = [];
    let hideTimer = null;
    let inputHistory = [];
    let historyIndex = -1;
    let maxHistory = 50;

    // Listen for NUI messages from client
    window.addEventListener('message', function(event) {
        var data = event.data;

        switch (data.type) {
            case 'open':
                openChat(data.defaultText || '');
                break;
            case 'close':
                closeChat();
                break;
            case 'addMessage':
                addMessage(data.message);
                break;
            case 'clearChat':
                clearChat();
                break;
            case 'setSuggestions':
                suggestions = data.suggestions || [];
                break;
            case 'showTemporary':
                revealAllMessages();
                break;
        }
    });

    function showContainer() {
        if (hideTimer) {
            clearTimeout(hideTimer);
            hideTimer = null;
        }
        chatContainer.classList.remove('auto-hidden');
    }

    function scheduleAutoHide() {
        if (hideTimer) clearTimeout(hideTimer);
        // Hide container 2s after last message finishes fading
        hideTimer = setTimeout(function() {
            if (!isOpen) {
                chatContainer.classList.add('auto-hidden');
            }
        }, 2000);
    }

    function openChat(defaultText) {
        isOpen = true;
        showContainer();
        inputArea.classList.remove('hidden');
        inputArea.classList.add('focused');
        chatInput.value = defaultText;
        chatInput.focus();
        revealAllMessages();
    }

    function closeChat() {
        isOpen = false;
        inputArea.classList.add('hidden');
        inputArea.classList.remove('focused');
        commandSuggestions.classList.add('hidden');
        chatInput.value = '';
        selectedSuggestion = -1;

        // Restart fade timers for all messages
        messages.forEach(function(msg) {
            startFadeTimer(msg);
        });
    }

    function revealAllMessages() {
        messages.forEach(function(msg) {
            if (msg.fadeTimer) {
                clearTimeout(msg.fadeTimer);
                msg.fadeTimer = null;
            }
            msg.el.style.opacity = '1';
            msg.el.classList.remove('fading');
        });
    }

    function startFadeTimer(msg) {
        if (msg.fadeTimer) {
            clearTimeout(msg.fadeTimer);
        }

        var elapsed = Date.now() - msg.timestamp;
        var remaining = fadeTime - elapsed;

        if (remaining <= 0) {
            msg.el.classList.add('fading');
            scheduleAutoHide();
        } else {
            msg.fadeTimer = setTimeout(function() {
                msg.el.classList.add('fading');
                msg.fadeTimer = null;
                scheduleAutoHide();
            }, remaining);
        }
    }

    function addMessage(msgData) {
        if (!msgData) return;

        // Show chat when new message arrives
        showContainer();

        var msgEl = document.createElement('div');
        msgEl.className = 'message';

        var borderColor = msgData.color || '#ff6b35';
        msgEl.style.borderLeftColor = borderColor;

        var html = '';

        if (msgData.isAction) {
            msgEl.classList.add('action-message');
            msgEl.style.borderLeftColor = msgData.color || '#fbbf24';
            html += '<span class="action-text" style="color: ' + (msgData.color || '#fbbf24') + ';">* ' + escapeHtml(msgData.sender) + ' ' + escapeHtml(msgData.text) + '</span>';
        } else if (msgData.isSystem) {
            msgEl.classList.add('system-message');
            msgEl.style.borderLeftColor = msgData.color || '#22c55e';
            html += '<span class="prefix-tag" style="background: ' + hexToRgba(msgData.color || '#22c55e', 0.15) + '; color: ' + (msgData.color || '#22c55e') + ';">' + escapeHtml(msgData.prefix || 'SYSTEM') + '</span>';
            html += '<span class="msg-text">' + escapeHtml(msgData.text) + '</span>';
        } else if (msgData.prefix && msgData.prefix !== '') {
            html += '<span class="prefix-tag" style="background: ' + hexToRgba(msgData.color, 0.15) + '; color: ' + msgData.color + ';">' + escapeHtml(msgData.prefix) + '</span>';
            html += '<span class="sender" style="color: ' + msgData.color + ';">' + escapeHtml(msgData.sender) + ':</span>';
            html += '<span class="msg-text">' + escapeHtml(msgData.text) + '</span>';
        } else {
            html += '<span class="sender" style="color: ' + borderColor + ';">' + escapeHtml(msgData.sender) + ':</span>';
            html += '<span class="msg-text">' + escapeHtml(msgData.text) + '</span>';
        }

        msgEl.innerHTML = html;
        messageList.appendChild(msgEl);

        var msgObj = {
            el: msgEl,
            timestamp: Date.now(),
            fadeTimer: null
        };
        messages.push(msgObj);

        while (messages.length > maxMessages) {
            var old = messages.shift();
            if (old.fadeTimer) clearTimeout(old.fadeTimer);
            if (old.el && old.el.parentNode) {
                old.el.parentNode.removeChild(old.el);
            }
        }

        messageList.scrollTop = messageList.scrollHeight;

        if (!isOpen) {
            startFadeTimer(msgObj);
        }
    }

    function clearChat() {
        messages.forEach(function(msg) {
            if (msg.fadeTimer) clearTimeout(msg.fadeTimer);
        });
        messages = [];
        messageList.innerHTML = '';
    }

    function escapeHtml(text) {
        if (!text) return '';
        var div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function hexToRgba(hex, alpha) {
        if (!hex) return 'rgba(255,107,53,' + alpha + ')';
        hex = hex.replace('#', '');
        var r = parseInt(hex.substring(0, 2), 16);
        var g = parseInt(hex.substring(2, 4), 16);
        var b = parseInt(hex.substring(4, 6), 16);
        return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
    }

    // ============================================================
    // INPUT & SUGGESTIONS
    // ============================================================

    chatInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();

            if (selectedSuggestion >= 0 && filteredSuggestions.length > 0) {
                chatInput.value = filteredSuggestions[selectedSuggestion].command + ' ';
                hideSuggestions();
                return;
            }

            var message = chatInput.value.trim();

            // Save to input history
            if (message.length > 0) {
                inputHistory.unshift(message);
                if (inputHistory.length > maxHistory) {
                    inputHistory.pop();
                }
            }
            historyIndex = -1;

            fetch('https://sb_chat/chatMessage', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: message })
            });

        } else if (e.key === 'Escape') {
            e.preventDefault();
            fetch('https://sb_chat/closeChat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });

        } else if (e.key === 'ArrowUp') {
            if (filteredSuggestions.length > 0) {
                e.preventDefault();
                selectedSuggestion = Math.max(0, selectedSuggestion - 1);
                updateSuggestionHighlight();
            } else if (inputHistory.length > 0) {
                // Navigate input history (older)
                e.preventDefault();
                historyIndex = Math.min(historyIndex + 1, inputHistory.length - 1);
                chatInput.value = inputHistory[historyIndex];
            }

        } else if (e.key === 'ArrowDown') {
            if (filteredSuggestions.length > 0) {
                e.preventDefault();
                selectedSuggestion = Math.min(filteredSuggestions.length - 1, selectedSuggestion + 1);
                updateSuggestionHighlight();
            } else if (historyIndex >= 0) {
                // Navigate input history (newer)
                e.preventDefault();
                historyIndex--;
                if (historyIndex < 0) {
                    chatInput.value = '';
                } else {
                    chatInput.value = inputHistory[historyIndex];
                }
            }

        } else if (e.key === 'Tab') {
            if (filteredSuggestions.length > 0) {
                e.preventDefault();
                var idx = selectedSuggestion >= 0 ? selectedSuggestion : 0;
                chatInput.value = filteredSuggestions[idx].command + ' ';
                hideSuggestions();
            }
        }
    });

    chatInput.addEventListener('input', function() {
        var value = chatInput.value;

        // Only show suggestions after at least 1 char typed after /
        if (value.startsWith('/') && !value.includes(' ') && value.length > 1) {
            var partial = value.toLowerCase();

            filteredSuggestions = suggestions.filter(function(sug) {
                return sug.command.toLowerCase().startsWith(partial);
            }).slice(0, 8);

            if (filteredSuggestions.length > 0) {
                selectedSuggestion = -1;
                renderSuggestions();
                commandSuggestions.classList.remove('hidden');
            } else {
                hideSuggestions();
            }
        } else {
            hideSuggestions();
        }
    });

    function hideSuggestions() {
        commandSuggestions.classList.add('hidden');
        selectedSuggestion = -1;
        filteredSuggestions = [];
    }

    function renderSuggestions() {
        commandSuggestions.innerHTML = '';
        filteredSuggestions.forEach(function(sug, index) {
            var item = document.createElement('div');
            item.className = 'suggestion-item' + (index === selectedSuggestion ? ' active' : '');

            // Build: /command param1 param2 — description
            var paramsText = '';
            if (sug.params && sug.params.length > 0) {
                sug.params.forEach(function(p) {
                    paramsText += ' [' + (p.name || 'arg') + ']';
                });
            }

            var html = '<span class="suggestion-cmd">' + escapeHtml(sug.command) + '</span>';
            if (paramsText) {
                html += '<span class="suggestion-params">' + escapeHtml(paramsText) + '</span>';
            }
            if (sug.description) {
                html += '<span class="suggestion-desc">' + escapeHtml(sug.description) + '</span>';
            }

            item.innerHTML = html;

            item.addEventListener('click', function() {
                chatInput.value = sug.command + ' ';
                hideSuggestions();
                chatInput.focus();
            });

            commandSuggestions.appendChild(item);
        });
    }

    function updateSuggestionHighlight() {
        var items = commandSuggestions.querySelectorAll('.suggestion-item');
        items.forEach(function(item, i) {
            if (i === selectedSuggestion) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }
})();
