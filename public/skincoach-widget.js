/**
 * SkinCoach Widget - JavaScript client for the dermatology chatbot API
 * Usage: Include this script and call SkinCoach.init() to embed the widget
 */

window.SkinCoach = (function() {
  // Configuration
  const config = {
    apiBaseUrl: window.location.origin + '/api/v1',
    widgetId: 'skincoach-widget',
    storageKey: 'skincoach-chat-history'
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

  // Markdown rendering utility
  const markdown = {
    // Simple markdown to HTML converter
    render(text) {
      return text
        // Bold: **text** or __text__
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/__(.*?)__/g, '<strong>$1</strong>')
        // Italic: *text* or _text_
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/_(.*?)_/g, '<em>$1</em>')
        // Code: `code`
        .replace(/`(.*?)`/g, '<code style="background:#f5f5f5;padding:2px 4px;border-radius:3px;font-family:monospace;">$1</code>')
        // Code blocks: ```code```
        .replace(/```([\s\S]*?)```/g, '<pre style="background:#f5f5f5;padding:8px;border-radius:4px;overflow-x:auto;margin:8px 0;"><code style="font-family:monospace;">$1</code></pre>')
        // Links: [text](url)
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" style="color:#667eea;text-decoration:underline;">$1</a>')
        // Line breaks
        .replace(/\n/g, '<br>')
        // Lists: - item or * item
        .replace(/^[\s]*[-*]\s(.+)$/gm, '<li style="margin-left:20px;">$1</li>')
        // Wrap consecutive list items
        .replace(/(<li[^>]*>.*<\/li>\s*)+/g, '<ul style="margin:8px 0;padding-left:0;">$&</ul>')
        // Headers: # Header, ## Header, ### Header
        .replace(/^### (.*$)/gm, '<h3 style="font-size:16px;font-weight:600;margin:12px 0 6px 0;">$1</h3>')
        .replace(/^## (.*$)/gm, '<h2 style="font-size:18px;font-weight:600;margin:12px 0 6px 0;">$1</h2>')
        .replace(/^# (.*$)/gm, '<h1 style="font-size:20px;font-weight:600;margin:12px 0 6px 0;">$1</h1>');
    }
  };

  // Chat history management
  const chatHistory = {
    // Save chat message to localStorage
    saveMessage(message, isUser, imageData = null) {
      try {
        const history = this.getHistory();
        const messageData = {
          id: Date.now() + Math.random(), // Unique ID
          content: message,
          isUser: isUser,
          timestamp: new Date().toISOString(),
          imageData: imageData // Base64 image data if present
        };
        
        history.push(messageData);
        
        // Keep only last 50 messages to prevent localStorage bloat
        if (history.length > 50) {
          history.splice(0, history.length - 50);
        }
        
        localStorage.setItem(config.storageKey, JSON.stringify(history));
      } catch (error) {
        console.warn('Failed to save chat message:', error);
      }
    },

    // Get chat history from localStorage
    getHistory() {
      try {
        const stored = localStorage.getItem(config.storageKey);
        return stored ? JSON.parse(stored) : [];
      } catch (error) {
        console.warn('Failed to load chat history:', error);
        return [];
      }
    },

    // Clear chat history
    clearHistory() {
      try {
        localStorage.removeItem(config.storageKey);
      } catch (error) {
        console.warn('Failed to clear chat history:', error);
      }
    },

    // Convert image file to base64 for storage
    async imageToBase64(file) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
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
          display: flex;
          justify-content: space-between;
          align-items: center;
        ">
          <span>🧴 SkinCoach Assistant</span>
          <button id="skincoach-clear" style="
            background: rgba(255,255,255,0.2);
            color: white;
            border: none;
            padding: 4px 8px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            opacity: 0.8;
          " title="Clear chat history">🗑️</button>
        </div>
        
        <div id="skincoach-messages" style="
          flex: 1;
          padding: 16px;
          overflow-y: auto;
          background: #f8f9fa;
        ">
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
    async function addMessage(content, isUser = false, imageFile = null, skipSave = false) {
      const messageDiv = document.createElement('div');
      messageDiv.style.cssText = `
        background: ${isUser ? '#667eea' : 'white'};
        color: ${isUser ? 'white' : '#333'};
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 12px;
        max-width: 85%;
        ${isUser ? 'margin-left: auto;' : ''}
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      `;
      
      let messageContent = '';
      let imageData = null;
      
      // Add image if provided
      if (imageFile) {
        const imageUrl = URL.createObjectURL(imageFile);
        messageContent += `
          <div style="margin-bottom: 8px;">
            <img src="${imageUrl}" alt="Uploaded skin photo" style="
              max-width: 200px;
              max-height: 200px;
              border-radius: 8px;
              object-fit: cover;
              border: 2px solid ${isUser ? 'rgba(255,255,255,0.3)' : '#e0e0e0'};
            ">
          </div>
        `;
        
        // Convert to base64 for storage if not skipping save
        if (!skipSave) {
          try {
            imageData = await chatHistory.imageToBase64(imageFile);
          } catch (error) {
            console.warn('Failed to convert image to base64:', error);
          }
        }
      }
      
      // Add text content (render markdown for bot messages)
      messageContent += isUser ? content : markdown.render(content);
      
      messageDiv.innerHTML = messageContent;
      messages.appendChild(messageDiv);
      messages.scrollTop = messages.scrollHeight;
      
      // Save to localStorage unless explicitly skipping
      if (!skipSave) {
        chatHistory.saveMessage(content, isUser, imageData);
      }
    }

    // Add message from stored data (for restoration)
    function addStoredMessage(messageData) {
      const messageDiv = document.createElement('div');
      messageDiv.style.cssText = `
        background: ${messageData.isUser ? '#667eea' : 'white'};
        color: ${messageData.isUser ? 'white' : '#333'};
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 12px;
        max-width: 85%;
        ${messageData.isUser ? 'margin-left: auto;' : ''}
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      `;
      
      let messageContent = '';
      
      // Add image if stored
      if (messageData.imageData) {
        messageContent += `
          <div style="margin-bottom: 8px;">
            <img src="${messageData.imageData}" alt="Uploaded skin photo" style="
              max-width: 200px;
              max-height: 200px;
              border-radius: 8px;
              object-fit: cover;
              border: 2px solid ${messageData.isUser ? 'rgba(255,255,255,0.3)' : '#e0e0e0'};
            ">
          </div>
        `;
      }
      
      // Add text content (render markdown for bot messages)
      messageContent += messageData.isUser ? messageData.content : markdown.render(messageData.content);
      
      messageDiv.innerHTML = messageContent;
      messages.appendChild(messageDiv);
    }

    // Restore chat history from localStorage
    function restoreChatHistory() {
      const history = chatHistory.getHistory();
      
      if (history.length === 0) {
        // Add welcome message if no history
        addMessage('👋 Hi! I\'m your AI skincare assistant. You can:<br>• Ask me skincare questions<br>• Upload a photo for skin analysis<br>• Drag & drop images directly here<br><br>How can I help you today?', false, null, true);
      } else {
        // Restore all messages from history
        history.forEach(messageData => {
          addStoredMessage(messageData);
        });
      }
      
      messages.scrollTop = messages.scrollHeight;
    }

    // Clear chat history
    function clearChat() {
      if (confirm('Are you sure you want to clear your chat history? This cannot be undone.')) {
        chatHistory.clearHistory();
        messages.innerHTML = '';
        addMessage('👋 Chat cleared! How can I help you today?', false, null, true);
      }
    }

    // Add typing indicator
    function addTypingIndicator() {
      const typingDiv = document.createElement('div');
      typingDiv.id = 'typing-indicator';
      typingDiv.style.cssText = `
        background: white;
        color: #666;
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 12px;
        max-width: 85%;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        font-style: italic;
      `;
      typingDiv.innerHTML = '🤔 Analyzing...';
      messages.appendChild(typingDiv);
      messages.scrollTop = messages.scrollHeight;
      return typingDiv;
    }

    // Remove typing indicator
    function removeTypingIndicator() {
      const indicator = document.getElementById('typing-indicator');
      if (indicator) {
        indicator.remove();
      }
    }

    // Send chat message
    async function sendMessage() {
      const message = input.value.trim();
      if (!message) return;
      
      await addMessage(message, true);
      input.value = '';
      
      try {
        const typingIndicator = addTypingIndicator();
        const response = await api.sendMessage(message);
        
        removeTypingIndicator();
        
        if (response.status === 'success') {
          await addMessage(response.response, false);
        } else {
          await addMessage('Sorry, I had trouble understanding that. Please try again.', false);
        }
      } catch (error) {
        removeTypingIndicator();
        await addMessage('Sorry, there was an error processing your message.', false);
      }
    }

    // Drag and drop functionality for chat area
    function setupDragAndDrop() {
      const chatArea = document.getElementById('skincoach-messages');
      
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        chatArea.addEventListener(eventName, preventDefaults, false);
      });
      
      function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
      }
      
      ['dragenter', 'dragover'].forEach(eventName => {
        chatArea.addEventListener(eventName, highlight, false);
      });
      
      ['dragleave', 'drop'].forEach(eventName => {
        chatArea.addEventListener(eventName, unhighlight, false);
      });
      
      function highlight(e) {
        chatArea.style.background = 'linear-gradient(135deg, #f0f8ff, #e6f3ff)';
        chatArea.style.border = '2px dashed #667eea';
      }
      
      function unhighlight(e) {
        chatArea.style.background = '#f8f9fa';
        chatArea.style.border = 'none';
      }
      
      chatArea.addEventListener('drop', handleDrop, false);
      
      function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;
        
        if (files.length > 0) {
          const file = files[0];
          if (file.type.startsWith('image/')) {
            // Process the dropped image
            processImageFile(file);
          } else {
            addMessage('❌ Please drop an image file (JPEG, PNG, etc.)', false, null, true);
          }
        }
      }
    }
    
    // Process image file (from drag/drop or file input)
    async function processImageFile(file) {
      // Show uploaded image with a message
      await addMessage('📸 Analyzing your skin photo...', true, file);
      
      try {
        const typingIndicator = addTypingIndicator();
        const response = await api.analyzePhoto(file);
        
        removeTypingIndicator();
        
        if (response.status === 'success') {
          // Use the conversational response from the AI
          if (response.response) {
            await addMessage(response.response, false);
          } else {
            // Fallback to structured display if no conversational response
            const analysis = response.analysis;
            const recommendations = response.recommendations;
            
            let resultHtml = '<strong>✨ Skin Analysis Results:</strong><br><br>';
            if (analysis && analysis.face_detected) {
              resultHtml += `<strong>Skin Type:</strong> ${analysis.skin_type}<br>`;
              if (analysis.concerns && analysis.concerns.length > 0) {
                resultHtml += `<strong>Concerns:</strong> ${analysis.concerns.join(', ')}<br>`;
              }
              if (analysis.notes) {
                resultHtml += `<strong>Notes:</strong> ${analysis.notes}<br><br>`;
              }
              
              // Show recommendations if available
              if (recommendations && recommendations.picks) {
                resultHtml += '<strong>🛍️ Product Recommendations:</strong><br>';
                Object.entries(recommendations.picks).forEach(([category, products]) => {
                  if (products && products.length > 0) {
                    const product = products[0]; // Show first product
                    resultHtml += `<strong>${category.charAt(0).toUpperCase() + category.slice(1)}:</strong> ${product.brand} ${product.name}<br>`;
                  }
                });
              }
            } else {
              resultHtml += '❌ No face detected in the image. Please upload a clear photo of your face for analysis.';
            }
            
            await addMessage(resultHtml, false);
          }
        } else {
          await addMessage('😔 Sorry, I had trouble analyzing your photo. Please try uploading a clear image of your face.', false);
        }
      } catch (error) {
        removeTypingIndicator();
        await addMessage('🔧 Sorry, there was an error analyzing your photo. Please try again.', false);
      }
    }

    // Event listeners
    sendBtn.addEventListener('click', sendMessage);
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendMessage();
    });
    
    photoBtn.addEventListener('click', () => photoInput.click());
    photoInput.addEventListener('change', () => {
      const file = photoInput.files[0];
      if (file) {
        processImageFile(file);
        photoInput.value = ''; // Clear the input
      }
    });
    
    // Clear chat button
    const clearBtn = document.getElementById('skincoach-clear');
    clearBtn.addEventListener('click', clearChat);
    
    // Initialize drag and drop
    setupDragAndDrop();
    
    // Restore chat history or show welcome message
    restoreChatHistory();
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
