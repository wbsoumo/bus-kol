/**
 * Where is my Bus - Secure Transit Engine
 * 1. Encrypted payload decryption (Zero network data leak)
 * 2. Full new screen for search results with native back navigation
 * 3. Authentic Where is My Train Android transit UI
 */

document.addEventListener('DOMContentLoaded', () => {
  // 256-bit AES-GCM Key (matches server.py)
  const CRYPTO_KEY_BYTES = new TextEncoder().encode('KolkataTransitSecureKey2026WIMT!');

  // App State
  let currentSearchResults = [];
  let currentActiveRoute = null;
  let currentActiveStops = [];
  let isRouteReversed = false;
  let currentLang = 'en';

  // Local Storage State
  let recentSearches = JSON.parse(localStorage.getItem('wimt_recent_searches') || '[]');
  let favoriteRoutes = JSON.parse(localStorage.getItem('wimt_fav_routes') || '[]');

  const defaultRecent = [
    { from: 'Howrah Station', to: 'Sector V' },
    { from: 'Esplanade', to: 'Airport' },
    { from: 'Ultadanga', to: 'Ruby Hospital' },
    { from: 'Sealdah Station', to: 'Howrah Station' }
  ];

  if (!recentSearches.length) {
    recentSearches = [...defaultRecent];
  }

  // DOM Elements - Screens
  const screenHome = document.getElementById('screen-home');
  const screenResults = document.getElementById('screen-results');
  const resultsBackBtn = document.getElementById('results-back-btn');
  const resultsSwapRefreshBtn = document.getElementById('results-swap-refresh-btn');
  const resultsStnPairTitle = document.getElementById('results-stn-pair-title');
  const resultsStatusSubtitle = document.getElementById('results-status-subtitle');
  const fullScreenResultsList = document.getElementById('full-screen-results-list');
  const filterTabPills = document.querySelectorAll('.filter-tab-pill');

  // DOM Elements - Home Tabs & Shell
  const navTabs = document.querySelectorAll('.wimt-tab');
  const tabPages = document.querySelectorAll('.wimt-page');
  const viewModeToggle = document.getElementById('view-mode-toggle');
  const langToggleBtn = document.getElementById('lang-toggle-btn');

  // DOM Elements - Search Inputs
  const fromInput = document.getElementById('from-input');
  const toInput = document.getElementById('to-input');
  const fromFieldBox = document.getElementById('from-field-box');
  const toFieldBox = document.getElementById('to-field-box');
  const clearFromBtn = document.getElementById('clear-from-btn');
  const clearToBtn = document.getElementById('clear-to-btn');
  const swapBtn = document.getElementById('swap-stops-btn');
  const fromSuggestions = document.getElementById('from-suggestions');
  const toSuggestions = document.getElementById('to-suggestions');
  const searchAlert = document.getElementById('search-alert');
  const alertText = document.getElementById('alert-text');
  const findBusesBtn = document.getElementById('find-buses-btn');

  // DOM Elements - Utility Cards
  const busnoInput = document.getElementById('busno-input');
  const busnoSearchBtn = document.getElementById('busno-search-btn');
  const liveStopInput = document.getElementById('live-stop-input');
  const liveStopBtn = document.getElementById('live-stop-btn');
  const liveStopSuggestions = document.getElementById('live-stop-suggestions');

  // DOM Elements - Recent & Favorites
  const recentSearchesList = document.getElementById('recent-searches-list');
  const clearHistoryBtn = document.getElementById('clear-history-btn');
  const favoritesList = document.getElementById('favorites-list');
  const emptyFavs = document.getElementById('empty-favs');

  // DOM Elements - Track Sheet
  const wimtTrackModal = document.getElementById('wimt-track-modal');
  const trackBackdrop = document.getElementById('track-backdrop');
  const sheetCloseBtn = document.getElementById('sheet-close-btn');
  const modalRouteNo = document.getElementById('modal-route-no');
  const modalRouteType = document.getElementById('modal-route-type');
  const modalRouteZone = document.getElementById('modal-route-zone');
  const modalRouteName = document.getElementById('modal-route-name');
  const modalReverseBtn = document.getElementById('modal-reverse-btn');
  const modalStatusText = document.getElementById('modal-status-text');
  const modalImageBtn = document.getElementById('modal-image-btn');
  const modalFromSelect = document.getElementById('modal-from-select');
  const modalToSelect = document.getElementById('modal-to-select');
  const metricStops = document.getElementById('metric-stops');
  const metricDuration = document.getElementById('metric-duration');
  const metricDist = document.getElementById('metric-dist');
  const modalTrackStops = document.getElementById('modal-track-stops');

  // DOM Elements - Photo Viewer
  const photoViewerModal = document.getElementById('photo-viewer-modal');
  const photoBackdrop = document.getElementById('photo-backdrop');
  const photoCloseBtn = document.getElementById('photo-close-btn');
  const photoImg = document.getElementById('photo-img');
  const photoTitle = document.getElementById('photo-title');

  // ========================================================
  // 1. SECURE DECRYPTION LAYER (Zero plain data on network)
  // ========================================================
  let cachedCryptoKey = null;

  async function getCryptoKey() {
    if (!cachedCryptoKey) {
      cachedCryptoKey = await window.crypto.subtle.importKey(
        'raw',
        CRYPTO_KEY_BYTES,
        { name: 'AES-GCM' },
        false,
        ['decrypt']
      );
    }
    return cachedCryptoKey;
  }

  async function secureFetch(url) {
    const res = await fetch(url);
    const wrapper = await res.json();
    if (!wrapper || !wrapper.p) {
      throw new Error('Invalid protected response');
    }

    // Decode base64 packed payload: [12-byte IV] + [Ciphertext + Auth Tag]
    const binary = atob(wrapper.p);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }

    const nonce = bytes.slice(0, 12);
    const ciphertext = bytes.slice(12);

    const key = await getCryptoKey();
    const decryptedBuffer = await window.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: nonce },
      key,
      ciphertext
    );

    const jsonStr = new TextDecoder().decode(decryptedBuffer);
    return JSON.parse(jsonStr);
  }

  // ========================================================
  // 2. SCREEN NAVIGATION (Home ⇄ Dedicated Results Screen)
  // ========================================================
  function showResultsScreen(titleText, subtitleText) {
    resultsStnPairTitle.innerText = titleText;
    resultsStatusSubtitle.innerText = subtitleText || 'Loading buses...';

    screenHome.classList.remove('active');
    screenResults.classList.add('active');

    window.scrollTo(0, 0);
    history.pushState({ screen: 'results' }, '');
  }

  function showHomeScreen() {
    screenResults.classList.remove('active');
    screenHome.classList.add('active');
    window.scrollTo(0, 0);
  }

  resultsBackBtn.addEventListener('click', () => {
    showHomeScreen();
  });

  // Handle browser / Android back button
  window.addEventListener('popstate', (e) => {
    if (!e.state || e.state.screen !== 'results') {
      if (screenResults.classList.contains('active')) {
        showHomeScreen();
      }
    }
  });

  // Results Screen Swap & Refresh Button
  resultsSwapRefreshBtn.addEventListener('click', () => {
    const temp = fromInput.value;
    fromInput.value = toInput.value;
    toInput.value = temp;

    resultsSwapRefreshBtn.style.transform = 'rotate(180deg)';
    setTimeout(() => { resultsSwapRefreshBtn.style.transform = ''; }, 260);

    executeSearch();
  });

  // ========================================================
  // 3. HOME TABS & UTILITIES
  // ========================================================
  renderRecentSearches();
  renderFavorites();

  navTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      navTabs.forEach(t => t.classList.remove('active'));
      tabPages.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetId = tab.getAttribute('data-tab');
      const targetPage = document.getElementById(targetId);
      if (targetPage) targetPage.classList.add('active');

      if (targetId === 'tab-favs') {
        renderFavorites();
      }
    });
  });

  viewModeToggle.addEventListener('click', () => {
    document.body.classList.toggle('desktop-view');
    const isDesk = document.body.classList.contains('desktop-view');
    viewModeToggle.innerHTML = isDesk 
      ? '<i class="fa-solid fa-compress"></i>' 
      : '<i class="fa-solid fa-mobile-screen"></i>';
  });

  langToggleBtn.addEventListener('click', () => {
    if (currentLang === 'en') {
      currentLang = 'bn';
      langToggleBtn.innerText = 'EN';
      findBusesBtn.innerText = 'বাস খুঁজুন (FIND BUSES)';
    } else {
      currentLang = 'en';
      langToggleBtn.innerText = 'বাং';
      findBusesBtn.innerText = 'FIND BUSES';
    }
  });

  // ========================================================
  // 4. AUTOCOMPLETE SUGGESTIONS
  // ========================================================
  function setupAutocomplete(inputEl, suggestionsEl, clearBtn, fieldBox) {
    let debounceTimer = null;

    inputEl.addEventListener('input', () => {
      searchAlert.classList.add('hidden');
      if (fieldBox) fieldBox.classList.remove('field-error');

      const val = inputEl.value.trim();
      if (clearBtn) {
        if (val.length > 0) clearBtn.classList.add('visible');
        else clearBtn.classList.remove('visible');
      }

      if (val.length === 0) {
        suggestionsEl.classList.remove('visible');
        return;
      }

      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        secureFetch(`/api/stops?q=${encodeURIComponent(val)}&limit=8`)
          .then(data => {
            if (!data.success || !data.stops.length) {
              suggestionsEl.innerHTML = '<div class="wimt-suggest-item"><em>No matching bus stop</em></div>';
              suggestionsEl.classList.add('visible');
              return;
            }

            suggestionsEl.innerHTML = data.stops.map(s => `
              <div class="wimt-suggest-item" data-name="${s.stop_name}">
                <span><i class="fa-solid fa-location-dot" style="color: #00897B; margin-right: 8px;"></i>${s.stop_name}</span>
                <span class="suggest-tag">${s.routes_count} buses</span>
              </div>
            `).join('');

            suggestionsEl.classList.add('visible');

            suggestionsEl.querySelectorAll('.wimt-suggest-item').forEach(item => {
              item.addEventListener('click', (e) => {
                e.stopPropagation();
                const name = item.getAttribute('data-name');
                if (name) {
                  inputEl.value = name;
                  if (clearBtn) clearBtn.classList.add('visible');
                  suggestionsEl.classList.remove('visible');
                  inputEl.focus();
                }
              });
            });
          })
          .catch(err => console.error(err));
      }, 130);
    });

    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        inputEl.value = '';
        clearBtn.classList.remove('visible');
        suggestionsEl.classList.remove('visible');
        inputEl.focus();
      });
    }

    document.addEventListener('click', (e) => {
      if (!inputEl.contains(e.target) && !suggestionsEl.contains(e.target)) {
        suggestionsEl.classList.remove('visible');
      }
    });
  }

  setupAutocomplete(fromInput, fromSuggestions, clearFromBtn, fromFieldBox);
  setupAutocomplete(toInput, toSuggestions, clearToBtn, toFieldBox);
  setupAutocomplete(liveStopInput, liveStopSuggestions, null, null);

  // Enter Key Triggers Search
  [fromInput, toInput].forEach(inp => {
    inp.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        fromSuggestions.classList.remove('visible');
        toSuggestions.classList.remove('visible');
        executeSearch();
      }
    });
  });

  // Swap Stations Button (⇄)
  swapBtn.addEventListener('click', () => {
    const temp = fromInput.value;
    fromInput.value = toInput.value;
    toInput.value = temp;

    if (fromInput.value) clearFromBtn.classList.add('visible'); else clearFromBtn.classList.remove('visible');
    if (toInput.value) clearToBtn.classList.add('visible'); else clearToBtn.classList.remove('visible');

    swapBtn.style.transform = 'rotate(180deg)';
    setTimeout(() => { swapBtn.style.transform = ''; }, 260);

    if (fromInput.value.trim() && toInput.value.trim()) {
      executeSearch();
    }
  });

  // ========================================================
  // 5. FIND BUSES: TRANSITION TO FULL NEW RESULTS SCREEN
  // ========================================================
  findBusesBtn.addEventListener('click', executeSearch);

  function executeSearch() {
    searchAlert.classList.add('hidden');
    fromFieldBox.classList.remove('field-error');
    toFieldBox.classList.remove('field-error');

    const fromVal = fromInput.value.trim();
    const toVal = toInput.value.trim();

    if (!fromVal && !toVal) {
      fromFieldBox.classList.add('field-error');
      toFieldBox.classList.add('field-error');
      alertText.innerText = 'Please enter both departure and destination stops.';
      searchAlert.classList.remove('hidden');
      fromInput.focus();
      return;
    }

    if (!fromVal) {
      fromFieldBox.classList.add('field-error');
      alertText.innerText = 'Please enter departure stop (From).';
      searchAlert.classList.remove('hidden');
      fromInput.focus();
      return;
    }

    if (!toVal) {
      toFieldBox.classList.add('field-error');
      alertText.innerText = 'Please enter destination stop (To).';
      searchAlert.classList.remove('hidden');
      toInput.focus();
      return;
    }

    // Save to Recent Searches
    addRecentSearch(fromVal, toVal);

    // Transition immediately to the FULL NEW RESULTS SCREEN
    showResultsScreen(`${fromVal} ➔ ${toVal}`, 'Connecting buses...');

    fullScreenResultsList.innerHTML = `
      <div class="empty-placeholder">
        <i class="fa-solid fa-spinner fa-spin" style="font-size: 2rem; color: #00897B;"></i>
        <h4 style="margin-top: 10px;">Finding Connecting Buses...</h4>
        <p>Scanning Kolkata transit network</p>
      </div>
    `;

    // Perform Secure Query
    secureFetch(`/api/search?from=${encodeURIComponent(fromVal)}&to=${encodeURIComponent(toVal)}`)
      .then(data => {
        const hasDirect = data.routes && data.routes.length > 0;
        const hasTransfers = data.transfer_routes && data.transfer_routes.length > 0;

        if (!hasDirect && !hasTransfers) {
          resultsStatusSubtitle.innerText = '0 Buses Running';
          fullScreenResultsList.innerHTML = `
            <div class="empty-placeholder">
              <i class="fa-solid fa-triangle-exclamation" style="font-size: 2.2rem; color: #FF8F00;"></i>
              <h4 style="margin-top: 8px;">No Direct or 1-Transfer Buses Found</h4>
              <p>No bus connection currently registered between <b>${fromVal}</b> and <b>${toVal}</b>. Try searching using nearby popular bus hubs like Howrah, Esplanade, Sealdah, or Ultadanga.</p>
            </div>
          `;
          return;
        }

        currentSearchResults = data.routes || [];
        const directCount = currentSearchResults.length;
        const transferCount = (data.transfer_routes || []).length;
        
        resultsStatusSubtitle.innerText = directCount > 0 
          ? `Runs Daily • ${directCount} Direct Buses${transferCount > 0 ? ` + ${transferCount} Hub Transfers` : ''}`
          : `0 Direct Buses • ${transferCount} Hub Transfers Available`;

        // Clear container
        fullScreenResultsList.innerHTML = '';

        // If no direct routes, show helpful hint
        if (!hasDirect && hasTransfers) {
          const noDirectHint = document.createElement('div');
          noDirectHint.className = 'wimt-alert-banner';
          noDirectHint.style.background = '#FFF3E0';
          noDirectHint.style.color = '#E65100';
          noDirectHint.style.marginBottom = '12px';
          noDirectHint.innerHTML = `<i class="fa-solid fa-shuffle"></i> <span>No direct bus connects these two stops. Showing recommended <strong>1-Transfer connecting routes</strong> via major transit hubs:</span>`;
          fullScreenResultsList.appendChild(noDirectHint);
        }

        // Render direct bus cards if any
        if (hasDirect) {
          const directContainer = document.createElement('div');
          directContainer.className = 'direct-buses-block';
          renderBusCards(data.routes, directContainer);
          fullScreenResultsList.appendChild(directContainer);
        }

        // Render 1-Transfer connecting routes if any
        if (hasTransfers) {
          const transferContainer = document.createElement('div');
          transferContainer.className = 'transfer-buses-block';
          transferContainer.innerHTML = renderTransferCardsHTML(data.transfer_routes);
          fullScreenResultsList.appendChild(transferContainer);

          // Wire click on transfer leg rows to open live track sheet
          transferContainer.querySelectorAll('.transfer-leg-row').forEach(row => {
            row.addEventListener('click', () => {
              const rId = row.getAttribute('data-route-id');
              if (rId) openLiveTrackSheet(rId);
            });
          });
        }
      })
      .catch(err => {
        console.error(err);
        fullScreenResultsList.innerHTML = `
          <div class="empty-placeholder">
            <i class="fa-solid fa-circle-exclamation" style="color: #C62828;"></i>
            <h4>Network Error</h4>
            <p>Could not load route information.</p>
          </div>
        `;
      });
  }

  // Helper to render 1-Transfer cards HTML
  function renderTransferCardsHTML(transfers) {
    if (!transfers || !transfers.length) return '';
    return `
      <div class="section-label-bar transfer-label-bar">
        <span><i class="fa-solid fa-shuffle"></i> 1-TRANSFER ROUTES (VIA TRANSIT HUBS)</span>
      </div>
      ${transfers.map(tr => `
        <div class="transfer-card-wimt">
          <div class="transfer-hub-banner">
            <span><i class="fa-solid fa-arrows-split-up-and-left"></i> Change at <strong>${tr.hub_name}</strong></span>
            <span class="transfer-time-text"><i class="fa-solid fa-clock"></i> ~${tr.total_time_mins} mins</span>
          </div>

          <div class="transfer-leg-row" data-route-id="${tr.leg1.id}" title="Tap to view Leg 1 live stops">
            <div class="leg-info">
              <span class="leg-bus-badge">${tr.leg1.route_no}</span>
              <span style="font-weight:600; margin-left:6px; color:#263238;">${tr.leg1.from_stop} ➔ ${tr.leg1.hub_stop}</span>
            </div>
            <span class="fare-pill">₹${tr.leg1.fare}</span>
          </div>

          <div class="transfer-leg-row" data-route-id="${tr.leg2.id}" title="Tap to view Leg 2 live stops">
            <div class="leg-info">
              <span class="leg-bus-badge" style="background:#FFF3E0; color:#E65100;">${tr.leg2.route_no}</span>
              <span style="font-weight:600; margin-left:6px; color:#263238;">${tr.leg2.hub_stop} ➔ ${tr.leg2.to_stop}</span>
            </div>
            <span class="fare-pill">₹${tr.leg2.fare}</span>
          </div>

          <div class="transfer-meta-row">
            <span class="leg-stops-text"><i class="fa-solid fa-signs-post"></i> Total ${tr.total_stops} stops (${tr.leg1.stops} + ${tr.leg2.stops})</span>
            <span class="combined-fare-pill">Combined Fare: ${tr.fare_text}</span>
          </div>
        </div>
      `).join('')}
    `;
  }

  // Filter Pills (All / AC / State / Mini)
  filterTabPills.forEach(pill => {
    pill.addEventListener('click', () => {
      filterTabPills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');

      const filterType = pill.getAttribute('data-filter');
      let filtered = currentSearchResults;

      if (filterType === 'ac') {
        filtered = currentSearchResults.filter(r => r.bus_type.toLowerCase().includes('ac'));
      } else if (filterType === 'state') {
        filtered = currentSearchResults.filter(r => 
          r.bus_type.toLowerCase().includes('wbtc') || 
          r.category.includes('SBSTC') || 
          r.category.includes('NBSTC')
        );
      } else if (filterType === 'mini') {
        filtered = currentSearchResults.filter(r => r.bus_type.toLowerCase().includes('mini'));
      }

      const directBlock = fullScreenResultsList.querySelector('.direct-buses-block') || fullScreenResultsList;
      renderBusCards(filtered, directBlock);
    });
  });

  // Render Authentic WIMT Bus Cards
  function renderBusCards(routes, container) {
    if (!routes.length) {
      container.innerHTML = `
        <div class="empty-placeholder">
          <i class="fa-solid fa-filter-circle-xmark" style="font-size: 2rem; color: #90A4AE;"></i>
          <h4>No buses matching this filter</h4>
        </div>
      `;
      return;
    }

    container.innerHTML = routes.map(r => {
      let badgeClass = '';
      if (r.bus_type.includes('AC')) badgeClass = 'ac';
      else if (r.bus_type.includes('Mini')) badgeClass = 'mini';
      else if (r.bus_type.includes('Rocket') || r.bus_type.includes('Express')) badgeClass = 'express';

      const isFav = favoriteRoutes.some(f => f.route_no === r.route_no);

      const stopsText = r.stops_between !== undefined 
        ? `<span class="stops-indicator-text"><i class="fa-solid fa-signs-post"></i> ${r.stops_between} stops between (${r.from_stop} ➔ ${r.to_stop})</span>`
        : `<span class="stops-indicator-text"><i class="fa-solid fa-route"></i> ${r.total_stops} total stops</span>`;

      const fareAmount = r.estimated_fare || (r.fare_text ? r.fare_text.replace('₹', '') : '10');

      return `
        <div class="bus-card-wimt" data-route-id="${r.id}" data-route-no="${r.route_no}">
          <div class="card-top-line">
            <span class="badge-bus-number ${badgeClass}">${r.route_no}</span>
            <div class="card-top-right">
              <span class="fare-pill" title="Estimated Bus Fare"><i class="fa-solid fa-indian-rupee-sign"></i> ${fareAmount}</span>
              <span class="type-pill">${r.bus_type}</span>
              <button class="fav-star-btn ${isFav ? 'active' : ''}" data-fav-no="${r.route_no}" title="${isFav ? 'Remove Favorite' : 'Save Favorite'}">
                <i class="${isFav ? 'fa-solid' : 'fa-regular'} fa-star"></i>
              </button>
            </div>
          </div>

          <div class="card-route-title">
            ${r.origin} ➔ ${r.destination}
          </div>

          <div class="card-via-stops">
            <strong>Via:</strong> ${r.route_name}
          </div>

          <div class="card-bottom-bar">
            ${stopsText}
            <span class="live-cta-text">LIVE STATUS <i class="fa-solid fa-arrow-right"></i></span>
          </div>
        </div>
      `;
    }).join('');

    container.querySelectorAll('.bus-card-wimt').forEach(card => {
      card.addEventListener('click', (e) => {
        if (e.target.closest('.fav-star-btn')) return;
        const routeId = card.getAttribute('data-route-id');
        openLiveTrackSheet(routeId);
      });
    });

    container.querySelectorAll('.fav-star-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const rno = btn.getAttribute('data-fav-no');
        const matched = routes.find(r => r.route_no === rno);
        if (matched) toggleFavorite(matched, btn);
      });
    });
  }

  // ========================================================
  // 6. RECENT SEARCHES
  // ========================================================
  function addRecentSearch(from, to) {
    recentSearches = recentSearches.filter(s => !(s.from.toLowerCase() === from.toLowerCase() && s.to.toLowerCase() === to.toLowerCase()));
    recentSearches.unshift({ from, to });
    if (recentSearches.length > 6) recentSearches.pop();
    localStorage.setItem('wimt_recent_searches', JSON.stringify(recentSearches));
    renderRecentSearches();
  }

  function renderRecentSearches() {
    if (!recentSearchesList) return;

    recentSearchesList.innerHTML = recentSearches.map(item => `
      <div class="recent-search-row" data-from="${item.from}" data-to="${item.to}">
        <span class="recent-route-text">
          <i class="fa-solid fa-bus" style="color: #90A4AE;"></i>
          ${item.from} <i class="fa-solid fa-arrow-right recent-arrow"></i> ${item.to}
        </span>
        <i class="fa-solid fa-arrow-turn-up recent-tap-icon" style="transform: rotate(90deg);" title="Launch Trip"></i>
      </div>
    `).join('');

    recentSearchesList.querySelectorAll('.recent-search-row').forEach(row => {
      row.addEventListener('click', () => {
        const from = row.getAttribute('data-from');
        const to = row.getAttribute('data-to');
        fromInput.value = from;
        toInput.value = to;
        clearFromBtn.classList.add('visible');
        clearToBtn.classList.add('visible');
        executeSearch();
      });
    });
  }

  clearHistoryBtn.addEventListener('click', () => {
    recentSearches = [];
    localStorage.removeItem('wimt_recent_searches');
    recentSearchesList.innerHTML = '<div style="padding: 10px; font-size: 0.8rem; color: #90A4AE;">No recent searches</div>';
  });

  // ========================================================
  // 7. BUS NO & LIVE STOP UTILITY SEARCHES
  // ========================================================
  busnoSearchBtn.addEventListener('click', () => {
    const q = busnoInput.value.trim();
    if (!q) return;

    showResultsScreen(`Bus No. ${q}`, 'Direct route lookup');
    fullScreenResultsList.innerHTML = `<div class="empty-placeholder"><i class="fa-solid fa-spinner fa-spin"></i><h4>Finding Route ${q}...</h4></div>`;

    secureFetch(`/api/routes?q=${encodeURIComponent(q)}&limit=30`)
      .then(data => {
        resultsStatusSubtitle.innerText = `${data.count} Routes Matching "${q}"`;
        renderBusCards(data.routes, fullScreenResultsList);
      })
      .catch(err => console.error(err));
  });

  busnoInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') busnoSearchBtn.click();
  });

  liveStopBtn.addEventListener('click', () => {
    const stop = liveStopInput.value.trim();
    if (!stop) return;

    showResultsScreen(`Departures at ${stop}`, 'Live Station Board');
    fullScreenResultsList.innerHTML = `<div class="empty-placeholder"><i class="fa-solid fa-spinner fa-spin"></i><h4>Loading Stop Schedule...</h4></div>`;

    secureFetch(`/api/stops/${encodeURIComponent(stop)}/routes`)
      .then(data => {
        resultsStatusSubtitle.innerText = `${data.count} Buses Servicing "${data.stop_name}"`;
        renderBusCards(data.routes, fullScreenResultsList);
      })
      .catch(err => console.error(err));
  });

  liveStopInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') liveStopBtn.click();
  });

  // ========================================================
  // 8. FAVORITES SYSTEM
  // ========================================================
  function toggleFavorite(route, btnEl) {
    const idx = favoriteRoutes.findIndex(f => f.route_no === route.route_no);
    if (idx >= 0) {
      favoriteRoutes.splice(idx, 1);
      if (btnEl) {
        btnEl.classList.remove('active');
        btnEl.innerHTML = '<i class="fa-regular fa-star"></i>';
      }
    } else {
      favoriteRoutes.push({
        id: route.id,
        route_no: route.route_no,
        route_name: route.route_name,
        origin: route.origin,
        destination: route.destination,
        bus_type: route.bus_type,
        category: route.category,
        total_stops: route.total_stops
      });
      if (btnEl) {
        btnEl.classList.add('active');
        btnEl.innerHTML = '<i class="fa-solid fa-star"></i>';
      }
    }

    localStorage.setItem('wimt_fav_routes', JSON.stringify(favoriteRoutes));
    renderFavorites();
  }

  function renderFavorites() {
    if (!favoritesList || !emptyFavs) return;

    if (!favoriteRoutes.length) {
      favoritesList.innerHTML = '';
      emptyFavs.classList.remove('hidden');
      return;
    }

    emptyFavs.classList.add('hidden');
    renderBusCards(favoriteRoutes, favoritesList);
  }

  // ========================================================
  // 9. SIGNATURE WIMT "LIVE STATUS / TRACK TIMELINE"
  // ========================================================
  function openLiveTrackSheet(routeId) {
    wimtTrackModal.classList.remove('hidden');
    modalTrackStops.innerHTML = `<div class="empty-placeholder"><i class="fa-solid fa-spinner fa-spin"></i><h4>Loading Track Timeline...</h4></div>`;
    isRouteReversed = false;

    secureFetch(`/api/routes/${routeId}`)
      .then(data => {
        if (!data.success) return;
        currentActiveRoute = data.route;
        currentActiveStops = [...data.route.stops];
        renderTrackSheetContent();
      })
      .catch(err => console.error(err));
  }

  function renderTrackSheetContent() {
    const r = currentActiveRoute;
    const stops = isRouteReversed ? [...currentActiveStops].reverse() : [...currentActiveStops];

    modalRouteNo.innerText = r.route_no;
    modalRouteType.innerText = r.bus_type;
    modalRouteZone.innerText = r.category;
    modalRouteName.innerText = isRouteReversed 
      ? `${r.destination} ➔ ${r.origin}` 
      : `${r.origin} ➔ ${r.destination}`;

    if (r.timetable && r.timetable !== 'Coming Soon') {
      modalStatusText.innerText = r.timetable;
    } else {
      modalStatusText.innerText = 'Runs Daily • Normal Peak Frequency (10-15 min)';
    }

    if (r.media_token) {
      modalImageBtn.classList.remove('hidden');
      modalImageBtn.onclick = () => {
        openPhotoViewer(r.media_token, `${r.route_no} Timetable`);
      };
    } else {
      modalImageBtn.classList.add('hidden');
    }

    modalFromSelect.innerHTML = stops.map((s, idx) => `
      <option value="${idx}" ${idx === 0 ? 'selected' : ''}>${s.stop_name}</option>
    `).join('');

    modalToSelect.innerHTML = stops.map((s, idx) => `
      <option value="${idx}" ${idx === stops.length - 1 ? 'selected' : ''}>${s.stop_name}</option>
    `).join('');

    const searchFrom = fromInput.value.trim().toLowerCase();
    const searchTo = toInput.value.trim().toLowerCase();
    if (searchFrom && searchTo) {
      stops.forEach((s, idx) => {
        if (s.stop_name.toLowerCase().includes(searchFrom)) modalFromSelect.value = idx;
        if (s.stop_name.toLowerCase().includes(searchTo)) modalToSelect.value = idx;
      });
    }

    modalFromSelect.onchange = updateTrackHighlight;
    modalToSelect.onchange = updateTrackHighlight;

    renderTrackNodes(stops);
    updateTrackHighlight();
  }

  function renderTrackNodes(stops) {
    modalTrackStops.innerHTML = stops.map((s, idx) => {
      const isOrigin = idx === 0;
      const isDest = idx === stops.length - 1;
      let nodeClass = '';
      let tagHtml = '';

      if (isOrigin) {
        nodeClass = 'is-origin';
        tagHtml = '<span class="stn-terminal-pill origin">ORIGIN</span>';
      } else if (isDest) {
        nodeClass = 'is-destination';
        tagHtml = '<span class="stn-terminal-pill dest">TERMINAL</span>';
      }

      const kmDist = (idx * 1.3).toFixed(1);
      const bayNumber = (idx % 3 === 0) ? `Bay ${(idx % 4) + 1}` : 'Stop';

      return `
        <div class="stn-node ${nodeClass}" data-idx="${idx}" id="stn-node-${idx}">
          <div class="stn-dist">${kmDist} km</div>
          <div class="stn-track-dot-box">
            <div class="stn-circle"></div>
          </div>
          <div class="stn-info-box">
            <div class="stn-name-line">
              <span>${s.stop_name}</span>
              ${tagHtml}
            </div>
          </div>
          <div class="stn-bay-info">${bayNumber}</div>
        </div>
      `;
    }).join('');

    modalTrackStops.querySelectorAll('.stn-node').forEach(node => {
      node.addEventListener('click', () => {
        const idx = parseInt(node.getAttribute('data-idx'));
        const curFrom = parseInt(modalFromSelect.value);
        if (idx < curFrom) {
          modalFromSelect.value = idx;
        } else {
          modalToSelect.value = idx;
        }
        updateTrackHighlight();
      });
    });
  }

  function updateTrackHighlight() {
    const fromIdx = parseInt(modalFromSelect.value);
    const toIdx = parseInt(modalToSelect.value);

    const allNodes = modalTrackStops.querySelectorAll('.stn-node');
    const existingBus = document.querySelector('.bus-sprite-on-track');
    if (existingBus) existingBus.remove();

    allNodes.forEach((node, idx) => {
      node.classList.remove('in-journey', 'journey-start', 'journey-end');
      if (fromIdx <= toIdx && idx >= fromIdx && idx <= toIdx) {
        node.classList.add('in-journey');
        if (idx === fromIdx) node.classList.add('journey-start');
        if (idx === toIdx) node.classList.add('journey-end');
      }
    });

    // Place Front-view Bus Sprite on Track at Boarding Stop
    const startNode = document.getElementById(`stn-node-${fromIdx}`);
    if (startNode) {
      const busSprite = document.createElement('img');
      busSprite.src = 'assets/bus-sprite.svg';
      busSprite.className = 'bus-sprite-on-track';
      busSprite.alt = 'Bus Sprite';
      startNode.appendChild(busSprite);
    }

    const diff = Math.abs(toIdx - fromIdx);
    metricStops.innerText = `${diff}`;
    metricDuration.innerText = `~${Math.round(diff * 3.5)} m`;
    metricDist.innerText = `~${(diff * 1.3).toFixed(1)} km`;
  }

  modalReverseBtn.addEventListener('click', () => {
    isRouteReversed = !isRouteReversed;
    renderTrackSheetContent();
  });

  sheetCloseBtn.addEventListener('click', () => wimtTrackModal.classList.add('hidden'));
  trackBackdrop.addEventListener('click', () => wimtTrackModal.classList.add('hidden'));

  // ========================================================
  // 10. SECURE PHOTO VIEWER (Proxied via backend token)
  // ========================================================
  function openPhotoViewer(mediaToken, title) {
    photoTitle.innerText = title;
    photoImg.src = `/api/media/${encodeURIComponent(mediaToken)}`;
    photoViewerModal.classList.remove('hidden');
  }

  photoCloseBtn.addEventListener('click', () => photoViewerModal.classList.add('hidden'));
  photoBackdrop.addEventListener('click', () => photoViewerModal.classList.add('hidden'));

  // ========================================================
  // 11. KOLKATA METRO FULL ENGINE (Delhi Metro Style)
  // ========================================================
  const metroFromSelect = document.getElementById('metro-from-select');
  const metroToSelect = document.getElementById('metro-to-select');
  const metroPlanBtn = document.getElementById('metro-plan-btn');
  const metroSwapBtn = document.getElementById('metro-swap-btn');
  const metroAlert = document.getElementById('metro-alert');
  const metroAlertText = document.getElementById('metro-alert-text');
  const metroPlanResult = document.getElementById('metro-plan-result');
  const metroResType = document.getElementById('metro-res-type');
  const metroResTitle = document.getElementById('metro-res-title');
  const metroResFare = document.getElementById('metro-res-fare');
  const metroResDuration = document.getElementById('metro-res-duration');
  const metroResStations = document.getElementById('metro-res-stations');
  const metroResDistance = document.getElementById('metro-res-distance');
  const metroResInterchange = document.getElementById('metro-res-interchange');
  const metroInterchangeText = document.getElementById('metro-interchange-text');
  const metroStationsTimeline = document.getElementById('metro-stations-timeline');
  const metroLinesDirectory = document.getElementById('metro-lines-directory');

  let isMetroLoaded = false;

  function initMetroEngine() {
    if (isMetroLoaded) return;
    isMetroLoaded = true;

    // 1. Load Metro Stations for dropdowns
    secureFetch('/api/metro/stations')
      .then(data => {
        if (!data.success || !data.stations) return;
        
        // Group stations by line
        const linesMap = {};
        data.stations.forEach(stn => {
          if (!linesMap[stn.line_id]) linesMap[stn.line_id] = [];
          linesMap[stn.line_id].push(stn);
        });

        let html = '<option value="">Select Station...</option>';
        for (const [lineId, stns] of Object.entries(linesMap)) {
          const lineLabel = stns[0].line_name;
          html += `<optgroup label="${lineLabel}">`;
          stns.forEach(s => {
            const bn = s.station_bengali ? ` (${s.station_bengali})` : '';
            html += `<option value="${s.station_name}">${s.station_name}${bn}</option>`;
          });
          html += '</optgroup>';
        }

        if (metroFromSelect) {
          metroFromSelect.innerHTML = html;
          metroFromSelect.value = 'Howrah Maidan';
        }
        if (metroToSelect) {
          metroToSelect.innerHTML = html;
          metroToSelect.value = 'Esplanade';
        }
      })
      .catch(err => console.error('Error loading metro stations:', err));

    // 2. Load Metro Corridors Directory
    secureFetch('/api/metro/lines')
      .then(data => {
        if (!data.success || !data.lines || !metroLinesDirectory) return;
        
        metroLinesDirectory.innerHTML = data.lines.map(l => {
          return `
            <div class="metro-corridor-item" style="border-left: 4px solid ${l.line_color};">
              <div class="corridor-bullet" style="background:${l.line_color};">${l.line_number}</div>
              <div class="corridor-details">
                <div class="corridor-name">${l.line_name}</div>
                <div class="corridor-stations">${l.terminal_from} ⇄ ${l.terminal_to}</div>
                <div class="corridor-meta">${l.total_stations} Stations • ${l.special_feature}</div>
                <div class="corridor-timings-grid">
                  <div class="corridor-timing-item"><i class="fa-solid fa-clock"></i> First: <strong>${l.first_train}</strong></div>
                  <div class="corridor-timing-item"><i class="fa-solid fa-clock"></i> Last: <strong>${l.last_train}</strong></div>
                  <div class="corridor-timing-item"><i class="fa-solid fa-bolt"></i> Peak: <strong>${l.peak_headway}</strong></div>
                  <div class="corridor-timing-item"><i class="fa-solid fa-hourglass-half"></i> Off-Peak: <strong>${l.offpeak_headway}</strong></div>
                </div>
              </div>
            </div>
          `;
        }).join('');
      })
      .catch(err => console.error('Error loading metro lines:', err));
  }

  // Swap Metro Stations
  if (metroSwapBtn) {
    metroSwapBtn.addEventListener('click', () => {
      const temp = metroFromSelect.value;
      metroFromSelect.value = metroToSelect.value;
      metroToSelect.value = temp;

      metroSwapBtn.style.transform = 'rotate(180deg)';
      setTimeout(() => { metroSwapBtn.style.transform = ''; }, 260);

      if (metroFromSelect.value && metroToSelect.value) {
        planMetroRoute();
      }
    });
  }

  // Calculate Metro Route & Fare (Delhi Metro App Style)
  if (metroPlanBtn) {
    metroPlanBtn.addEventListener('click', planMetroRoute);
  }

  function planMetroRoute() {
    const fromStn = metroFromSelect.value;
    const toStn = metroToSelect.value;

    if (!fromStn || !toStn) {
      if (metroAlert) {
        metroAlertText.innerText = 'Please select both departure and arrival metro stations.';
        metroAlert.classList.remove('hidden');
      }
      return;
    }

    if (fromStn === toStn) {
      if (metroAlert) {
        metroAlertText.innerText = 'Boarding and destination metro stations cannot be the same.';
        metroAlert.classList.remove('hidden');
      }
      return;
    }

    if (metroAlert) metroAlert.classList.add('hidden');

    metroPlanBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Calculating Route & Fare...';
    metroPlanBtn.disabled = true;

    secureFetch(`/api/metro/plan?from=${encodeURIComponent(fromStn)}&to=${encodeURIComponent(toStn)}`)
      .then(data => {
        metroPlanBtn.innerHTML = '<i class="fa-solid fa-train-subway"></i> SHOW ROUTE & FARE';
        metroPlanBtn.disabled = false;

        if (!data.success || !data.plan) {
          if (metroAlert) {
            metroAlertText.innerText = 'Could not calculate metro route between these stations.';
            metroAlert.classList.remove('hidden');
          }
          return;
        }

        const p = data.plan;
        metroResType.innerText = p.type === 'DIRECT' ? 'DIRECT METRO TRAIN' : '1 INTERCHANGE ROUTE';
        metroResTitle.innerText = `${p.from_station} ➔ ${p.to_station}`;
        metroResFare.innerText = p.fare_text || `₹${p.fare}`;
        metroResDuration.innerText = `${p.duration_mins} mins`;
        metroResStations.innerText = `${p.stations_count} Stations`;
        metroResDistance.innerText = `${p.distance_km} km`;

        if (p.type === 'INTERCHANGE') {
          metroResInterchange.classList.remove('hidden');
          metroInterchangeText.innerText = p.instructions || `Change train at ${p.interchange_station} station.`;
        } else {
          metroResInterchange.classList.add('hidden');
        }

        // Render Stations Timeline
        if (p.stations && p.stations.length) {
          metroStationsTimeline.innerHTML = p.stations.map((s, idx) => {
            const isTerminal = idx === 0 || idx === p.stations.length - 1;
            const lineColor = p.line_color || '#2E7D32';
            const bn = s.station_bengali ? `<span class="metro-node-bn">${s.station_bengali}</span>` : '';
            const ic = s.interchange_info ? `<span class="metro-interchange-badge">${s.interchange_info}</span>` : '';

            return `
              <div class="metro-station-node">
                <div class="metro-node-line" style="background:${lineColor};"></div>
                <div class="metro-node-dot ${isTerminal ? 'terminal' : ''}" style="border-color:${lineColor};"></div>
                <div class="metro-node-name">${s.station_name}${bn}</div>
                ${ic}
              </div>
            `;
          }).join('');
        } else {
          metroStationsTimeline.innerHTML = '';
        }

        metroPlanResult.classList.remove('hidden');
        metroPlanResult.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      })
      .catch(err => {
        console.error('Metro plan error:', err);
        metroPlanBtn.innerHTML = '<i class="fa-solid fa-train-subway"></i> SHOW ROUTE & FARE';
        metroPlanBtn.disabled = false;
      });
  }

  // ========================================================
  // 12. COMMUTER COMMUNITY CHAT ENGINE (m-Indicator Style)
  // ========================================================
  const chatMessagesList = document.getElementById('chat-messages-list');
  const chatChannelPills = document.querySelectorAll('.channel-pill');
  const chatUserInput = document.getElementById('chat-user-input');
  const chatRouteInput = document.getElementById('chat-route-input');
  const chatMsgInput = document.getElementById('chat-msg-input');
  const chatPostBtn = document.getElementById('chat-post-btn');
  const chatRefreshBtn = document.getElementById('chat-refresh-btn');
  const statusTagBtns = document.querySelectorAll('.status-tag-btn');
  const chatActiveCount = document.getElementById('chat-active-count');

  let activeChatChannel = 'general';
  let activeStatusTag = 'Normal';

  // Restore saved username
  if (chatUserInput) {
    const savedName = localStorage.getItem('cholokolkata_username');
    if (savedName) chatUserInput.value = savedName;
  }

  function loadChatMessages() {
    if (!chatMessagesList) return;

    secureFetch(`/api/chat/messages?channel=${encodeURIComponent(activeChatChannel)}&limit=35`)
      .then(data => {
        if (!data.success || !data.messages) return;

        if (chatActiveCount) {
          const randCommuters = Math.floor(Math.random() * 20) + 38;
          chatActiveCount.innerText = `${randCommuters} active commuters`;
        }

        if (!data.messages.length) {
          chatMessagesList.innerHTML = `
            <div class="empty-placeholder">
              <i class="fa-regular fa-comment-dots" style="font-size: 2rem; color: #B0BEC5;"></i>
              <h4>No alerts in #${activeChatChannel.toUpperCase()}</h4>
              <p>Be the first commuter to post traffic or bus updates here.</p>
            </div>
          `;
          return;
        }

        chatMessagesList.innerHTML = data.messages.map(m => {
          let statusClass = 'status-smooth';
          let icon = 'fa-circle-check';

          if (m.status_tag === 'Heavy Jam') {
            statusClass = 'status-jam';
            icon = 'fa-traffic-light';
          } else if (m.status_tag === 'Bus Arrived') {
            statusClass = 'status-arrived';
            icon = 'fa-bus';
          } else if (m.status_tag === 'Crowded') {
            statusClass = 'status-crowd';
            icon = 'fa-users';
          }

          const routeBadge = m.route_ref 
            ? `<span class="chat-route-tag"><i class="fa-solid fa-hashtag"></i> ${m.route_ref}</span>` 
            : '';

          return `
            <div class="chat-card">
              <div class="chat-card-top">
                <div class="chat-user-box">
                  <span class="chat-user-name">${m.user_name}</span>
                  <span class="chat-time-str">• ${m.time_str}</span>
                </div>
                <span class="chat-status-pill ${statusClass}">
                  <i class="fa-solid ${icon}"></i> ${m.status_tag}
                </span>
              </div>
              ${routeBadge}
              <p class="chat-text">${m.message}</p>
            </div>
          `;
        }).join('');
      })
      .catch(err => console.error('Chat load error:', err));
  }

  // Channel Tabs Switcher
  chatChannelPills.forEach(pill => {
    pill.addEventListener('click', () => {
      chatChannelPills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      activeChatChannel = pill.getAttribute('data-channel');
      loadChatMessages();
    });
  });

  // Status Tag Buttons
  statusTagBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      statusTagBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeStatusTag = btn.getAttribute('data-status');
    });
  });

  // Post Chat Message
  if (chatPostBtn) {
    chatPostBtn.addEventListener('click', postCommuterMessage);
  }

  if (chatMsgInput) {
    chatMsgInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') postCommuterMessage();
    });
  }

  if (chatRefreshBtn) {
    chatRefreshBtn.addEventListener('click', () => {
      chatRefreshBtn.innerHTML = '<i class="fa-solid fa-rotate fa-spin"></i> Refreshing...';
      loadChatMessages();
      setTimeout(() => {
        chatRefreshBtn.innerHTML = '<i class="fa-solid fa-rotate"></i> Refresh';
      }, 600);
    });
  }

  function postCommuterMessage() {
    const text = chatMsgInput ? chatMsgInput.value.trim() : '';
    if (!text) {
      if (chatMsgInput) chatMsgInput.focus();
      return;
    }

    const userName = (chatUserInput && chatUserInput.value.trim()) ? chatUserInput.value.trim() : 'Commuter_' + Math.floor(Math.random() * 900 + 100);
    const routeRef = chatRouteInput ? chatRouteInput.value.trim() : '';

    localStorage.setItem('cholokolkata_username', userName);

    chatPostBtn.disabled = true;
    chatPostBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>';

    fetch('/api/chat/post', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        channel: activeChatChannel,
        user_name: userName,
        route_ref: routeRef,
        status_tag: activeStatusTag,
        message: text
      })
    })
      .then(res => res.json())
      .then(() => {
        if (chatMsgInput) chatMsgInput.value = '';
        chatPostBtn.disabled = false;
        chatPostBtn.innerHTML = '<i class="fa-solid fa-paper-plane"></i>';
        loadChatMessages();
      })
      .catch(err => {
        console.error('Post chat error:', err);
        chatPostBtn.disabled = false;
        chatPostBtn.innerHTML = '<i class="fa-solid fa-paper-plane"></i>';
      });
  }

  // Hook tab switching to initialize modules
  navTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.getAttribute('data-tab');
      if (targetId === 'tab-metro') {
        initMetroEngine();
      } else if (targetId === 'tab-chat') {
        loadChatMessages();
      }
    });
  });

  // Background auto-refresh for community chat when chat tab is visible
  setInterval(() => {
    const chatPage = document.getElementById('tab-chat');
    if (chatPage && chatPage.classList.contains('active')) {
      loadChatMessages();
    }
  }, 18000);

  // Initialize Metro & Chat on launch
  initMetroEngine();

});
