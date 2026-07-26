class OpencodeController < ApplicationController
  def models
    args = params[:provider].present? ? [params[:provider]] : []
    stdout, stderr, status = OpencodeCli.exec("models", *args)

    if status.success?
      render json: { models: stdout.each_line.map(&:strip).reject(&:blank?) }
    else
      render json: { error: stderr }, status: :unprocessable_content
    end
  end

  def agents
    stdout, stderr, status = OpencodeCli.exec("agent", "list")
    render json: { output: status.success? ? stdout : stderr }, status: status.success? ? :ok : :unprocessable_content
  end
end
