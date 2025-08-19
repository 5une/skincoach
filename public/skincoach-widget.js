/**
 * SkinCoach Widget - JavaScript client for the dermatology chatbot API
 * Usage: Include this script and call SkinCoach.init() to embed the widget
 */

window.SkinCoach = (function() {
  // Configuration
  const config = {
    apiBaseUrl: window.location.origin + '/api/v1',
    widgetId: 'skincoach-widget'
  };

  // API methods
  const api = {
    // Send a chat message about skin concerns (text only)
    async sendMessage(message) {
      try {
        const response = await fetch(`${config.apiBaseUrl}/chat/message`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ message: message })
        });
        
        return await response.json();
      } catch (error) {
        console.error('SkinCoach API Error:', error);
        throw error;
      }
    },

    // Analyze a photo with optional message
    async analyzePhoto(photoFile, message = null) {
      try {
        const formData = new FormData();
        formData.append('photo', photoFile);
        if (message) {
          formData.append('message', message);
        }
        
        const response = await fetch(`${config.apiBaseUrl}/chat/message`, {
          method: 'POST',
          body: formData
        });
        
        return await response.json();
      } catch (error) {
        console.error('SkinCoach Photo Analysis Error:', error);
        throw error;
      }
    },

    // Send message with photo (combined endpoint)
    async sendMessageWithPhoto(message, photoFile) {
      try {
        const formData = new FormData();
        if (message) formData.append('message', message);
        if (photoFile) formData.append('photo', photoFile);
        
        const response = await fetch(`${config.apiBaseUrl}/chat/message`, {
          method: 'POST',
          body: formData
        });
        
        return await response.json();
      } catch (error) {
        console.error('SkinCoach Message with Photo Error:', error);
        throw error;
      }
    },

    // Get consultation status
    async getConsultationStatus(consultationId) {
      try {
        const response = await fetch(`${config.apiBaseUrl}/chat/consultation/${consultationId}`);
        return await response.json();
      } catch (error) {
        console.error('SkinCoach Consultation Status Error:', error);
        throw error;
      }
    },

    // Get product recommendations
    async getProducts(filters = {}) {
      try {
        const params = new URLSearchParams();
        if (filters.category) params.append('category', filters.category);
        if (filters.concern) params.append('concern', filters.concern);
        if (filters.limit) params.append('limit', filters.limit);
        
        const response = await fetch(`${config.apiBaseUrl}/chat/products?${params}`);
        return await response.json();
      } catch (error) {
        console.error('SkinCoach Products Error:', error);
        throw error;
      }
    }
  };

  // Widget UI creation
  function createWidget() {
    const widget = document.createElement('div');
    widget.id = config.widgetId;
    widget.innerHTML = `
      <div style="
        position: fixed;
        bottom: 20px;
        right: 20px;
        width: 350px;
        height: 500px;
        background: white;
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.15);
        z-index: 10000;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        display: flex;
        flex-direction: column;
      ">
        <div style="
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 16px;
          border-radius: 12px 12px 0 0;
          font-weight: 600;
        ">
          🧴 SkinCoach Assistant
        </div>
        
        <div id="skincoach-messages" style="
          flex: 1;
          padding: 16px;
          overflow-y: auto;
          background: #f8f9fa;
        ">
          <div style="background: white; padding: 12px; border-radius: 8px; margin-bottom: 12px;">
            Hi! I'm your skincare assistant. Ask me about skin concerns or upload a photo for analysis.
          </div>
        </div>
        
        <div style="padding: 16px; background: white; border-radius: 0 0 12px 12px;">
          <div style="display: flex; gap: 8px; margin-bottom: 8px;">
            <input type="text" id="skincoach-input" placeholder="Ask about skincare..." style="
              flex: 1;
              padding: 8px 12px;
              border: 1px solid #ddd;
              border-radius: 20px;
              outline: none;
            ">
            <button id="skincoach-send" style="
              background: #667eea;
              color: white;
              border: none;
              padding: 8px 16px;
              border-radius: 20px;
              cursor: pointer;
            ">Send</button>
          </div>
          
          <div style="display: flex; gap: 8px; align-items: center;">
            <input type="file" id="skincoach-photo" accept="image/*" style="display: none;">
            <button id="skincoach-photo-btn" style="
              background: #28a745;
              color: white;
              border: none;
              padding: 6px 12px;
              border-radius: 16px;
              cursor: pointer;
              font-size: 12px;
            ">📸 Analyze Photo</button>
            <span style="font-size: 11px; color: #666;">Upload skin photo for analysis</span>
          </div>
        </div>
      </div>
    `;
    
    return widget;
  }

  // Widget functionality
  function initializeWidget() {
    const widget = createWidget();
    document.body.appendChild(widget);
    
    const messages = document.getElementById('skincoach-messages');
    const input = document.getElementById('skincoach-input');
    const sendBtn = document.getElementById('skincoach-send');
    const photoInput = document.getElementById('skincoach-photo');
    const photoBtn = document.getElementById('skincoach-photo-btn');

    // Add message to chat
    function addMessage(content, isUser = false) {
      const messageDiv = document.createElement('div');
      messageDiv.style.cssText = `
        background: ${isUser ? '#667eea' : 'white'};
        color: ${isUser ? 'white' : '#333'};
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 12px;
        max-width: 85%;
        ${isUser ? 'margin-left: auto;' : ''}
      `;
      messageDiv.innerHTML = content;
      messages.appendChild(messageDiv);
      messages.scrollTop = messages.scrollHeight;
    }

    // Send chat message
    async function sendMessage() {
      const message = input.value.trim();
      if (!message) return;
      
      addMessage(message, true);
      input.value = '';
      
      try {
        addMessage('Thinking...', false);
        const response = await api.sendMessage(message);
        
        // Remove "Thinking..." message
        messages.removeChild(messages.lastChild);
        
        if (response.status === 'success') {
          addMessage(response.response, false);
        } else {
          addMessage('Sorry, I had trouble understanding that. Please try again.', false);
        }
      } catch (error) {
        messages.removeChild(messages.lastChild);
        addMessage('Sorry, there was an error processing your message.', false);
      }
    }

    // Analyze photo
    async function analyzePhoto() {
      const file = photoInput.files[0];
      if (!file) return;
      
      addMessage('📸 Photo uploaded, analyzing...', true);
      
      try {
        const response = await api.analyzePhoto(file);
        
        if (response.status === 'success') {
          const analysis = response.analysis;
          const recommendations = response.recommendations;
          
          let resultHtml = '<strong>Analysis Results:</strong><br>';
          if (analysis.face_detected) {
            resultHtml += `Skin Type: ${analysis.skin_type}<br>`;
            if (analysis.concerns && analysis.concerns.length > 0) {
              resultHtml += `Concerns: ${analysis.concerns.join(', ')}<br>`;
            }
            resultHtml += `Notes: ${analysis.notes}<br><br>`;
            
            if (recommendations.recommended_products && recommendations.recommended_products.length > 0) {
              resultHtml += '<strong>Recommended Products:</strong><br>';
              recommendations.recommended_products.slice(0, 3).forEach(product => {
                resultHtml += `• ${product.name} (${product.category})<br>`;
              });
            }
          } else {
            resultHtml += 'No face detected in the image. Please upload a clear photo of your face.';
          }
          
          addMessage(resultHtml, false);
        } else {
          addMessage('Sorry, I had trouble analyzing your photo. Please try again.', false);
        }
      } catch (error) {
        addMessage('Sorry, there was an error analyzing your photo.', false);
      }
      
      photoInput.value = '';
    }

    // Event listeners
    sendBtn.addEventListener('click', sendMessage);
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendMessage();
    });
    
    photoBtn.addEventListener('click', () => photoInput.click());
    photoInput.addEventListener('change', analyzePhoto);
  }

  // Public API
  return {
    init: initializeWidget,
    api: api
  };
})();

// Auto-initialize if not in module environment
if (typeof module === 'undefined') {
  document.addEventListener('DOMContentLoaded', () => {
    // Uncomment the next line to auto-initialize the widget
    // SkinCoach.init();
  });
}
