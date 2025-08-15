import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="uploader"
export default class extends Controller {
  static targets = ["input", "preview", "submit"]

  connect() {
    this.previewImage()
  }

  previewImage() {
    if (this.hasInputTarget && this.hasPreviewTarget) {
      this.inputTarget.addEventListener("change", (event) => {
        const file = event.target.files[0]
        if (file) {
          const reader = new FileReader()
          reader.onload = (e) => {
            this.previewTarget.src = e.target.result
            this.previewTarget.classList.remove("hidden")
            if (this.hasSubmitTarget) {
              this.submitTarget.disabled = false
            }
          }
          reader.readAsDataURL(file)
        }
      })
    }
  }
}
