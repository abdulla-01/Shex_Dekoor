// === CONFIG ===
let CONFIG = {
  serverUrl: localStorage.getItem('serverUrl') || '',
  apiKey: localStorage.getItem('apiKey') || '',
  lang: localStorage.getItem('lang') || 'ku'
};

// === GALLERY STORAGE ===
let gallery = JSON.parse(localStorage.getItem('gallery') || '[]');

// === TRANSLATIONS ===
const PLACEHOLDERS = {
  ku: {
    imagePrompt: "وەسفی وێنەکەت بنووسە... بۆ نموونە: کۆهستانی کوردستان لە کاتی ئاستاوە، رووناکی زێرین",
    videoPrompt: "ڤیدیۆی دەتەوێت وەسفی بکە... بۆ نموونە: دریاچەی زریبار لە کاتی ئاوایی، خوێندکار",
  },
  ar: {
    imagePrompt: "صف صورتك... مثال: غروب الشمس على جبال كردستان، ضوء ذهبي دافئ",
    videoPrompt: "صف مقطعك... مثال: بحيرة دوكان في المساء، حركة بطيئة",
  },
  en: {
    imagePrompt: "Describe your image... e.g: Kurdish mountain sunset, golden hour light, photorealistic",
    videoPrompt: "Describe your video... e.g: Dukan lake at dusk, slow motion water ripples",
  }
};

// === INIT ===
document.addEventListener('DOMContentLoaded', () => {
  initCursor();
  initLang(CONFIG.lang);
  initTabs();
  initStylePills();
  renderGallery();

  if (!CONFIG.serverUrl) {
    setTimeout(openApiModal, 1000);
  }
});

// === CURSOR ===
function initCursor() {
  const cursor = document.getElementById('cursor');
  const trail = document.getElementById('cursorTrail');
  let tx = 0, ty = 0;

  document.addEventListener('mousemove', e => {
    cursor.style.left = e.clientX + 'px';
    cursor.style.top = e.clientY + 'px';
    tx = e.clientX; ty = e.clientY;
  });

  setInterval(() => {
    trail.style.left = tx + 'px';
    trail.style.top = ty + 'px';
  }, 80);

  document.querySelectorAll('button, a, input, textarea, select').forEach(el => {
    el.addEventListener('mouseenter', () => {
      cursor.style.width = '20px';
      cursor.style.height = '20px';
    });
    el.addEventListener('mouseleave', () => {
      cursor.style.width = '12px';
      cursor.style.height = '12px';
    });
  });
}

// === LANGUAGE ===
function initLang(lang) {
  CONFIG.lang = lang;
  localStorage.setItem('lang', lang);

  const isRTL = lang !== 'en';
  document.documentElement.setAttribute('lang', lang);
  document.documentElement.setAttribute('dir', isRTL ? 'rtl' : 'ltr');
  document.body.className = `lang-${lang}`;

  // Update all translatable elements
  document.querySelectorAll(`[data-${lang}]`).forEach(el => {
    el.textContent = el.getAttribute(`data-${lang}`);
  });

  // Placeholders
  const ip = document.getElementById('imagePrompt');
  const vp = document.getElementById('videoPrompt');
  if (ip) ip.placeholder = PLACEHOLDERS[lang].imagePrompt;
  if (vp) vp.placeholder = PLACEHOLDERS[lang].videoPrompt;

  // Active lang btn
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });
}

document.querySelectorAll('.lang-btn').forEach(btn => {
  btn.addEventListener('click', () => initLang(btn.dataset.lang));
});

// === TABS ===
function initTabs() {
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
    });
  });
}

// === STYLE PILLS ===
function initStylePills() {
  document.querySelectorAll('.style-pills').forEach(container => {
    container.querySelectorAll('.style-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        container.querySelectorAll('.style-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
      });
    });
  });
}

function getActiveStyle(containerId) {
  const active = document.querySelector(`#${containerId} .style-pill.active`);
  return active ? active.dataset.style : 'photorealistic';
}

// === SCROLL ===
function scrollToStudio() {
  document.getElementById('studio').scrollIntoView({ behavior: 'smooth' });
}

