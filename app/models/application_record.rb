class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  PER_PAGE = 20

  def self.paginate(page:, per: PER_PAGE)
    page = page.to_i
    page = 1 if page < 1
    limit(per).offset((page - 1) * per)
  end
end
