(() => {
  const root = document.documentElement;
  const savedTheme = localStorage.getItem('theme');
  const prefersLight = window.matchMedia('(prefers-color-scheme: light)').matches;
  root.dataset.theme = savedTheme || (prefersLight ? 'light' : 'dark');

  const themeButton = document.querySelector('.theme-toggle');
  const syncThemeButton = () => {
    if (!themeButton) return;
    const isLight = root.dataset.theme === 'light';
    themeButton.setAttribute('aria-pressed', String(isLight));
    themeButton.textContent = isLight ? '◑' : '◐';
  };
  syncThemeButton();
  themeButton?.addEventListener('click', () => {
    root.dataset.theme = root.dataset.theme === 'light' ? 'dark' : 'light';
    localStorage.setItem('theme', root.dataset.theme);
    syncThemeButton();
  });

  const menuButton = document.querySelector('.menu-toggle');
  const navigation = document.querySelector('.primary-nav');
  menuButton?.addEventListener('click', () => {
    const isOpen = navigation?.classList.toggle('is-open') || false;
    menuButton.setAttribute('aria-expanded', String(isOpen));
  });

  const input = document.querySelector('#post-filter');
  const items = [...document.querySelectorAll('[data-search-item]')];
  const chips = [...document.querySelectorAll('[data-category]')];
  const result = document.querySelector('#filter-result');
  const empty = document.querySelector('#filter-empty');
  let category = 'all';
  const filter = () => {
    const query = (input?.value || '').trim().toLowerCase();
    let visible = 0;
    items.forEach((item) => {
      const textMatched = !query || item.dataset.searchText.includes(query);
      const categoryMatched = category === 'all' || item.dataset.categories.split(' ').includes(category);
      const matched = textMatched && categoryMatched;
      item.hidden = !matched;
      if (matched) visible += 1;
    });
    if (result) result.textContent = `显示 ${visible} 篇文章`;
    if (empty) empty.hidden = visible !== 0;
  };
  input?.addEventListener('input', filter);
  chips.forEach((chip) => chip.addEventListener('click', () => {
    category = chip.dataset.category;
    chips.forEach((item) => item.classList.toggle('is-active', item === chip));
    filter();
  }));
  document.addEventListener('keydown', (event) => {
    if (event.key === '/' && document.activeElement?.tagName !== 'INPUT' && input) {
      event.preventDefault();
      input.focus();
    }
  });
})();