// === API MODAL ===
function openApiModal() {
  const modal = document.getElementById('apiModal');
  modal.classList.add('active');
  document.getElementById('serverUrl').value = CONFIG.serverUrl;
  document.getElementById('apiKey').value = CONFIG.apiKey;
}
function closeApiModal() {
  document.getElementById('apiModal').classList.remove('active');
}
function saveConfig() {
  CONFIG.serverUrl = document.getElementById('serverUrl').value.trim();
  CONFIG.apiKey = document.getElementById('apiKey').value.trim();
  localStorage.setItem('serverUrl', CONFIG.serverUrl);
  localStorage.setItem('apiKey', CONFIG.apiKey);
  closeApiModal();
  showToast(CONFIG.lang === 'ku' ? 'پاراستن سەرکەوتوو بوو ✓' : CONFIG.lang === 'ar' ? 'تم الحفظ بنجاح ✓' : 'Saved successfully ✓', 'success');
}

// === TOAST ===
function showToast(msg, type = '') {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = `toast show ${type}`;
  setTimeout(() => toast.className = 'toast', 3000);
}

// === CALL API ===
async function callFreeLLM(prompt, systemPrompt = '') {
  if (!CONFIG.serverUrl || !CONFIG.apiKey) {
    openApiModal();
    throw new Error('No API config');
  }

  const url = CONFIG.serverUrl.replace(/\/$/, '') + '/v1/chat/completions';
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${CONFIG.apiKey}`
    },
    body: JSON.stringify({
      model: 'auto',
      max_tokens: 2000,
      messages: [
        ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
        { role: 'user', content: prompt }
      ]
    })
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API Error: ${response.status} - ${err}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content || '';
}

// === ENHANCE PROMPT ===
async function enhancePrompt(type) {
  const el = document.getElementById(type === 'image' ? 'imagePrompt' : 'videoPrompt');
  const text = el.value.trim();
  if (!text) {
    showToast(CONFIG.lang === 'ku' ? 'سەرەتا تێکستێک بنووسە' : CONFIG.lang === 'ar' ? 'أدخل نصاً أولاً' : 'Enter text first');
    return;
  }

  const sys = `You are a creative AI prompt engineer. Enhance the given prompt to be more detailed, 
  vivid and effective for AI image/video generation. Keep the core idea but add:
  - lighting details, camera angles, mood, atmosphere
  - style descriptors and quality terms
  Keep it under 200 words. Respond ONLY with the enhanced prompt, no explanations.`;

  try {
    el.disabled = true;
    el.style.opacity = '0.5';
    const enhanced = await callFreeLLM(`Enhance this prompt: "${text}"`, sys);
    el.value = enhanced.trim();
    el.style.opacity = '1';
    el.disabled = false;
    showToast(CONFIG.lang === 'ku' ? 'باشترکراوە ✦' : CONFIG.lang === 'ar' ? 'تم التحسين ✦' : 'Enhanced ✦', 'success');
  } catch (e) {
    el.style.opacity = '1';
    el.disabled = false;
    showToast('Error: ' + e.message, 'error');
  }
}

// === GENERATE IMAGE ===
async function generateImage() {
  const prompt = document.getElementById('imagePrompt').value.trim();
  if (!prompt) {
    showToast(CONFIG.lang === 'ku' ? 'وەسفێک بنووسە' : CONFIG.lang === 'ar' ? 'أدخل وصفاً' : 'Enter a description');
    return;
  }

  const style = getActiveStyle('imageStyles');
  const size = document.getElementById('imageSize').value;
  const count = parseInt(document.getElementById('imageCount').value);
  const btn = document.getElementById('generateImageBtn');
  const outputPanel = document.getElementById('imageOutput');

  setLoading(btn, true);
  showOutputLoading(outputPanel, 'image');

  const systemPrompt = `You are an AI art director. When given a prompt, generate ${count} detailed image 
  description(s) in JSON format. Each should be rich, vivid, suitable for AI image generation.
  Response MUST be valid JSON array: [{"title": "...", "description": "...", "colors": "...", "mood": "...", "emoji": "..."}]
  NO markdown, NO code blocks, ONLY raw JSON.`;

  const userPrompt = `Create ${count} image(s) based on:
  Prompt: "${prompt}"
  Style: ${style}
  Size: ${size}
  Make each unique and detailed.`;

  try {
    const raw = await callFreeLLM(userPrompt, systemPrompt);
    let images;
    try {
      const clean = raw.replace(/```json|```/g, '').trim();
      images = JSON.parse(clean);
    } catch {
      images = [{ title: 'AI Generated', description: prompt, colors: 'vibrant', mood: 'dynamic', emoji: '🎨' }];
    }

    renderImageResults(outputPanel, images, prompt, style);
    addToGallery(images, prompt, style, 'image');
  } catch (e) {
    outputPanel.innerHTML = `<div class="output-empty"><p style="color:var(--accent2)">Error: ${e.message}</p></div>`;
  } finally {
    setLoading(btn, false);
  }
}

// === RENDER IMAGE RESULTS ===
function renderImageResults(panel, images, prompt, style) {
  panel.innerHTML = `<div class="results-grid"></div>`;
  const grid = panel.querySelector('.results-grid');

  images.forEach((img, i) => {
    const colors = generateGradient(img.mood || style);
    const card = document.createElement('div');
    card.className = 'result-card';
    card.style.animationDelay = `${i * 0.1}s`;
    card.innerHTML = `
      <div style="aspect-ratio:1; background: ${colors}; display:flex; align-items:center; justify-content:center; font-size:80px; position:relative; overflow:hidden;">
        <div style="position:absolute;inset:0;background:${colors};opacity:0.8;"></div>
        <div style="position:relative;z-index:1;text-align:center;padding:20px;">
          <div style="font-size:56px;margin-bottom:12px;">${img.emoji || '🎨'}</div>
          <div style="font-size:13px;color:rgba(255,255,255,0.7);line-height:1.5;max-width:180px;margin:0 auto;">${img.title || 'Generated'}</div>
        </div>
      </div>
      <div style="padding:12px;border-top:1px solid var(--border);">
        <p style="font-size:12px;color:var(--text-muted);line-height:1.5;overflow:hidden;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;">${img.description}</p>
        <div style="display:flex;gap:6px;margin-top:10px;flex-wrap:wrap;">
          <span class="gallery-style">${style}</span>
          ${img.mood ? `<span class="gallery-style" style="background:rgba(252,92,125,0.1);color:var(--accent2);">${img.mood}</span>` : ''}
        </div>
      </div>
      <div class="result-actions">
        <button class="action-btn" onclick="downloadCard(this, '${img.title || 'image'}')">
          ${CONFIG.lang === 'ku' ? 'داگرتن' : CONFIG.lang === 'ar' ? 'تحميل' : 'Download'}
        </button>
        <button class="action-btn" onclick="copyPrompt('${escStr(img.description)}')">
          ${CONFIG.lang === 'ku' ? 'کۆپی' : CONFIG.lang === 'ar' ? 'نسخ' : 'Copy'}
        </button>
      </div>
    `;
    grid.appendChild(card);
  });
}

// === GENERATE VIDEO ===
async function generateVideo() {
  const prompt = document.getElementById('videoPrompt').value.trim();
  if (!prompt) {
    showToast(CONFIG.lang === 'ku' ? 'وەسفێک بنووسە' : CONFIG.lang === 'ar' ? 'أدخل وصفاً' : 'Enter a description');
    return;
  }

  const style = getActiveStyle('videoStyles');
  const duration = document.getElementById('videoDuration').value;
  const quality = document.getElementById('videoQuality').value;
  const btn = document.getElementById('generateVideoBtn');
  const outputPanel = document.getElementById('videoOutput');

  setLoading(btn, true);
  showOutputLoading(outputPanel, 'video');

  const systemPrompt = `You are a professional video director. Create a detailed video storyboard/concept.
  Return ONLY valid JSON (no markdown, no code blocks): {
    "title": "video title",
    "concept": "overall concept in 2-3 sentences",
    "scenes": [{"time": "0:00", "description": "...", "camera": "...", "emoji": "..."}],
    "mood": "...",
    "soundtrack": "...",
    "colorGrading": "..."
  }
  Create ${Math.ceil(parseInt(duration)/5)} scenes for a ${duration}-second video.`;

  try {
    const raw = await callFreeLLM(
      `Create a detailed ${style} video storyboard for: "${prompt}"\nDuration: ${duration}s, Quality: ${quality}`,
      systemPrompt
    );

    let video;
    try {
      const clean = raw.replace(/```json|```/g, '').trim();
      video = JSON.parse(clean);
    } catch {
      video = {
        title: 'AI Video Concept',
        concept: prompt,
        scenes: [{ time: '0:00', description: prompt, camera: 'Wide shot', emoji: '🎬' }],
        mood: style, soundtrack: 'Ambient', colorGrading: 'Natural'
      };
    }

    renderVideoResult(outputPanel, video, prompt, style, duration, quality);
    addToGallery([{ title: video.title, description: video.concept, emoji: '🎬', mood: video.mood }], prompt, style, 'video');
  } catch (e) {
    outputPanel.innerHTML = `<div class="output-empty"><p style="color:var(--accent2)">Error: ${e.message}</p></div>`;
  } finally {
    setLoading(btn, false);
  }
}

// === RENDER VIDEO RESULT ===
function renderVideoResult(panel, video, prompt, style, duration, quality) {
  const colors = generateGradient(video.mood || style);
  panel.innerHTML = `
    <div class="video-result-card" style="width:100%">
      <div class="video-placeholder" style="background:${colors};">
        <div class="video-placeholder-bg"></div>
        <div class="play-icon">▶</div>
        <div style="position:relative;z-index:1;text-align:center;color:#fff;">
          <div style="font-size:20px;font-weight:700;margin-bottom:4px;">${video.title}</div>
          <div style="font-size:13px;opacity:0.7;">${duration}s • ${quality} • ${style}</div>
        </div>
      </div>
      <div class="video-frames">
        ${video.scenes.slice(0,6).map(s => `
          <div class="video-frame" title="${s.description}">
            <div style="text-align:center">
              <div style="font-size:18px">${s.emoji || '🎬'}</div>
              <div style="font-size:9px;color:var(--text-muted);margin-top:2px">${s.time}</div>
            </div>
          </div>
        `).join('')}
      </div>
      <div class="video-info">
        <div class="video-title">${video.title}</div>
        <div class="video-meta">${video.concept}</div>
        <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap;">
          <span class="gallery-style">🎭 ${video.mood}</span>
          <span class="gallery-style" style="background:rgba(92,240,252,0.1);color:var(--accent3)">🎵 ${video.soundtrack}</span>
          <span class="gallery-style" style="background:rgba(252,92,125,0.1);color:var(--accent2)">🎨 ${video.colorGrading}</span>
        </div>
      </div>
      <div style="padding:0 20px 20px;">
        <div style="font-size:13px;color:var(--text-muted);margin-bottom:12px;font-weight:600;">
          ${CONFIG.lang === 'ku' ? 'سکرین پلی' : CONFIG.lang === 'ar' ? 'السيناريو' : 'Storyboard'}
        </div>
        ${video.scenes.map((s, i) => `
          <div style="display:flex;gap:12px;padding:12px;background:var(--bg3);border-radius:8px;margin-bottom:8px;border:1px solid var(--border);">
            <div style="flex-shrink:0;width:36px;height:36px;background:var(--bg2);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:16px">${s.emoji||'🎬'}</div>
            <div>
              <div style="font-size:12px;color:var(--accent);font-family:var(--font-mono);margin-bottom:4px">${s.time}</div>
              <div style="font-size:14px;line-height:1.5">${s.description}</div>
              <div style="font-size:12px;color:var(--text-muted);margin-top:4px">📷 ${s.camera}</div>
            </div>
          </div>
        `).join('')}
      </div>
    </div>
  `;
}

// === GALLERY ===
function addToGallery(items, prompt, style, type) {
  items.forEach(item => {
    gallery.unshift({ ...item, prompt, style, type, date: new Date().toISOString() });
  });
  if (gallery.length > 50) gallery = gallery.slice(0, 50);
  localStorage.setItem('gallery', JSON.stringify(gallery));
  renderGallery();
}

function renderGallery() {
  const grid = document.getElementById('galleryGrid');
  if (!gallery.length) {
    grid.innerHTML = `<div class="gallery-empty"><p data-${CONFIG.lang}="${
      CONFIG.lang === 'ku' ? 'هێشتا هیچ دروستنەکراوە. دەستپێبکە!' :
      CONFIG.lang === 'ar' ? 'لا يوجد شيء بعد. ابدأ الإنشاء!' :
      "Nothing yet. Start creating!"
    }">هێشتا هیچ دروستنەکراوە. دەستپێبکە!</p></div>`;
    return;
  }
  grid.innerHTML = gallery.slice(0, 12).map(item => `
    <div class="gallery-item">
      <div style="aspect-ratio:1;background:${generateGradient(item.mood||item.style)};display:flex;align-items:center;justify-content:center;font-size:60px;">
        ${item.type === 'video' ? '🎬' : (item.emoji || '🎨')}
      </div>
      <div class="gallery-meta">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
          <span style="font-size:12px;opacity:0.5">${item.type === 'video' ? '🎬' : '🖼️'}</span>
          <span style="font-size:14px;font-weight:600;">${item.title || 'Untitled'}</span>
        </div>
        <div class="gallery-prompt">${item.prompt}</div>
        <span class="gallery-style">${item.style}</span>
      </div>
    </div>
  `).join('');
}

