# frozen_string_literal: true

module UtahLegislature
  # Immutable value objects returned by the client. These are deliberately
  # plain — a host app maps them onto its own persistence layer.

  # A member of the legislature.
  Legislator = Data.define(
    :remote_id, :full_name, :chamber, :district, :party, :counties, :email, :phone
  )

  # A committee and the remote ids of its members.
  Committee = Data.define(:remote_id, :name, :member_remote_ids)

  # A lightweight entry from the bill list (used to decide what to fetch).
  BillSummary = Data.define(:number, :updated_at)

  # A downloadable document attached to a bill version.
  BillDoc = Data.define(:url, :description, :file_type)

  # A single action in a bill's history.
  BillAction = Data.define(:description, :owner, :action_at, :vote)

  # A specific version of a bill, including its parsed body text.
  BillVersion = Data.define(:remote_id, :version_number, :active, :docs, :text)

  # A bill with its actions and versions.
  Bill = Data.define(
    :tracking_id, :number, :short_number, :title,
    :prime_sponsor_remote_id, :floor_sponsor_remote_id,
    :general_provisions, :monies_appropriated, :year,
    :last_action_at, :updated_at, :link, :actions, :versions
  )
end
