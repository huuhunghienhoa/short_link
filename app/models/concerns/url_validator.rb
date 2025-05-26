require "resolv"

class UrlValidator < ActiveModel::EachValidator
  PROTOCOLS = %w(http https).freeze
  INVALID_HOST_CHARS_REGEX = /[^a-zA-Z0-9.-]/.freeze
  WHITESPACE_IN_PATH_REGEX = /\s/.freeze

  def validate_each record, attribute, value
    return if value.blank?

    uri = parse_uri(value)

    return if uri && valid_uri_components?(uri)

    record.errors.add(attribute, options[:message] || "must be a valid URL")
  end

  def valid_uri_components? uri
    valid_scheme?(uri.scheme) &&
      valid_host?(uri.host) &&
      valid_path?(uri.path)
  end

  protected

  def parse_uri url
    URI.parse(url)
  rescue URI::InvalidURIError
    nil
  end

  # http and https are accepted
  def valid_scheme? scheme
    return false unless scheme

    PROTOCOLS.include?(scheme.downcase.to_s)
  end

  def valid_host? host
    return false if host.blank?
    return false if host.match?(INVALID_HOST_CHARS_REGEX)
    return false if host.end_with?(".")
    return false unless valid_length?(host)

    labels = host.split(".")
    valid_labels?(labels) || valid_ip?(host)
  end

  # Each label must be between 1 and 63 characters long
  def valid_labels? labels
    labels.count >= 2 && labels.all?{|label| label.length.between?(1, 63)}
  end

  # Entire hostname has a maximum of 253 characters
  def valid_length? host
    host.length <= 253
  end

  # Check if host is an ip-address
  def valid_ip? host
    Resolv::IPv4::Regex.match?(host) || Resolv::IPv6::Regex.match?(host)
  end

  # Disallow blank characters in the path
  def valid_path? path
    return true if path.blank?

    !path.match?(WHITESPACE_IN_PATH_REGEX)
  end
end