// === HELPERS ===
function generateGradient(mood) {
  const maps = {
    cinematic: 'linear-gradient(135deg, #0d0d2b, #1a0535, #2d0b62)',
    photorealistic: 'linear-gradient(135deg, #1a2a3a, #0d3b2b, #1a2a1a)',
    anime: 'linear-gradient(135deg, #2d0b4e, #4e0b2d, #0b2d4e)',
    documentary: 'linear-gradient(135deg, #2a1a0a, #3a2a1a, #1a0a0a)',
    default: 'linear-gradient(135deg, #1a0535, #0d1535, #35150d)'
  };
  const key = Object.keys(maps).find(k => mood && mood.toLowerCase().includes(k));
  return maps[key] || maps.default;
}

function setLoading(btn, loading) {
  const text = btn.querySelector('.btn-text');
  const loader = btn.querySelector('.btn-loader');
  btn.disabled = loading;
  if (loading) {
    text.classList.add('hidden');
    loader.classList.remove('hidden');
    btn.style.opacity = '0.7';
  } else {
    text.classList.remove('hidden');
    loader.classList.add('hidden');
    btn.style.opacity = '1';
  }
}

function showOutputLoading(panel, type) {
  const msgs = {
    ku: { image: 'وێنەکە دروست دەکرێت...', video: 'ڤیدیۆکە دروست دەکرێت...' },
    ar: { image: 'جاري إنشاء الصورة...', video: 'جاري إنشاء الفيديو...' },
    en: { image: 'Generating image...', video: 'Generating video...' }
  };
  const steps = {
    ku: ['تێگەیشتن لە وەسفەکە...', 'دروستکردنی ئایدیا...', 'خستنەکار بردن...'],
    ar: ['تحليل الوصف...', 'توليد الأفكار...', 'إنهاء التفاصيل...'],
    en: ['Analyzing prompt...', 'Generating concepts...', 'Finalizing details...']
  };

  let stepIdx = 0;
  panel.innerHTML = `
    <div class="loading-overlay" style="position:relative;inset:auto;width:100%;height:300px;background:transparent;">
      <div class="loading-orb"></div>
      <div class="loading-text" id="loadingMsg">${msgs[CONFIG.lang][type]}</div>
      <div class="loading-step" id="loadingStep">${steps[CONFIG.lang][0]}</div>
    </div>
  `;

  const stepInterval = setInterval(() => {
    stepIdx = (stepIdx + 1) % steps[CONFIG.lang].length;
    const el = document.getElementById('loadingStep');
    if (el) el.textContent = steps[CONFIG.lang][stepIdx];
    else clearInterval(stepInterval);
  }, 1200);
}

function copyPrompt(text) {
  navigator.clipboard.writeText(text).then(() => {
    showToast(CONFIG.lang === 'ku' ? 'کۆپیکرا ✓' : CONFIG.lang === 'ar' ? 'تم النسخ ✓' : 'Copied ✓', 'success');
  });
}

function downloadCard(btn, title) {
  showToast(CONFIG.lang === 'ku' ? 'داگیرساندن...' : CONFIG.lang === 'ar' ? 'جاري التحميل...' : 'Downloading...');
}

function escStr(str) {
  return (str || '').replace(/'/g, "\\'").replace(/"/g, '\\"').substring(0, 100);
}

// === CLICK OUTSIDE MODAL ===
document.getElementById('apiModal').addEventListener('click', function(e) {
  if (e.target === this) closeApiModal();
});
