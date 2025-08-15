import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="status"
export default class extends Controller {
  static targets = ["indicator", "content"]
  static values = { 
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.poll()
  }

  disconnect() {
    this.stopPolling()
  }

  poll() {
    this.pollTimer = setInterval(() => {
      this.checkStatus()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateStatus(data)
        
        // Stop polling if status is completed or failed
        if (data.status === "completed" || data.status === "failed") {
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error("Error checking status:", error)
    }
  }

  updateStatus(data) {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.textContent = this.formatStatus(data.status)
    }
    
    if (this.hasContentTarget && data.status === "completed") {
      // Replace content area with results
      this.contentTarget.innerHTML = data.html || ""
    }
  }

  formatStatus(status) {
    const statusMap = {
      "pending": "⏳ Pending...",
      "analyzing": "🔍 Analyzing your photo...",
      "completed": "✅ Analysis complete!",
      "failed": "❌ Analysis failed"
    }
    return statusMap[status] || status
  }
}
