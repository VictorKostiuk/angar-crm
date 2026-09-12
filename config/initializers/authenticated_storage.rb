# Protect original files, variants, disk URLs and direct uploads. All staff can
# view shop attachments, but possession of a signed URL alone is insufficient.
Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include AuthenticatedStorage
end
