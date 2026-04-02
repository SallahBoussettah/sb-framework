(function() {
    const crosshair = document.getElementById('crosshair');
    const contextMenu = document.getElementById('context-menu');
    const menuOptions = document.getElementById('menu-options');

    // NUI Message Handler
    window.addEventListener('message', function(event) {
        const data = event.data;

        switch (data.action) {
            case 'showCrosshair':
                showCrosshair(data.hasTarget);
                break;
            case 'hideCrosshair':
                hideCrosshair();
                break;
            case 'showMenu':
                showMenu(data.options);
                break;
            case 'hideMenu':
                hideMenu();
                break;
        }
    });

    function showCrosshair(hasTarget) {
        crosshair.classList.remove('hidden');
        if (hasTarget) {
            crosshair.classList.add('has-target');
        } else {
            crosshair.classList.remove('has-target');
        }
    }

    function hideCrosshair() {
        crosshair.classList.add('hidden');
        crosshair.classList.remove('has-target');
    }

    function showMenu(options) {
        if (!options || options.length === 0) {
            hideMenu();
            return;
        }

        menuOptions.innerHTML = '';
        contextMenu.classList.remove('hidden', 'hiding');

        options.forEach(function(opt, index) {
            const el = document.createElement('div');
            el.className = 'menu-option';
            el.style.animationDelay = (index * 30) + 'ms';

            el.innerHTML = `
                <div class="option-icon">
                    <i class="fas ${opt.icon}"></i>
                </div>
                <span class="option-label">${opt.label}</span>
            `;

            el.addEventListener('click', function() {
                selectOption(opt.index);
            });

            menuOptions.appendChild(el);
        });
    }

    function hideMenu() {
        if (!contextMenu.classList.contains('hidden')) {
            contextMenu.classList.add('hiding');
            setTimeout(function() {
                contextMenu.classList.add('hidden');
                contextMenu.classList.remove('hiding');
                menuOptions.innerHTML = '';
            }, 150);
        }
    }

    function selectOption(index) {
        fetch('https://sb_target/selectOption', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ index: index })
        });
    }

    // Prevent right-click context menu
    document.addEventListener('contextmenu', function(e) {
        e.preventDefault();
    });

    // ESC to close
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            fetch('https://sb_target/closeTarget', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        }
    });
})();
