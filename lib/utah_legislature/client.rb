# frozen_string_literal: true

require "json"
require "time"
require "date"
require "faraday"

module UtahLegislature
  # Talks to the Utah State Legislature API and returns plain value objects.
  #
  #   client = UtahLegislature::Client.new(api_key: "...", session: "2026GS")
  #   client.legislators
  #   client.committees
  #   client.bill_list
  #   client.bill("HB0001")
  #
  # NOTE: `session` is the API's session identifier — "2026GS" (General
  # Session), "2026S1" (first Special Session), etc. — NOT a bare year.
  class Client
    API_HOST = "https://glen.le.utah.gov"
    TEXT_HOST = "https://le.utah.gov"

    attr_reader :api_key, :session

    def initialize(api_key:, session: nil, connection: nil)
      raise ArgumentError, "api_key is required" if api_key.to_s.empty?

      @api_key = api_key
      @session = session
      @connection = connection
    end

    def legislators
      Array(get_json("#{API_HOST}/legislators/#{api_key}")["legislators"]).map do |h|
        chamber = h["house"] == "H" ? "House" : "Senate"
        Legislator.new(
          remote_id: h["id"],
          full_name: h["fullName"],
          chamber: chamber,
          district: "#{chamber} District #{h["district"]}",
          party: party_name(h["party"]),
          counties: h["counties"],
          email: h["email"],
          phone: h["workPhone"]
        )
      end
    end

    def committees
      Array(get_json("#{API_HOST}/committees/#{api_key}")["committees"]).map do |h|
        Committee.new(
          remote_id: h["id"],
          name: h["description"],
          member_remote_ids: Array(h["members"]).map { |m| m["id"] }
        )
      end
    end

    # Lightweight list of bills for a session. Iterate this, compare
    # `updated_at`, and fetch full details only for what changed.
    def bill_list(session = @session)
      session = require_session(session)
      Array(get_json("#{API_HOST}/bills/#{session}/billlist/#{api_key}")).map do |h|
        BillSummary.new(number: h["number"], updated_at: parse_date(h["updatetime"]))
      end
    end

    # Full detail for one bill. When include_text is true (default) each version's
    # body text is fetched and parsed.
    def bill(number, session: @session, include_text: true)
      session = require_session(session)
      h = get_json("#{API_HOST}/bills/#{session}/#{number}/#{api_key}")

      Bill.new(
        tracking_id: h["trackingID"],
        number: h["billNumber"],
        short_number: h["billNumberShort"],
        title: h["shortTitle"],
        prime_sponsor_remote_id: h["primeSponsor"],
        floor_sponsor_remote_id: h["floorSponsor"],
        general_provisions: h["generalProvisions"],
        monies_appropriated: h["moniesAppropriated"],
        year: h["year"],
        last_action_at: parse_date(h["lastActionDate"]),
        updated_at: parse_date(h["updatetime"]),
        link: "#{TEXT_HOST}/~#{h["year"]}/bills/static/#{h["billNumber"]}.html",
        actions: build_actions(h),
        versions: build_versions(h, include_text: include_text)
      )
    end

    # Fetch and parse the body text for a single BillDoc (or doc URL). Returns
    # clean plain text, or nil if it couldn't be retrieved.
    def bill_text(doc_or_url)
      url = doc_or_url.respond_to?(:url) ? doc_or_url.url : doc_or_url
      xml = fetch_xml(resolve_doc_url(url))
      xml && Parser.body_text(xml)
    end

    private

    def build_actions(bill_hash)
      Array(bill_hash["actionHistoryList"]).map do |a|
        BillAction.new(
          description: a["description"],
          owner: a["owner"],
          action_at: parse_date(a["actionDate"]),
          vote: a["voteStr"]
        )
      end
    end

    def build_versions(bill_hash, include_text:)
      Array(bill_hash["billVersionList"]).map do |v|
        docs = xml_docs(v)
        remote_id = present(v["subTrackID"]) ||
                    [bill_hash["trackingID"], v["subVersion"]].compact.join(":")
        BillVersion.new(
          remote_id: remote_id,
          version_number: v["subVersion"],
          active: !!v["active"],
          docs: docs,
          text: include_text ? fetch_first_text(docs) : nil
        )
      end
    end

    # XML documents attached to a version, in the order the API lists them
    # (enrolled first, then introduced, ...).
    def xml_docs(version)
      Array(version["billDocs"]).filter_map do |doc|
        url = doc["url"].to_s
        next unless url.split(".").last.to_s.downcase == "xml"

        BillDoc.new(url: url, description: doc["shortDesc"], file_type: doc["fileType"])
      end
    end

    def fetch_first_text(docs)
      docs.each do |doc|
        xml = fetch_xml(resolve_doc_url(doc.url))
        return Parser.body_text(xml) if xml
      end
      nil
    end

    # Fetch a bill-text XML doc. Under bulk load le.utah.gov rate-limits and
    # returns HTTP-200 HTML landing pages instead of XML, so validate the body
    # and retry with backoff rather than trusting the status code alone.
    def fetch_xml(url, attempts: 4)
      attempts.times do |i|
        sleep(UtahLegislature.throttle_seconds)
        begin
          response = connection.get(url)
          body = response.body.to_s
          return body if response.success? && xml_like?(response, body)
        rescue Faraday::Error => e
          UtahLegislature.logger.warn("[UtahLegislature] XML fetch error (#{e.class}) for #{url}")
        end

        sleep(1.0 * (i + 1)) # extra backoff once we've clearly been throttled
      end
      UtahLegislature.logger.warn("[UtahLegislature] Gave up fetching XML after #{attempts} tries: #{url}")
      nil
    end

    def xml_like?(response, body)
      response.headers["content-type"].to_s.include?("xml") ||
        body.lstrip.start_with?("<?xml", "<leg")
    end

    # Doc URLs are absolute paths ("/Session/2026/bills/enrolled/HB0001.xml").
    # Resolve them against the text host; tolerate full URLs and relative paths.
    def resolve_doc_url(url)
      url = url.to_s
      if url.start_with?("http")
        url
      elsif url.start_with?("/")
        "#{TEXT_HOST}#{url}"
      else
        "#{TEXT_HOST}/#{url}"
      end
    end

    def get_json(url)
      response = connection.get(url)
      unless response.success?
        raise ResponseError, "GET #{url} returned #{response.status}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise ResponseError, "GET #{url} did not return JSON: #{e.message}"
    end

    # The API mixes date formats: "1/31/2026" (m/d/Y) for lastActionDate, and
    # ISO timestamps like "2026-01-19 11:07:38.010" for history/updatetime.
    # The timestamps carry no timezone, so we interpret them as UTC — otherwise
    # parsing would depend on the host's timezone and produce different values
    # on a dev box vs. a UTC server.
    def parse_date(value)
      str = value.to_s.strip
      return nil if str.empty?

      if str.match?(%r{\A\d{1,2}/\d{1,2}/\d{4}\z})
        Date.strptime(str, "%m/%d/%Y")
      else
        DateTime.parse(str).to_time.utc
      end
    rescue ArgumentError, Date::Error
      UtahLegislature.logger.warn("[UtahLegislature] Unparseable date: #{value.inspect}")
      nil
    end

    def party_name(code)
      case code
      when "R" then "Republican"
      when "D" then "Democrat"
      else "Independent"
      end
    end

    def require_session(session)
      return session unless session.to_s.empty?

      raise ArgumentError, "session is required (e.g. \"2026GS\")"
    end

    def present(value)
      value unless value.to_s.empty?
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.open_timeout = UtahLegislature.open_timeout
        f.options.timeout = UtahLegislature.timeout
      end
    end
  end
end
