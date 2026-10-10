class MatchesController < ApplicationController
  before_action :require_manager
  before_action :set_match, except: %i[index run]

  def index
    @status = Match::STATUSES.include?(params[:status]) ? params[:status] : "pending"
    scope = current_company.matches.where(status: @status)
                           .includes(employee: %i[current_location desired_location], matched_employee: %i[current_location desired_location])
    scope = scope.where(match_type: params[:match_type]) if Match::TYPES.key?(params[:match_type])
    # Seniority first, the usual rule in union and civil-service transfer policies.
    @matches = scope.sort_by { |match| [ -match.combined_seniority, match.created_at ] }
    @counts = current_company.matches.group(:status).count
  end

  def show
  end

  def run
    created = SwapMatcher.new(current_company).refresh_all
    audit("match.run", summary: "Ran matching (#{created} new)")
    redirect_to matches_path, notice: created.positive? ? "Found #{created} new #{"match".pluralize(created)}." : "No new matches found."
  end

  def approve = transition(:approve!, "Swap approved. Both employees have been notified.")
  def reject = transition(:reject!, "Swap rejected. This pair won't be suggested again unless you reopen it.")
  def reopen = transition(:reopen!, "Swap moved back to pending.")
  def complete = transition(:complete!, "Swap completed. Employee locations have been updated.")

  private

  def set_match
    @match = current_company.matches.find(params[:id])
  end

  def transition(action, message)
    SwapWorkflow.new(@match, actor: Current.user).public_send(action)
    redirect_back_or_to matches_path(status: @match.status), notice: message
  rescue SwapWorkflow::InvalidTransition => e
    redirect_back_or_to matches_path, alert: e.message
  end
end
