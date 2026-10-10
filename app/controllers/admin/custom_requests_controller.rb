module Admin
  class CustomRequestsController < BaseController
    def index
      @status = params[:status].presence_in(CustomRequest::STATUSES)
      @requests = CustomRequest.recent_first
      @requests = @status ? @requests.where(status: @status) : @requests.open
      @counts = CustomRequest.group(:status).count
    end

    def show
      @custom_request = CustomRequest.find(params[:id])
      @company = Company.where("LOWER(name) = ?", @custom_request.organization.downcase).first
    end

    def update
      @custom_request = CustomRequest.find(params[:id])
      if @custom_request.update(params.require(:custom_request).permit(:status, :notes))
        redirect_to admin_custom_request_path(@custom_request), notice: "Saved."
      else
        @company = nil
        render :show, status: :unprocessable_entity
      end
    end
  end
end
