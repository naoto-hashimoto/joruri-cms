# encoding: utf-8
class Tourism::Piece::RecentMovie < Cms::Piece
  validate :validate_settings

  def validate_settings
    unless in_settings['list_count'].blank?
      errors.add(:list_count, :not_a_number) if in_settings['list_count'] !~ /^[0-9]+$/
    end
  end
end
