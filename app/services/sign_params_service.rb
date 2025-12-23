require 'open3'
require 'json'

class SignParamsService
  PRODUCTS_RUNNER = Rails.root.join('app/javascript/products.mjs')

  def self.get_products(
    cookie:,
    oec_seller_id:,
    base_url:,
    fp:,
    timezone_offset:,
    start_date:,
    end_date:,
    page_no: 0,
    page_size: 10
  )
    # Prepare input data as JSON
    input_data = {
      cookie:,
      oecSellerId: oec_seller_id,
      baseUrl: base_url,
      fp:,
      timezoneOffset: timezone_offset,
      startDate: start_date,
      endDate: end_date,
      pageNo: page_no,
      pageSize: page_size
    }.compact.to_json

    # Pass data via stdin to avoid shell escaping issues
    stdout, stderr, status = Open3.capture3(
      'node',
      PRODUCTS_RUNNER.to_s,
      stdin_data: input_data
    )

    # Even if node exits with non-zero, we still try to parse stdout
    # because the JS code now outputs errors as JSON to stdout
    parsed_response = JSON.parse(stdout.strip)
    
    # Check if the response itself indicates an error
    if parsed_response['error'] || parsed_response['status_code'] == -1
      error_msg = parsed_response['status_msg'] || parsed_response['error'] || 'Unknown error'
      Rails.logger.error("JavaScript fetcher error: #{error_msg}")
      Rails.logger.error("stderr: #{stderr}") if stderr && !stderr.empty?
      return parsed_response  # Return the error response so caller can handle it
    end

    parsed_response
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse JSON response: #{e.message}")
    Rails.logger.error("stdout: #{stdout}")
    Rails.logger.error("stderr: #{stderr}") if stderr && !stderr.empty?
    raise "Failed to parse response: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("SignParamsService error: #{e.message}")
    Rails.logger.error("stdout: #{stdout}")
    Rails.logger.error("stderr: #{stderr}") if stderr && !stderr.empty?
    raise
  end
end

