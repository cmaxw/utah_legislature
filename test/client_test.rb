# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  include UtahLegislature::TestHelpers

  def test_requires_api_key
    assert_raises(ArgumentError) { UtahLegislature::Client.new(api_key: "") }
  end

  def test_legislators_maps_chamber_and_party
    conn = FakeConnection.new([
      ["/legislators/", json_response(JSON.generate(
        "legislators" => [
          { "id" => "1", "fullName" => "Jane Doe", "house" => "H", "district" => "5",
            "party" => "D", "counties" => "Salt Lake", "email" => "j@example.com",
            "workPhone" => "555-1000" }
        ]
      ))]
    ])
    client = UtahLegislature::Client.new(api_key: "k", connection: conn)

    leg = client.legislators.first
    assert_equal "Jane Doe", leg.full_name
    assert_equal "House", leg.chamber
    assert_equal "House District 5", leg.district
    assert_equal "Democrat", leg.party
  end

  def test_bill_list_requires_session
    client = UtahLegislature::Client.new(api_key: "k", connection: FakeConnection.new([]))
    assert_raises(ArgumentError) { client.bill_list }
  end

  def test_bill_builds_actions_versions_and_text
    bill_json = JSON.generate(
      "trackingID" => "T1", "billNumber" => "HB0001", "billNumberShort" => "HB1",
      "shortTitle" => "Research Office Act", "year" => "2026",
      "lastActionDate" => "1/31/2026", "updatetime" => "2026-01-31 23:18:35.99",
      "actionHistoryList" => [
        { "description" => "Bill received", "owner" => "House", "voteStr" => "",
          "actionDate" => "2026-01-19 11:07:38.010" }
      ],
      "billVersionList" => [
        { "subTrackID" => "V1", "subVersion" => "1", "active" => true,
          "billDocs" => [{ "url" => "/Session/2026/bills/introduced/HB0001.xml",
                           "shortDesc" => "Introduced", "fileType" => "Introduced" }] }
      ]
    )
    xml = File.read(File.expand_path("fixtures/sample_bill.xml", __dir__))
    conn = FakeConnection.new([
      ["glen.le.utah.gov/bills/2026GS/HB0001/", json_response(bill_json)],
      ["le.utah.gov/Session/2026/bills/introduced/HB0001.xml", xml_response(xml)]
    ])
    client = UtahLegislature::Client.new(api_key: "k", session: "2026GS", connection: conn)

    bill = with_no_throttle { client.bill("HB0001") }

    assert_equal "T1", bill.tracking_id
    assert_equal "Research Office Act", bill.title
    assert_equal Date.new(2026, 1, 31), bill.last_action_at
    assert_equal 1, bill.actions.length
    assert_instance_of Time, bill.actions.first.action_at
    assert_equal 1, bill.versions.length
    assert_includes bill.versions.first.text, "research office"
  end

  def test_bill_list_parses_mixed_date_formats
    conn = FakeConnection.new([
      ["/billlist/", json_response(JSON.generate([
        { "number" => "HB0001", "updatetime" => "2026-01-31 23:18:35.99" }
      ]))]
    ])
    client = UtahLegislature::Client.new(api_key: "k", session: "2026GS", connection: conn)

    assert_instance_of Time, client.bill_list.first.updated_at
  end

  private

  def with_no_throttle
    original = UtahLegislature.throttle_seconds
    UtahLegislature.throttle_seconds = 0
    yield
  ensure
    UtahLegislature.throttle_seconds = original
  end
end
