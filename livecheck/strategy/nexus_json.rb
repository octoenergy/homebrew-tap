# typed: strict
# frozen_string_literal: true

require "json"
require "livecheck/strategic"
require "net/http"
require "openssl"
require "uri"

# Strategy for Nexus REST API search JSON (e.g. /service/rest/v1/search).
# Based on the Homebrew JSON strategy:
# https://github.com/Homebrew/brew/blob/master/Library/Homebrew/livecheck/strategy/json.rb
# Adds optional mTLS support when HOMEBREW_SSL_CLIENT_CERT is set to a cert file path.

#TODO: Support pagination or figure out how to get nexus to return latest uploads first

module Homebrew
  module Livecheck
    module Strategy
      class NexusJson
        extend Strategic

        NICE_NAME = "Nexus JSON"

        URL_MATCH_REGEX = %r{^https?://}i

        MAX_REDIRECTS = 5

        HTTP_OPEN_CONNECTION_TIMEOUT = 5
        HTTP_READ_CONNECTION_TIMEOUT = 10

        sig { override.params(url: String).returns(T::Boolean) }
        def self.match?(url)
          URL_MATCH_REGEX.match?(url)
        end

        # Nexus API response cointains an array of items each having version key
        def self.versions_from_nexus_items(json)
          items = json["items"]
          return [] unless items.is_a?(Array)

          items.filter_map { |item| item["version"] }.uniq
        end

        sig do
          override
            .params(
              url: String,
              regex: T.nilable(Regexp),
              content: T.nilable(String),
              options: Options,
              block: T.nilable(Proc)
            )
            .returns(T::Hash[Symbol, T.anything])
        end
        def self.find_versions(
          url:,
          regex: nil,
          content: nil,
          options: Options.new,
          &block
        )
          match_data = { matches: {}, regex:, url: }
          match_data[:cached] = true if content
          return match_data if url.blank?

          unless match_data[:cached]
            env_cert = ENV["HOMEBREW_SSL_CLIENT_CERT"].to_s.strip
            if env_cert.empty?
              content, error = fetch_without_mtls(url)
            else
              cert_path = File.expand_path(env_cert)
              if File.exist?(cert_path)
                content, error = fetch_with_mtls(url, cert_path)
              else
                match_data[:messages] = [
                  "Client certificate path set in HOMEBREW_SSL_CLIENT_CERT but file not found at: #{cert_path}"
                ]
                return match_data
              end
            end

            if error && content.nil?
              match_data[:messages] = [error]
              return match_data
            end
          end

          return match_data if content.blank?

          json = JSON.parse(content)
          versions = versions_from_nexus_items(json)
          versions.each { |v| match_data[:matches][v] = Version.new(v) }
          match_data
        end

        def self.fetch_with_mtls(url_str, cert_path)
          pem = File.read(cert_path)
          cert = OpenSSL::X509::Certificate.new(pem)
          key = OpenSSL::PKey.read(pem)

          redirects = 0
          uri = URI(url_str)

          while redirects <= MAX_REDIRECTS
            http = Net::HTTP.new(uri.hostname, uri.port)
            http.use_ssl = (uri.scheme == "https")
            http.cert = cert
            http.key = key
            http.open_timeout = HTTP_OPEN_CONNECTION_TIMEOUT
            http.read_timeout = HTTP_READ_CONNECTION_TIMEOUT

            response = http.request(Net::HTTP::Get.new(uri.request_uri))

            case response
            when Net::HTTPSuccess
              return response.body, nil
            when Net::HTTPRedirection
              redirects += 1
              location = response["location"]
              uri = URI.join(uri, location)
            else
              return nil, "HTTP #{response.code} #{response.message}"
            end
          end

          [nil, "Too many redirects"]
        end

        def self.fetch_without_mtls(url_str)
          redirects = 0
          uri = URI(url_str)

          while redirects <= MAX_REDIRECTS
            http = Net::HTTP.new(uri.hostname, uri.port)
            http.use_ssl = (uri.scheme == "https")
            http.open_timeout = HTTP_OPEN_CONNECTION_TIMEOUT
            http.read_timeout = HTTP_READ_CONNECTION_TIMEOUT

            response = http.request(Net::HTTP::Get.new(uri.request_uri))

            case response
            when Net::HTTPSuccess
              return response.body, nil
            when Net::HTTPRedirection
              redirects += 1
              location = response["location"]
              uri = URI.join(uri, location)
            else
              return nil, "HTTP #{response.code} #{response.message}"
            end
          end

          [nil, "Too many redirects"]
        end
      end
    end
  end
end
