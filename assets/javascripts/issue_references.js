// Issue Reference - 折りたたみ/展開機能、表示モード切り替え、ソート機能、フィルター機能
console.log('issue_references.js loaded');
(function() {
  console.log('IIFE started');
  document.addEventListener('DOMContentLoaded', function() {
    console.log('DOMContentLoaded fired');
    var DISMISS_ANIMATION_DURATION_MS = 480;
    
    setupDismissedToggleButtons();
    setupReferenceActionForms();

    // フィルター機能
    var currentFilters = {}; // 各リストのフィルター状態を保持
    
    // フィルター適用ボタン
    document.querySelectorAll('.issue-reference-filter-apply').forEach(function(button) {
      button.addEventListener('click', function() {
        var inputId = this.getAttribute('data-input');
        var targetId = this.getAttribute('data-target');
        var input = document.getElementById(inputId);
        
        if (input && targetId) {
          var filterText = input.value.trim();
          currentFilters[targetId] = filterText;
          applyFilter(targetId, filterText);
          
          // フィルターをローカルストレージに保存
          localStorage.setItem('issueReferenceFilter_' + targetId, filterText);
        }
      });
    });
    
    // フィルタークリアボタン
    document.querySelectorAll('.issue-reference-filter-clear').forEach(function(button) {
      button.addEventListener('click', function() {
        var inputId = this.getAttribute('data-input');
        var targetId = this.getAttribute('data-target');
        var input = document.getElementById(inputId);
        
        if (input && targetId) {
          input.value = '';
          currentFilters[targetId] = '';
          applyFilter(targetId, '');
          
          // フィルターをローカルストレージから削除
          localStorage.removeItem('issueReferenceFilter_' + targetId);
        }
      });
    });
    
    // Enterキーでフィルター適用
    document.querySelectorAll('.issue-reference-filter-input').forEach(function(input) {
      var targetId = input.getAttribute('data-target');
      
      // 保存されたフィルターを復元
      var savedFilter = localStorage.getItem('issueReferenceFilter_' + targetId);
      if (savedFilter) {
        input.value = savedFilter;
        currentFilters[targetId] = savedFilter;
        applyFilter(targetId, savedFilter);
      }
      
      input.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
          var filterText = this.value.trim();
          var targetId = this.getAttribute('data-target');
          currentFilters[targetId] = filterText;
          applyFilter(targetId, filterText);
          
          // フィルターをローカルストレージに保存
          localStorage.setItem('issueReferenceFilter_' + targetId, filterText);
        }
      });
    });
    
    function applyFilter(targetId, filterText) {
      var container = document.getElementById(targetId);
      if (!container) return;
      
      var items = container.querySelectorAll('.reference-item');
      var visibleCount = 0;
      
      if (!filterText) {
        // フィルターが空の場合、すべて表示
        items.forEach(function(item) {
          item.style.display = '';
          visibleCount++;
        });
      } else {
        // フィルター条件を含むものだけ表示
        var searchText = filterText.toLowerCase();
        items.forEach(function(item) {
          var title = item.getAttribute('data-wiki-title').toLowerCase();
          var textBlock = item.getAttribute('data-text-block').toLowerCase();
          var extractedData = (item.getAttribute('data-extracted-data') || '').toLowerCase();
          
          if (title.indexOf(searchText) >= 0 || 
              textBlock.indexOf(searchText) >= 0 || 
              extractedData.indexOf(searchText) >= 0) {
            item.style.display = '';
            visibleCount++;
          } else {
            item.style.display = 'none';
          }
        });
      }
      
      // フィルター後の件数表示を更新
      updateFilteredCount(container, visibleCount, filterText);
    }
    
    function updateFilteredCount(container, visibleCount, filterText) {
      var referencesDiv = container.closest('.issue-references');
      if (!referencesDiv) return;
      
      var filteredCountSpan = referencesDiv.querySelector('.reference-filtered-count');
      if (!filteredCountSpan) return;
      
      if (filterText) {
        var filteredLabel = window.I18n && window.I18n.label_filtered_count ? window.I18n.label_filtered_count : '[I18n NG]';
        console.log('label_filtered_count:', filteredLabel);
        filteredCountSpan.textContent = ' (' + visibleCount + ' ' + filteredLabel + ')';
        filteredCountSpan.style.display = 'inline';
      } else {
        filteredCountSpan.style.display = 'none';
      }
    }

    function setupDismissedToggleButtons() {
      document.querySelectorAll('.issue-reference-toggle-dismissed').forEach(function(button) {
        var targetId = button.getAttribute('data-target');
        var initialState = false;
        setDismissedToggleState(button, targetId, initialState);

        button.addEventListener('click', function() {
          var currentState = this.getAttribute('aria-pressed') === 'true';
          var nextState = !currentState;
          setDismissedToggleState(this, targetId, nextState);
        });
      });
    }

    function setDismissedToggleState(button, targetId, showDismissed) {
      button.setAttribute('aria-pressed', showDismissed ? 'true' : 'false');
      var labelShow = button.getAttribute('data-show-label') || 'Show hidden';
      var labelHide = button.getAttribute('data-hide-label') || 'Hide hidden';
      button.textContent = showDismissed ? labelHide : labelShow;

      var container = document.getElementById(targetId);
      if (!container) return;
      container.setAttribute('data-show-dismissed', showDismissed ? 'true' : 'false');
      container.classList.toggle('show-dismissed', showDismissed);

      if (showDismissed) {
        container.querySelectorAll('.reference-item.dismissed').forEach(function(item) {
          resetDismissedAnimationState(item);
        });
      }
    }

    function setupReferenceActionForms() {
      document.addEventListener('submit', function(event) {
        var targetForm = event.target.closest('.reference-action-form');
        if (!targetForm) {
          return;
        }

        event.preventDefault();
        handleReferenceAction(targetForm);
      });
    }

    function handleReferenceAction(form) {
      var url = form.getAttribute('action');
      var referenceItem = form.closest('.reference-item');
      var actionType = (form.dataset.actionType || '').toLowerCase();
      var messages = getIssueReferenceMessages();
      var errorMessage = form.dataset.errorMessage || messages.actionError;

      sendReferenceRequest(url)
        .then(function(response) {
          var dismissed = actionType === 'dismiss';
          if (actionType === 'restore') {
            dismissed = false;
          }
          setReferenceDismissedState(referenceItem, dismissed);
          updateReferenceCounts(referenceItem);
        })
        .catch(function(error) {
          console.error('Failed to update reference visibility', error);
          showFlashMessage('error', errorMessage);
        });
    }

    function sendReferenceRequest(url) {
      var token = getMetaContent('csrf-token');
      return fetch(url, {
        method: 'POST',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': token,
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      }).then(function(response) {
        if (!response.ok) {
          throw new Error('Request failed with status ' + response.status);
        }
        return response.json().catch(function() {
          return {};
        });
      });
    }

    function setReferenceDismissedState(referenceItem, dismissed) {
      if (!referenceItem) {
        return;
      }

      referenceItem.dataset.dismissed = dismissed ? 'true' : 'false';
      referenceItem.classList.toggle('dismissed', dismissed);

      var dismissForm = referenceItem.querySelector('.reference-dismiss-form');
      var restoreForm = referenceItem.querySelector('.reference-restore-form');
      if (dismissForm) {
        dismissForm.classList.toggle('reference-action-hidden', dismissed);
      }
      if (restoreForm) {
        restoreForm.classList.toggle('reference-action-hidden', !dismissed);
      }

      var referenceList = referenceItem.closest('.reference-list');
      var showDismissed = referenceList && referenceList.getAttribute('data-show-dismissed') === 'true';

      if (dismissed && !showDismissed) {
        animateReferenceDismissal(referenceItem);
      } else if (!dismissed) {
        resetDismissedAnimationState(referenceItem);
      }
    }

    function updateReferenceCounts(referenceItem) {
      var wrapper = referenceItem && referenceItem.closest('.issue-references');
      if (!wrapper) return;

      var summary = wrapper.querySelector('.reference-count-summary');
      if (!summary) return;

      var total = parseInt(summary.getAttribute('data-total-count'), 10) || 0;
      var dismissedCount = wrapper.querySelectorAll('.reference-item.dismissed').length;
      var dismissedWrapper = summary.querySelector('.reference-dismissed-wrapper');
      var dismissedValue = summary.querySelector('.reference-dismissed-count');

      if (dismissedValue) {
        dismissedValue.textContent = dismissedCount;
      }

      if (dismissedWrapper) {
        dismissedWrapper.style.display = dismissedCount > 0 ? 'inline' : 'none';
      }

      summary.setAttribute('data-dismissed-count', dismissedCount);
      summary.setAttribute('data-visible-count', Math.max(total - dismissedCount, 0));

      var toggleButton = wrapper.querySelector('.issue-reference-toggle-dismissed');
      if (toggleButton) {
        var showLabel = toggleButton.getAttribute('data-show-label') || 'Show hidden';
        var hideLabel = toggleButton.getAttribute('data-hide-label') || 'Hide hidden';
        var list = wrapper.querySelector('.reference-list');
        var showDismissed = list && list.getAttribute('data-show-dismissed') === 'true';
        toggleButton.textContent = showDismissed ? hideLabel : showLabel;
        toggleButton.setAttribute('aria-pressed', showDismissed ? 'true' : 'false');
      }
    }

    function getMetaContent(name) {
      var element = document.querySelector('meta[name="' + name + '"]');
      return element ? element.getAttribute('content') : null;
    }

    function getIssueReferenceMessages() {
      var defaults = {
        dismissSuccess: 'Reference hidden.',
        restoreSuccess: 'Reference restored.',
        actionError: 'Failed to update reference.'
      };

      if (window.IssueReferences && window.IssueReferences.messages) {
        return Object.assign(defaults, window.IssueReferences.messages);
      }
      return defaults;
    }

    function animateReferenceDismissal(referenceItem) {
      if (!referenceItem) {
        return;
      }

      resetDismissedAnimationState(referenceItem);
      referenceItem.classList.add('reference-dismiss-animating');
      referenceItem.style.display = 'block';
      referenceItem.style.opacity = '1';
      referenceItem.style.transform = 'translateY(0)';
      var measuredHeight = referenceItem.scrollHeight || referenceItem.offsetHeight || 0;
      referenceItem.style.maxHeight = measuredHeight + 'px';
      referenceItem.style.overflow = 'hidden';

      referenceItem.getBoundingClientRect(); // Force reflow so transition starts from measured height

      requestAnimationFrame(function() {
        referenceItem.classList.add('reference-dismissing');
        referenceItem.style.maxHeight = '0px';
      });

      if (referenceItem.dismissAnimationTimer) {
        clearTimeout(referenceItem.dismissAnimationTimer);
      }

      referenceItem.dismissAnimationTimer = setTimeout(function() {
        referenceItem.classList.remove('reference-dismissing');
        referenceItem.classList.remove('reference-dismiss-animating');
        referenceItem.style.removeProperty('display');
        referenceItem.style.removeProperty('opacity');
        referenceItem.style.removeProperty('transform');
        referenceItem.style.removeProperty('max-height');
        referenceItem.style.removeProperty('overflow');
        referenceItem.dismissAnimationTimer = null;
      }, DISMISS_ANIMATION_DURATION_MS);
    }

    function resetDismissedAnimationState(referenceItem) {
      if (!referenceItem) {
        return;
      }

      if (referenceItem.dismissAnimationTimer) {
        clearTimeout(referenceItem.dismissAnimationTimer);
        referenceItem.dismissAnimationTimer = null;
      }

      referenceItem.classList.remove('reference-dismissing');
      referenceItem.classList.remove('reference-dismiss-animating');
      referenceItem.style.removeProperty('display');
      referenceItem.style.removeProperty('opacity');
      referenceItem.style.removeProperty('transform');
      referenceItem.style.removeProperty('max-height');
      referenceItem.style.removeProperty('overflow');
    }
    
    // ソート機能
    document.querySelectorAll('.issue-reference-sort').forEach(function(select) {
      var targetId = select.getAttribute('data-target');
      
      // 保存されたソート項目を復元（グローバル設定）
      var savedSort = localStorage.getItem('issueReferenceSort');
      if (savedSort) {
        select.value = savedSort;
        sortReferences(targetId, savedSort);
      }
      
      select.addEventListener('change', function() {
        var sortType = this.value;
        var targetId = this.getAttribute('data-target');
        
        sortReferences(targetId, sortType);
        
        // ソート項目をローカルストレージに保存（グローバル設定）
        localStorage.setItem('issueReferenceSort', sortType);
        
        // ソート後もフィルターを再適用
        if (currentFilters[targetId]) {
          applyFilter(targetId, currentFilters[targetId]);
        }
      });
    });
    
    function sortReferences(targetId, sortType) {
      var container = document.getElementById(targetId);
      if (!container) return;
      
      var items = Array.from(container.querySelectorAll('.reference-item'));
      
      items.sort(function(a, b) {
        switch (sortType) {
          case 'newest':
            // 新しい順（更新日時の降順）
            return parseInt(b.getAttribute('data-updated-at')) - parseInt(a.getAttribute('data-updated-at'));
          
          case 'oldest':
            // 古い順（更新日時の昇順）
            return parseInt(a.getAttribute('data-updated-at')) - parseInt(b.getAttribute('data-updated-at'));
          
          case 'title_asc':
            // タイトル昇順
            var titleA = a.getAttribute('data-wiki-title').toLowerCase();
            var titleB = b.getAttribute('data-wiki-title').toLowerCase();
            return titleA.localeCompare(titleB);
          
          case 'title_desc':
            // タイトル降順
            var titleA = a.getAttribute('data-wiki-title').toLowerCase();
            var titleB = b.getAttribute('data-wiki-title').toLowerCase();
            return titleB.localeCompare(titleA);
          
          default:
            return 0;
        }
      });
      
      // 並び替えたアイテムをDOMに再配置
      items.forEach(function(item) {
        container.appendChild(item);
      });
    }
    
    // 表示モード切り替え
    document.querySelectorAll('.issue-reference-view-mode').forEach(function(button) {
      // 保存されたモードを復元（グローバル設定）
      var targetId = button.getAttribute('data-target');
      var savedMode = localStorage.getItem('issueReferenceViewMode');
      if (savedMode) {
        setViewMode(button, savedMode);
      }
      
      button.addEventListener('click', function(e) {
        e.preventDefault();
        var currentMode = this.getAttribute('data-mode');
        var newMode = currentMode === 'detailed' ? 'compact' : 'detailed';
        setViewMode(this, newMode);
        
        // モードをローカルストレージに保存（グローバル設定）
        var targetId = this.getAttribute('data-target');
        localStorage.setItem('issueReferenceViewMode', newMode);
        
        // 表示モード切り替え後もフィルターを維持（display設定が上書きされないように再適用）
        if (currentFilters[targetId]) {
          applyFilter(targetId, currentFilters[targetId]);
        }
      });
    });
    
    function setViewMode(button, mode) {
      var targetId = button.getAttribute('data-target');
      var targetElement = document.getElementById(targetId);
      var labelDetailed = button.getAttribute('data-label-detailed') || 'Detailed';
      var labelCompact = button.getAttribute('data-label-compact') || 'Compact';
      
      button.setAttribute('data-mode', mode);
      
      if (targetElement) {
        targetElement.setAttribute('data-view-mode', mode);
        
        if (mode === 'compact') {
          // 簡略表示中 → 次は詳細表示に切り替わるので「詳細表示」ボタンを表示
          button.innerHTML = '<span class="mode-icon">■</span> ' + labelDetailed;
          targetElement.querySelectorAll('.reference-item').forEach(function(item) {
            // 詳細表示を非表示
            var detailedView = item.querySelector('.reference-detailed-view');
            if (detailedView) detailedView.style.display = 'none';
            
            // 簡略表示を表示
            var compactView = item.querySelector('.reference-compact-view');
            if (compactView) compactView.style.display = 'block';
            
            // アイテム全体のスタイルを簡略表示用に調整
            item.style.marginBottom = '8px';
            item.style.padding = '8px 10px';
          });
        } else {
          // 詳細表示中 → 次は簡略表示に切り替わるので「簡略表示」ボタンを表示
          button.innerHTML = '<span class="mode-icon">▦</span> ' + labelCompact;
          targetElement.querySelectorAll('.reference-item').forEach(function(item) {
            // 詳細表示を表示
            var detailedView = item.querySelector('.reference-detailed-view');
            if (detailedView) detailedView.style.display = 'block';
            
            // 簡略表示を非表示
            var compactView = item.querySelector('.reference-compact-view');
            if (compactView) compactView.style.display = 'none';
            
            // アイテム全体のスタイルを詳細表示用に調整
            item.style.marginBottom = '15px';
            item.style.padding = '10px';
          });
        }
      }
    }
    
    // 折りたたみボタンのクリックイベント
    document.querySelectorAll('.issue-reference-toggle').forEach(function(toggle) {
      var targetId = toggle.getAttribute('data-target');

      // 保存された折りたたみ状態を復元（グローバル設定）
      var savedCollapsed = localStorage.getItem('issueReferenceCollapsed');
      if (savedCollapsed === 'true') {
        var targetElement = document.getElementById(targetId);
        if (targetElement) {
          targetElement.style.display = 'none';
          toggle.classList.remove('icon-collapsed');
          toggle.classList.add('icon-expanded');
          toggle.textContent = toggle.getAttribute('data-label-expand') || 'Expand';
        }
      }

      toggle.addEventListener('click', function(e) {
        e.preventDefault();
        
        var targetId = this.getAttribute('data-target');
        var targetElement = document.getElementById(targetId);
        
        if (targetElement) {
          if (targetElement.style.display === 'none') {
            // 展開
            targetElement.style.display = 'block';
            this.classList.remove('icon-expanded');
            this.classList.add('icon-collapsed');
            this.textContent = this.getAttribute('data-label-collapse') || 'Collapse';
            localStorage.setItem('issueReferenceCollapsed', 'false');
          } else {
            // 折りたたみ
            targetElement.style.display = 'none';
            this.classList.remove('icon-collapsed');
            this.classList.add('icon-expanded');
            this.textContent = this.getAttribute('data-label-expand') || 'Expand';
            localStorage.setItem('issueReferenceCollapsed', 'true');
          }
        }
      });
    });
    
    // === 手動転記機能 ===
    // ボタンは常に表示（チェック状態に関わらず）
    
    // ボタンのテキストを編集モードに応じて更新
    function updateTranscribeButtonText() {
      var transcribeButtons = document.querySelectorAll('.issue-reference-transcribe');
      var isEditMode = findJournalTextarea() !== null;

      transcribeButtons.forEach(function(button) {
        if (isEditMode) {
          if (window.I18n && typeof window.I18n.t === 'function') {
            var newText = I18n.t('button_transcribe_selected');
            var newTitle = I18n.t('tooltip_transcribe_selected');
          } else {
            var newText = button.getAttribute('data-transcribe-text') || button.textContent;
            var newTitle = button.getAttribute('data-transcribe-title') || button.title;
          }
          if (button.textContent !== newText) {
            button.textContent = newText;
            button.title = newTitle;
          }
        } else {
          if (window.I18n && typeof window.I18n.t === 'function') {
            var newText = I18n.t('button_copy_selected');
            var newTitle = I18n.t('tooltip_copy_selected');
          } else {
            var newText = button.getAttribute('data-copy-text') || button.textContent;
            var newTitle = button.getAttribute('data-copy-title') || button.title;
          }
          if (button.textContent !== newText) {
            button.textContent = newText;
            button.title = newTitle;
          }
        }
      });
    }
    
    // 初期表示時にボタンテキストを設定
    updateTranscribeButtonText();
    
    // 編集ボタンとキャンセルボタンのクリックを監視
    document.addEventListener('click', function(e) {
      var target = e.target;
      // 編集ボタン（更新リンク）、キャンセルボタン、送信ボタンをクリックした場合
      if (target.matches('a.icon-edit') || 
          target.matches('input[type="submit"]') || 
          target.matches('a') ||
          target.closest('a.icon-edit')) {
        // 少し遅延させてDOMが更新されるのを待つ
        setTimeout(updateTranscribeButtonText, 100);
        setTimeout(updateTranscribeButtonText, 500); // さらに遅延してもう一度チェック
      }
    });
    
    // フォーカスが戻ったときもチェック（編集モード終了の可能性）
    window.addEventListener('focus', function() {
      setTimeout(updateTranscribeButtonText, 100);
    });
    
    // 転記ボタンのクリックハンドラ
    var transcribeButtons = document.querySelectorAll('.issue-reference-transcribe');
    console.log('Found transcribe buttons:', transcribeButtons.length);
    
    transcribeButtons.forEach(function(button) {
      console.log('Attaching click handler to button:', button);
      button.addEventListener('click', function(e) {
        console.log('Transcribe button clicked!');
        e.preventDefault(); // デフォルト動作を防止
        
        var checkboxes = document.querySelectorAll('.reference-checkbox:checked');
        console.log('Checked checkboxes:', checkboxes.length);
        
        if (checkboxes.length === 0) {
          showFlashMessage('warning', '記事がチェックされていません。転記する参照を選択してください。');
          return;
        }
        
        // チェックされた参照情報を収集
        var references = [];
        checkboxes.forEach(function(checkbox) {
          var wikiTitle = checkbox.getAttribute('data-wiki-title');
          var wikiUrl = checkbox.getAttribute('data-wiki-url');
          var textBlock = checkbox.getAttribute('data-text-block');
          var extractedDataStr = checkbox.getAttribute('data-extracted-data');
          
          var extractedData = null;
          if (extractedDataStr && extractedDataStr !== '{}' && extractedDataStr !== 'null') {
            try {
              extractedData = JSON.parse(extractedDataStr);
            } catch (e) {
              console.error('Failed to parse extracted data:', e);
            }
          }
          
          references.push({
            wikiTitle: wikiTitle,
            wikiUrl: wikiUrl,
            textBlock: textBlock,
            extractedData: extractedData
          });
        });
        
        // テキストを生成
        var transcribedText = generateTranscribedText(references);
        
        // JournalのTextareaを探す
        var textarea = findJournalTextarea();
        
        if (textarea) {
          // 編集モード: Textareaに直接挿入
          insertIntoJournal(transcribedText, textarea);
          showFlashMessage('success', references.length + '件の参照をコメントに挿入しました。内容を確認して送信してください。');
          
          // チェックボックスをすぐにクリア
          checkboxes.forEach(function(checkbox) {
            checkbox.checked = false;
          });
        } else {
          // 非編集モード: クリップボードにコピー
          copyToClipboard(transcribedText, references.length, button);
          
          // チェックボックスのクリアを遅延（視覚的フィードバックの後）
          setTimeout(function() {
            checkboxes.forEach(function(checkbox) {
              checkbox.checked = false;
            });
          }, 3000);
        }
      });
    });
    
    // JournalのTextareaを探す（編集モードの場合のみ）
    function findJournalTextarea() {
      // 編集モードかどうかを確認
      var editForm = document.querySelector('form.edit_issue');
      if (!editForm) {
        return null;
      }
      
      // 編集モードの場合のみTextareaを探す
      var textarea = document.getElementById('issue_notes');
      if (!textarea) {
        textarea = document.querySelector('textarea[name="issue[notes]"]');
      }
      
      // Textareaが表示されているかも確認
      if (textarea && textarea.offsetParent !== null) {
        return textarea;
      }
      
      return null;
    }
    
    // 転記テキストを生成
    function generateTranscribedText(references) {
      var lines = [];
      lines.push('---');
      lines.push('');
      
      references.forEach(function(ref) {
        lines.push('### ' + ref.wikiTitle);
        lines.push('');
        
        // 抽出データがあれば追加
        if (ref.extractedData && Object.keys(ref.extractedData).length > 0) {
          for (var key in ref.extractedData) {
            var value = ref.extractedData[key];
            if (Array.isArray(value)) {
              value = value.join(', ');
            }
            lines.push('**' + key + '**: ' + value);
          }
          lines.push('');
        }
        
        // テキストブロック
        lines.push(ref.textBlock);
        lines.push('');
        lines.push('[→ ' + ref.wikiTitle + '](' + ref.wikiUrl + ')');
        lines.push('');
      });
      
      lines.push('---');
      
      return lines.join('\n');
    }
    
    // JournalのTextareaに挿入
    function insertIntoJournal(text, textarea) {
      var currentValue = textarea.value;
      if (currentValue && !currentValue.endsWith('\n')) {
        textarea.value = currentValue + '\n\n' + text;
      } else if (currentValue) {
        textarea.value = currentValue + text;
      } else {
        textarea.value = text;
      }
      
      textarea.focus();
      textarea.setSelectionRange(textarea.value.length, textarea.value.length);
      textarea.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    
    // クリップボードにコピー
    function copyToClipboard(text, count, button) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
          showCopySuccess(count, button);
        }).catch(function(err) {
          console.error('Failed to copy to clipboard:', err);
          fallbackCopyToClipboard(text, count, button);
        });
      } else {
        fallbackCopyToClipboard(text, count, button);
      }
    }
    
    // クリップボードコピーのフォールバック
    function fallbackCopyToClipboard(text, count, button) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      
      try {
        document.execCommand('copy');
        showCopySuccess(count, button);
      } catch (err) {
        console.error('Failed to copy to clipboard:', err);
        showFlashMessage('error', 'クリップボードへのコピーに失敗しました。');
        alert('クリップボードへのコピーに失敗しました。');
      }
      
      document.body.removeChild(textarea);
    }
    
    // コピー成功時のフィードバック
    function showCopySuccess(count, button) {
      var message = count + '件の参照をクリップボードにコピーしました。編集モードでコメントに貼り付けてください。';
      showFlashMessage('notice', message);
    }
    
    // フラッシュメッセージを表示
    function showFlashMessage(type, message) {
      var flash = document.getElementById('flash_' + type);
      
      if (!flash) {
        flash = document.createElement('div');
        flash.id = 'flash_' + type;
        flash.className = 'flash ' + type;
        flash.style.cssText = 'padding: 4px 4px 4px 30px; margin-bottom: 12px; font-size: 14px; border: 2px solid;';
        
        if (type === 'notice' || type === 'success') {
          flash.style.backgroundColor = '#dff0d8';
          flash.style.borderColor = '#d6e9c6';
          flash.style.color = '#3c763d';
        } else if (type === 'warning') {
          flash.style.backgroundColor = '#fcf8e3';
          flash.style.borderColor = '#faebcc';
          flash.style.color = '#8a6d3b';
        } else if (type === 'error') {
          flash.style.backgroundColor = '#f2dede';
          flash.style.borderColor = '#ebccd1';
          flash.style.color = '#a94442';
        }
        
        var content = document.getElementById('content');
        if (content) {
          content.insertBefore(flash, content.firstChild);
        } else {
          document.body.insertBefore(flash, document.body.firstChild);
        }
      }
      
      flash.textContent = message;
      flash.style.display = 'block';
      
      // メッセージをスクロールして表示
      flash.scrollIntoView({ behavior: 'smooth', block: 'start' });
      
      setTimeout(function() {
        if (flash.parentNode) {
          flash.style.display = 'none';
        }
      }, 5000);
    }  });
})();