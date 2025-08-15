class ConsultationsController < ApplicationController
  before_action :set_consultation, only: [:show, :status]

  def new
    @consultation = Consultation.new
  end

  def create
    @consultation = Consultation.new(consultation_params)

    if @consultation.save
      # Enqueue background job for analysis (demo version)
      AnalyzeImageDemoJob.perform_later(@consultation)
      redirect_to consultation_path(@consultation)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Status page that polls for updates
  end

  def status
    # JSON endpoint for status polling
    respond_to do |format|
      format.json do
        render json: {
          status: @consultation.status,
          html: @consultation.completed? ? render_results_html : nil
        }
      end
    end
  end

  def status_demo
    # Demo status endpoint for testing Stimulus status controller
  end

  private

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  def consultation_params
    params.require(:consultation).permit(:photo)
  end

  def render_results_html
    return nil unless @consultation.completed?

    render_to_string(
      partial: 'consultations/results',
      locals: { consultation: @consultation }
    )
  end
end
