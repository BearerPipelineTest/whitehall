When /^I draft a new consultation "([^"]*)"$/ do |title|
  policy = create(:policy)
  begin_drafting_document type: 'consultation', title: title
  select_date "Opening Date", with: 1.day.ago.to_s
  select_date "Closing Date", with: 6.days.from_now.to_s
  attach_file "Attachment", Rails.root.join("features/fixtures/attachment.pdf")
  check "Wales"
  check "Scotland"
  select policy.title, from: "Related Policies"
  click_button "Save"
end