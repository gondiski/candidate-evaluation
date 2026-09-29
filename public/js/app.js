// HTMX progress polling
document.addEventListener('htmx:beforeRequest', function(event) {
  // Show loading indicator
  const indicator = document.querySelector('#loading-indicator');
  if (indicator) {
    indicator.style.display = 'block';
  }
});

document.addEventListener('htmx:afterRequest', function(event) {
  // Hide loading indicator
  const indicator = document.querySelector('#loading-indicator');
  if (indicator) {
    indicator.style.display = 'none';
  }
});

// Progress polling
function startProgressPolling(evaluationId) {
  const progressBar = document.querySelector('.progress-bar-fill');
  const progressText = document.querySelector('.progress-text');
  
  if (!progressBar || !progressText) return;
  
  const interval = setInterval(async () => {
    try {
      const response = await fetch(`/stages/${evaluationId}/progress`);
      const data = await response.json();
      
      // Update progress bar
      const stages = ['briefing', 'job_description', 'weights', 'human_gates', 'cvs', 'verification', 'pre_report', 'diagnosis', 'final_report'];
      const currentIndex = stages.indexOf(data.stage);
      const progress = ((currentIndex + 1) / stages.length) * 100;
      
      progressBar.style.width = `${progress}%`;
      progressText.textContent = `Stage: ${data.stage} ${data.detail ? '- ' + data.detail : ''}`;
      
      // Stop polling if completed
      if (data.stage === 'final_report' && data.detail === 'completed') {
        clearInterval(interval);
      }
    } catch (error) {
      console.error('Error polling progress:', error);
    }
  }, 2000);
  
  return interval;
}

// Auto-resize textareas
document.addEventListener('DOMContentLoaded', function() {
  const textareas = document.querySelectorAll('textarea');
  textareas.forEach(textarea => {
    textarea.addEventListener('input', function() {
      this.style.height = 'auto';
      this.style.height = (this.scrollHeight) + 'px';
    });
  });
});

// Confirm before purge
document.addEventListener('DOMContentLoaded', function() {
  const purgeButtons = document.querySelectorAll('.btn-danger');
  purgeButtons.forEach(button => {
    if (button.textContent.includes('Purge')) {
      button.addEventListener('click', function(e) {
        if (!confirm('This will permanently delete all data including CVs, candidates, scores, and reports. Continue?')) {
          e.preventDefault();
        }
      });
    }
  });
});

// Gate mark validation
document.addEventListener('DOMContentLoaded', function() {
  const gateForms = document.querySelectorAll('.gate-mark-form');
  gateForms.forEach(form => {
    form.addEventListener('submit', function(e) {
      const selects = form.querySelectorAll('select');
      let hasBlank = false;
      
      selects.forEach(select => {
        if (!select.value) {
          hasBlank = true;
          select.classList.add('error');
        } else {
          select.classList.remove('error');
        }
      });
      
      if (hasBlank) {
        e.preventDefault();
        alert('All cells must be filled. Use NOT_REACHED if the candidate was not assessed.');
      }
    });
  });
});

// Score validation
document.addEventListener('DOMContentLoaded', function() {
  const scoreInputs = document.querySelectorAll('input[type="number"][min="0"][max="10"]');
  scoreInputs.forEach(input => {
    input.addEventListener('input', function() {
      const value = parseInt(this.value);
      if (value < 0) this.value = 0;
      if (value > 10) this.value = 10;
    });
  });
});
