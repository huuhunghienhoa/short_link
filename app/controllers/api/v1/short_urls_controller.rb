class Api::V1::ShortUrlsController < ApplicationController
  rescue_from RateLimitExceededError, with: :render_rate_limit_exceeded
  rescue_from ShortCodeCreationExceededError, with: :render_short_code_creation_exceeded
  rescue_from LockAcquisitionFailedError, with: :render_lock_acquisition_failed
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def encode
    short_code = EncodeService.new(params[:url], user_remote_ip).call
    render json: {short_code: short_code}
  end

  def decode
    original_url = DecodeService.new(params[:short_code], user_remote_ip).call
    render json: {original_url: original_url}
  end

  private

  def render_rate_limit_exceeded
    SHORTLINK_LOGGER.error("[RateLimitExceededError]: IP: #{user_remote_ip}")
    render json: {error: "Rate limit exceeded"}, status: :too_many_requests
  end

  def render_short_code_creation_exceeded
    SHORTLINK_LOGGER.error("[ShortCodeCreationExceededError]: IP: #{user_remote_ip}")
    render json: {error: "Failed to create short code"}, status: :too_many_requests
  end

  def render_lock_acquisition_failed
    SHORTLINK_LOGGER.error("[LockAcquisitionFailedError]: IP: #{user_remote_ip}")
    render json: {error: "Create limit exceeded"}, status: :too_many_requests
  end

  def render_record_invalid exception
    SHORTLINK_LOGGER.error("[ActiveRecord::RecordInvalid]: IP: #{user_remote_ip},
                            Detail: #{exception.record.errors.full_messages.join(', ')}")
    render json: {error: exception.record.errors.full_messages.to_sentence}, status: :unprocessable_entity
  end

  def render_not_found
    SHORTLINK_LOGGER.warn("[ActiveRecord::RecordNotFound]: IP: #{user_remote_ip}")
    render json: {error: "Short code not found"}, status: :not_found
  end

  def user_remote_ip
    @user_remote_ip ||= request.remote_ip
  end
end
