Consultation.where(first_published_at: nil).each do |consultation|
  next unless consultation.document.ever_published_editions.any?
  next if consultation.opening_at.blank?

  public_at = consultation.make_public_at(consultation.opening_at.to_datetime) # rubocop:disable Style/DateTime
  result = consultation.save(touch: false, validate: false)

  puts sprintf("Setting %s first_published_at to %s \n=> %s", consultation.inspect, public_at, result)
end

Consultation.where("date(first_published_at) > date(opening_at)").each do |consultation|
  next unless consultation.document.ever_published_editions.any?
  next if consultation.opening_at.blank?

  public_at = consultation.first_published_at = consultation.opening_at.to_datetime # rubocop:disable Style/DateTime
  result = consultation.save(touch: false, validate: false)

  puts sprintf("Setting %s first_published_at to %s \n=> %s", consultation.inspect, public_at, result)
end
