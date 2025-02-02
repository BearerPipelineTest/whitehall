module Attachable
  extend ActiveSupport::Concern
  EDITION_CREATE_GRACE_PERIOD = 20.seconds

  included do
    has_many :attachments,
             -> { not_deleted.order("attachments.ordering, attachments.id") },
             as: :attachable,
             inverse_of: :attachable

    has_many :html_attachments,
             -> { not_deleted.order("attachments.ordering, attachments.id") },
             as: :attachable

    has_many :deleted_html_attachments,
             -> { deleted },
             class_name: "HtmlAttachment",
             as: :attachable

    has_many :deleted_attachments,
             -> { deleted },
             class_name: "Attachment",
             as: :attachable

    if respond_to?(:add_trait)
      add_trait do
        def process_associations_after_save(edition)
          @edition.attachments.each do |attachment|
            edition.attachments << attachment.deep_clone
          end
        end
      end
    end
  end

  class Null
    def publicly_visible?
      false
    end

    def accessible_to?(_user)
      false
    end

    def access_limited?
      false
    end

    def access_limited_object
      nil
    end

    def organisations
      []
    end

    def unpublished?
      false
    end

    def unpublished_edition
      nil
    end
  end

  def attachables
    [self]
  end

  ChangedAttachment = Struct.new(:attachment, :status)

  def changed_attachments
    created = attachments.where("created_at > ?", created_at + EDITION_CREATE_GRACE_PERIOD)

    updated_attachments = attachments.where("updated_at > created_at")

    # Using a 30 second grace period because GovspeakContent#render_govspeak! historically used to change the updated_at timestamp
    # when running in an async worker to convert body to HTML. This meant that all HTML attachments ended up with
    # (updated_at > created_at) so would show as 'changed'.
    updated_html_attachments = html_attachments.joins(:govspeak_content).where("govspeak_contents.updated_at > DATE_ADD(govspeak_contents.created_at,  INTERVAL 20 SECOND)")
    updated = (updated_attachments + updated_html_attachments) - created

    created.map { |a| ChangedAttachment.new(a, :created) } +
      updated.map { |a| ChangedAttachment.new(a, :updated) } +
      deleted_attachments.map { |a| ChangedAttachment.new(a, :deleted) }
  end

  def uploaded_to_asset_manager?
    attachments
      .map(&:attachment_data)
      .compact
      .all?(&:uploaded_to_asset_manager?)
  end

  def allows_attachments?
    true
  end

  def allows_file_attachments?
    true
  end

  def allows_attachment_references?
    false
  end

  def allows_inline_attachments?
    true
  end

  def can_order_attachments?
    !allows_inline_attachments?
  end

  def can_have_attached_house_of_commons_papers?
    false
  end

  def allows_html_attachments?
    false
  end

  def allows_external_attachments?
    false
  end

  def allows_attachment_type?(type)
    case type
    when "html"
      allows_html_attachments?
    when "external"
      allows_external_attachments?
    when "file"
      allows_file_attachments?
    else
      false
    end
  end

  def has_thumbnail?
    thumbnailable_attachments.any?
  end

  def thumbnail_url
    thumbnailable_attachments.first.url(:thumbnail)
  end

  def thumbnailable_attachments
    attachments.select { |a| a.content_type == AttachmentUploader::PDF_CONTENT_TYPE }
  end

  def has_official_document?
    has_command_paper? || has_act_paper?
  end

  def has_command_paper?
    attachments.any?(&:is_command_paper?)
  end

  def has_act_paper?
    attachments.any?(&:is_act_paper?)
  end

  def search_index
    super.merge("attachments" => attachments.map(&:search_index))
  end

  def next_ordering
    max = Attachment.where(attachable_id: id, attachable_type: self.class.base_class.to_s).maximum(:ordering)
    max ? max + 1 : 0
  end

  def delete_all_attachments
    attachments.each(&:destroy)
  end

  def reorder_attachments(ordered_attachment_ids)
    return if ordered_attachment_ids.empty?

    transaction do
      # Attachment has a unique constraint on attachable type/id and ordering.
      # This stops us simply changing the ordering values of existing
      # attachments, as two rows end up with the same ordering value during
      # the update, violating the constraint.

      # To get around it, we check that we can start at 0 and fit all the
      # ordering values below the current lowest ordering.
      start_at = if ordered_attachment_ids.count < attachments.unscoped.minimum(:ordering)
                   0
                 else # Otherwise, we start reordering at the next available number
                   next_ordering
                 end

      ordered_attachment_ids.each.with_index(start_at) do |attachment_id, ordering|
        attachments.find(attachment_id).update_column(:ordering, ordering)
      end
    end
  end
end
