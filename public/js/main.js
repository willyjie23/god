/**
 * 臺南市佳里廣澤信仰宗教協會 - 主程式
 */

document.addEventListener('DOMContentLoaded', function() {
  // 手機版選單切換
  initMobileMenu();

  // 滾動動畫
  initScrollAnimations();

  // 導航列滾動效果
  initNavbarScroll();

  // 捐款金額按鈕
  initAmountButtons();

  // 平滑滾動
  initSmoothScroll();
});

/**
 * 手機版選單切換
 */
function initMobileMenu() {
  const toggle = document.getElementById('navToggle');
  const menu = document.getElementById('navMenu');

  if (toggle && menu) {
    toggle.addEventListener('click', function() {
      menu.classList.toggle('active');
      toggle.classList.toggle('active');
    });

    // 點擊選單項目後關閉選單
    menu.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', function() {
        menu.classList.remove('active');
        toggle.classList.remove('active');
      });
    });
  }
}

/**
 * 滾動動畫 - 元素進入視窗時淡入
 */
function initScrollAnimations() {
  const fadeElements = document.querySelectorAll('.fade-in');

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  });

  fadeElements.forEach(el => observer.observe(el));
}

/**
 * 導航列滾動效果
 */
function initNavbarScroll() {
  const navbar = document.querySelector('.navbar');
  let lastScroll = 0;

  window.addEventListener('scroll', function() {
    const currentScroll = window.pageYOffset;

    if (currentScroll > 100) {
      navbar.style.background = 'rgba(45, 24, 16, 0.98)';
      navbar.style.boxShadow = '0 2px 30px rgba(0, 0, 0, 0.4)';
    } else {
      navbar.style.background = 'linear-gradient(180deg, var(--dark-brown) 0%, rgba(45, 24, 16, 0.95) 100%)';
      navbar.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.3)';
    }

    lastScroll = currentScroll;
  });
}

/**
 * 捐款金額按鈕
 */
function initAmountButtons() {
  const buttons = document.querySelectorAll('.amount-btn');
  const input = document.querySelector('input[name="amount"]');

  buttons.forEach(btn => {
    btn.addEventListener('click', function() {
      // 移除其他按鈕的 active 狀態
      buttons.forEach(b => b.classList.remove('active'));
      // 添加當前按鈕的 active 狀態
      this.classList.add('active');
      // 設定金額到輸入框
      if (input) {
        input.value = this.dataset.amount;
      }
    });
  });

  // 輸入框變更時移除按鈕 active 狀態
  if (input) {
    input.addEventListener('input', function() {
      buttons.forEach(b => b.classList.remove('active'));
    });
  }
}

/**
 * 平滑滾動
 */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      e.preventDefault();
      const targetId = this.getAttribute('href');
      const target = document.querySelector(targetId);

      if (target) {
        const navbarHeight = document.querySelector('.navbar').offsetHeight;
        const targetPosition = target.offsetTop - navbarHeight;

        window.scrollTo({
          top: targetPosition,
          behavior: 'smooth'
        });
      }
    });
  });
}

/**
 * 顯示訊息 - 使用安全的 DOM 方法
 */
function showMessage(message, type) {
  type = type || 'info';

  // 建立訊息元素
  const msgEl = document.createElement('div');
  msgEl.className = 'message message-' + type;

  // 建立內容容器
  const contentDiv = document.createElement('div');
  contentDiv.className = 'message-content';

  // 建立訊息文字（使用 textContent 避免 XSS）
  const textSpan = document.createElement('span');
  textSpan.textContent = message;

  // 建立關閉按鈕
  const closeBtn = document.createElement('button');
  closeBtn.className = 'message-close';
  closeBtn.textContent = '\u00D7'; // × 符號
  closeBtn.setAttribute('aria-label', '關閉');

  // 組裝元素
  contentDiv.appendChild(textSpan);
  contentDiv.appendChild(closeBtn);
  msgEl.appendChild(contentDiv);

  // 設定樣式
  var bgStyle = 'background: linear-gradient(135deg, #D4AF37 0%, #996515 100%); color: white;';
  if (type === 'success') {
    bgStyle = 'background: linear-gradient(135deg, #28a745 0%, #1e7e34 100%); color: white;';
  } else if (type === 'error') {
    bgStyle = 'background: linear-gradient(135deg, #dc3545 0%, #c82333 100%); color: white;';
  }

  msgEl.style.cssText =
    'position: fixed;' +
    'top: 100px;' +
    'left: 50%;' +
    'transform: translateX(-50%);' +
    'padding: 1rem 2rem;' +
    'border-radius: 8px;' +
    'z-index: 9999;' +
    'animation: slideDown 0.3s ease;' +
    'box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);' +
    bgStyle;

  document.body.appendChild(msgEl);

  // 關閉按鈕事件
  closeBtn.addEventListener('click', function() {
    msgEl.remove();
  });

  // 自動關閉
  setTimeout(function() {
    if (msgEl.parentNode) {
      msgEl.remove();
    }
  }, 5000);
}

// CSS 動畫（透過 JS 注入）
(function() {
  var style = document.createElement('style');
  style.textContent = [
    '@keyframes slideDown {',
    '  from {',
    '    opacity: 0;',
    '    transform: translateX(-50%) translateY(-20px);',
    '  }',
    '  to {',
    '    opacity: 1;',
    '    transform: translateX(-50%) translateY(0);',
    '  }',
    '}',
    '.message-content {',
    '  display: flex;',
    '  align-items: center;',
    '  gap: 1rem;',
    '}',
    '.message-close {',
    '  background: none;',
    '  border: none;',
    '  color: inherit;',
    '  font-size: 1.5rem;',
    '  cursor: pointer;',
    '  opacity: 0.8;',
    '  transition: opacity 0.3s;',
    '}',
    '.message-close:hover {',
    '  opacity: 1;',
    '}'
  ].join('\n');
  document.head.appendChild(style);
})();
